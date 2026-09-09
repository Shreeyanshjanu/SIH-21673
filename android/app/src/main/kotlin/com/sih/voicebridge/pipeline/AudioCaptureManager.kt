package com.sih.voicebridge.pipeline

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

data class AudioFrame(
    val samples: ShortArray,
    val sampleRate: Int,
    val timestampMs: Long,
    val readAtEpochMs: Long = timestampMs,
)

class AudioCaptureManager {
    companion object {
        const val SAMPLE_RATE = PcmUtteranceBuffer.SAMPLE_RATE
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
        private const val FRAME_SIZE = SAMPLE_RATE / 50
        private const val BYTES_PER_SAMPLE = 2
    }

    private val readExecutor = Executors.newSingleThreadExecutor()
    private val capturing = AtomicBoolean(false)
    @Volatile private var stopSignal: AtomicBoolean? = null

    val isCapturing: Boolean get() = capturing.get()

    @SuppressLint("MissingPermission")
    fun start(
        stopRequested: AtomicBoolean,
        onFrame: (AudioFrame) -> Boolean,
        onError: (String) -> Unit,
        onCompleted: (Map<String, Any?>) -> Unit,
    ) {
        check(!capturing.get()) { "Microphone is already recording" }
        val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, ENCODING)
        check(minBufferSize > 0) { "AudioRecord min buffer size unavailable: $minBufferSize" }
        val bufferSize = max(minBufferSize, FRAME_SIZE * BYTES_PER_SAMPLE * 4)
        val record = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            SAMPLE_RATE, CHANNEL_CONFIG, ENCODING, bufferSize,
        )
        try {
            check(record.state == AudioRecord.STATE_INITIALIZED) { "AudioRecord initialization failed" }
            check(record.sampleRate == SAMPLE_RATE && record.channelCount == 1 && record.audioFormat == ENCODING) {
                "Unexpected capture format: ${record.sampleRate} Hz, ${record.channelCount} channels, ${record.audioFormat}"
            }
            val actualSampleRate = record.sampleRate
            val actualBufferSizeFrames = record.bufferSizeInFrames
            stopSignal = stopRequested
            record.startRecording()
            check(record.recordingState == AudioRecord.RECORDSTATE_RECORDING) { "AudioRecord did not start recording" }
            val recordingStartedAt = System.currentTimeMillis()
            capturing.set(true)
            readExecutor.execute {
                val levels = AudioLevels()
                var queuedSamples = 0L
                var firstFrameAt: Long? = null
                var failure: String? = null
                val frameBuffer = ShortArray(FRAME_SIZE)

                fun readFrame(readMode: Int): Boolean {
                    val samplesRead = record.read(frameBuffer, 0, frameBuffer.size, readMode)
                    if (samplesRead < 0) error("AudioRecord read error: $samplesRead")
                    if (samplesRead == 0) return false
                    val readAt = System.currentTimeMillis()
                    if (firstFrameAt == null) firstFrameAt = readAt
                    val frame = AudioFrame(
                        samples = frameBuffer.copyOf(samplesRead),
                        sampleRate = SAMPLE_RATE,
                        timestampMs = recordingStartedAt + levels.samples * 1000L / SAMPLE_RATE,
                        readAtEpochMs = readAt,
                    )
                    levels.add(frame.samples)
                    check(onFrame(frame)) { "Audio queue exceeded its 5-second limit; capture aborted, not truncated" }
                    queuedSamples += samplesRead
                    return true
                }

                try {
                    while (!stopRequested.get()) readFrame(AudioRecord.READ_BLOCKING)
                    val maxDrainReads = (actualBufferSizeFrames / FRAME_SIZE + 2).coerceAtMost(100)
                    var drained = false
                    for (drainIndex in 0 until maxDrainReads) {
                        if (!readFrame(AudioRecord.READ_NON_BLOCKING)) {
                            drained = true
                            break
                        }
                    }
                    check(drained) { "Microphone drain limit exceeded; utterance discarded, not truncated" }
                } catch (error: Throwable) {
                    failure = error.message ?: error.javaClass.simpleName
                    onError(failure)
                } finally {
                    try {
                        record.stop()
                    } catch (error: Throwable) {
                        if (failure == null) {
                            failure = "AudioRecord stop failed: ${error.message}"
                            onError(failure)
                        }
                    } finally {
                        record.release()
                        capturing.set(false)
                        stopSignal = null
                    }
                    onCompleted(levels.toMap(SAMPLE_RATE) + mapOf(
                        "capturedSamples" to levels.samples,
                        "queuedSamples" to queuedSamples,
                        "capturedDurationMs" to levels.samples * 1000.0 / SAMPLE_RATE,
                        "recordingStartedEpochMs" to recordingStartedAt,
                        "firstFrameEpochMs" to firstFrameAt,
                        "captureFinishedEpochMs" to System.currentTimeMillis(),
                        "sampleRate" to actualSampleRate,
                        "bufferSizeBytes" to bufferSize,
                        "actualBufferSizeFrames" to actualBufferSizeFrames,
                        "captureError" to failure,
                    ))
                }
            }
        } catch (error: Throwable) {
            capturing.set(false)
            stopSignal = null
            runCatching { record.stop() }
            record.release()
            throw error
        }
    }

    fun stop() { stopSignal?.set(true) }

    fun shutdown() {
        stop()
        readExecutor.shutdown()
    }
}
