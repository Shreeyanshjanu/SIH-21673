
package com.sih.voicebridge.pipeline

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class VoicePipelineOrchestrator(
    context: Context,
    private val emitEvent: (Map<String, Any?>) -> Unit,
) {
    private val appContext = context.applicationContext

    private val audioCaptureManager = AudioCaptureManager()
    private val vadProcessor = VadProcessor()
    private val sttEngine = SttEngine(appContext, ::emitStatus)
    private val sentenceManager = SentenceManager()
    private val emergencyAudioController = EmergencyAudioController(appContext)
    private val ttsEngine = TtsEngine(appContext, emitEvent, ::emitStatus)
    private val resourceMonitor = ResourceMonitor(appContext, emitEvent)

    /*
     * IMPORTANT:
     * Expensive initialization/model operations run here,
     * NOT on Android's main/UI thread.
     */
    private val pipelineExecutor = Executors.newSingleThreadExecutor()

    private var languageCode: String = "en"
    private var mode: String = "walkie_talkie"
    private var activeMessageId: String? = null

    private val listening = AtomicBoolean(false)
    private val initialized = AtomicBoolean(false)

    private var pttMode = true

    fun initialize(languageCode: String) {
        this.languageCode = languageCode

        emitStatus("Initializing voice pipelines...")

        pipelineExecutor.execute {
            try {
                /*
                 * STT model/backend initialization.
                 * This can involve asset/model loading, so it stays
                 * on the background executor.
                 */
                sttEngine.initialize(languageCode)

                /*
                 * Model-size calculation can scan files and therefore
                 * also stays away from the UI thread.
                 */
                val sttSize = sttEngine.currentModelSizeMb()
                val ttsSize = ttsEngine.currentModelSizeMb(languageCode)

                resourceMonitor.setPhase(ResourcePhase.IDLE)

                resourceMonitor.updateModelSizes(
                    sttModelSizeMb = sttSize,
                    ttsModelSizeMb = ttsSize,
                )

                resourceMonitor.start()

                initialized.set(true)

                emitEvent(
                    mapOf(
                        "type" to "status",
                        "text" to "Pipelines ready for $languageCode (${sttEngine.backendName})",
                    ),
                )
            } catch (error: Throwable) {
                initialized.set(false)

                emitError(
                    "Pipeline initialization failed: ${error.message ?: error.javaClass.simpleName}"
                )
            }
        }
    }

    fun setLanguage(languageCode: String) {
        pipelineExecutor.execute {
            try {
                this.languageCode = languageCode

                /*
                 * Language/model switching can also be expensive.
                 */
                sttEngine.setLanguage(languageCode)

                val sttSize = sttEngine.currentModelSizeMb()
                val ttsSize = ttsEngine.currentModelSizeMb(languageCode)

                resourceMonitor.updateModelSizes(
                    sttModelSizeMb = sttSize,
                    ttsModelSizeMb = ttsSize,
                )

                emitStatus("Language switched to $languageCode")
            } catch (error: Throwable) {
                emitError(
                    "Language switch failed: ${error.message ?: error.javaClass.simpleName}"
                )
            }
        }
    }

    fun setOperationMode(mode: String) {
        this.mode = mode

        emitStatus("Operation mode set to $mode")
    }

    fun startListening(
        ptt: Boolean,
        messageId: String?,
    ) {
        if (!hasRecordPermission()) {
            emitError("RECORD_AUDIO permission not granted")
            return
        }

        if (!initialized.get()) {
            emitError("Voice pipelines are still initializing. Please try again.")
            return
        }

        if (listening.get()) {
            emitStatus("Already listening")
            return
        }

        pttMode = ptt
        activeMessageId =
            messageId ?: "native-${System.currentTimeMillis()}"

        vadProcessor.reset()

        /*
         * Session creation may initialize native STT objects.
         * Keep it away from the UI thread.
         */
        pipelineExecutor.execute {
            try {
                if (listening.get()) {
                    return@execute
                }

                sttEngine.beginSession()
                listening.set(true)

                resourceMonitor.setPhase(ResourcePhase.STT)

                val started = audioCaptureManager.start(
                    onFrame = ::handleAudioFrame,
                    onError = ::handleAudioError,
                )

                if (!started) {
                    listening.set(false)
                    sttEngine.resetSession()
                    resourceMonitor.setPhase(ResourcePhase.IDLE)

                    emitError("Unable to start microphone capture")
                    return@execute
                }

                emitEvent(
                    mapOf(
                        "type" to "status",
                        "text" to
                            "Listening ($mode, ptt=$ptt, silence=${vadProcessor.silenceThresholdMs()}ms)",
                        "messageId" to activeMessageId,
                    ),
                )
            } catch (error: Throwable) {
                listening.set(false)
                sttEngine.resetSession()
                resourceMonitor.setPhase(ResourcePhase.IDLE)

                emitError(
                    "Unable to start listening: ${error.message ?: error.javaClass.simpleName}"
                )
            }
        }
    }

    fun stopListening() {
        if (!listening.get()) {
            return
        }

        /*
         * Stop the microphone immediately.
         */
        listening.set(false)
        audioCaptureManager.stop()

        /*
         * Final STT decoding can be expensive, so do it in the
         * background pipeline executor.
         */
        pipelineExecutor.execute {
            try {
                finalizeUtterance(reason = "manual_stop")
            } catch (error: Throwable) {
                emitError(
                    "Failed to finalize speech: ${error.message ?: error.javaClass.simpleName}"
                )
            } finally {
                resourceMonitor.setPhase(ResourcePhase.IDLE)
            }
        }
    }

    fun dispose() {
        listening.set(false)

        audioCaptureManager.stop()

        pipelineExecutor.execute {
            try {
                sttEngine.shutdown()
                ttsEngine.shutdown()
                resourceMonitor.stop()
            } catch (_: Throwable) {
            }
        }

        pipelineExecutor.shutdownNow()
    }

    private fun handleAudioFrame(frame: AudioFrame) {
        if (!listening.get()) {
            return
        }

        val decision = vadProcessor.process(frame)

        if (decision.speechStarted) {
            emitEvent(
                mapOf(
                    "type" to "status",
                    "text" to "Speech started",
                    "messageId" to activeMessageId,
                ),
            )
        }

        if (decision.isSpeech) {
            val sttResult = sttEngine.acceptAudio(
                frame.samples,
                frame.sampleRate,
            )

            val partial = sttResult.partial

            if (!partial.isNullOrBlank()) {
                emitEvent(
                    mapOf(
                        "type" to "partial",
                        "text" to partial,
                        "messageId" to activeMessageId,
                    ),
                )
            }
        }

        if (!pttMode && decision.pauseDetected) {
            /*
             * We are already on the audio background thread.
             * Finalization is relatively expensive, so schedule it
             * on the pipeline executor.
             */
            pipelineExecutor.execute {
                if (!listening.get()) {
                    return@execute
                }

                try {
                    finalizeUtterance(reason = "vad_pause")

                    sttEngine.beginSession()

                    activeMessageId =
                        "native-${System.currentTimeMillis()}"
                } catch (error: Throwable) {
                    emitError(
                        "VAD sentence finalization failed: ${error.message}"
                    )
                }
            }
        }
    }

    private fun handleAudioError(reason: String) {
        emitError(reason)

        listening.set(false)
        audioCaptureManager.stop()

        pipelineExecutor.execute {
            try {
                sttEngine.resetSession()
            } catch (_: Throwable) {
            }

            resourceMonitor.setPhase(ResourcePhase.IDLE)
        }
    }

    private fun finalizeUtterance(reason: String) {
        val result = sttEngine.finalizeSession()

        val finalText =
            sentenceManager.finalizeSentence(
                result.finalText.orEmpty()
            )

        val messageId = activeMessageId

        if (messageId != null && finalText.isNotBlank()) {
            emitEvent(
                mapOf(
                    "type" to "final_sentence",
                    "text" to finalText,
                    "messageId" to messageId,
                    "reason" to reason,
                ),
            )
        }

        if (pttMode || reason == "manual_stop") {
            activeMessageId = null
        }
    }

    fun speakText(
        text: String,
        languageCode: String,
        emergency: Boolean,
        messageId: String?,
    ) {
        val resolvedMessageId =
            messageId ?: "tts-${System.currentTimeMillis()}"

        /*
         * TTS itself already handles Android TTS initialization on
         * the main Android handler internally.
         *
         * We only avoid doing model-size/file work here.
         */
        if (emergency) {
            emergencyAudioController.prepareMaxVolume()
        }

        resourceMonitor.setPhase(ResourcePhase.TTS)

        ttsEngine.speak(
            text = text,
            languageCode = languageCode,
            emergency = emergency,
            messageId = resolvedMessageId,
            onPlaybackFinished = {
                if (emergency) {
                    emergencyAudioController.restoreVolume()
                }

                resourceMonitor.setPhase(ResourcePhase.IDLE)
            },
        )
    }

    fun setEmergencyOverride(enabled: Boolean) {
        if (enabled) {
            emergencyAudioController.prepareMaxVolume()
        } else {
            emergencyAudioController.restoreVolume()
        }
    }

    private fun hasRecordPermission(): Boolean {
        return appContext.checkSelfPermission(
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun emitStatus(text: String) {
        emitEvent(
            mapOf(
                "type" to "status",
                "text" to text,
            ),
        )
    }

    private fun emitError(text: String) {
        emitEvent(
            mapOf(
                "type" to "error",
                "text" to text,
                "messageId" to activeMessageId,
            ),
        )
    }
}