package com.sih.voicebridge.pipeline

import android.Manifest
import android.os.Bundle
import android.os.Debug
import android.os.Process
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.roundToInt

@RunWith(AndroidJUnit4::class)
class NativeSttDeviceTest {
    @get:Rule val microphonePermission: GrantPermissionRule = GrantPermissionRule.grant(Manifest.permission.RECORD_AUDIO)

    @Test fun microphoneStopHandsOffEveryReadSampleBeforeCompletion() {
        val capture = AudioCaptureManager()
        val worker = Executors.newSingleThreadExecutor()
        val queue = BoundedAudioFrameQueue(worker)
        val buffer = PcmUtteranceBuffer()
        val stopRequested = AtomicBoolean(false)
        val firstFrame = CountDownLatch(1)
        val completed = CountDownLatch(1)
        val failure = AtomicReference<String?>(null)
        val captureMetrics = AtomicReference<Map<String, Any?>?>(null)
        try {
            capture.start(
                stopRequested = stopRequested,
                onFrame = { frame ->
                    firstFrame.countDown()
                    queue.offer(frame) { buffer.append(it.samples, it.sampleRate) }
                },
                onError = { failure.set(it) },
                onCompleted = { metrics ->
                    worker.execute {
                        captureMetrics.set(metrics)
                        completed.countDown()
                    }
                },
            )
            assertTrue("No microphone frames arrived", firstFrame.await(10, TimeUnit.SECONDS))
            assertTrue(capture.isCapturing)
            Thread.sleep(250)
            stopRequested.set(true)
            assertTrue("Capture completion did not arrive", completed.await(10, TimeUnit.SECONDS))
            assertNull(failure.get())
            val metrics = captureMetrics.get()!!
            val captured = (metrics["capturedSamples"] as Number).toLong()
            assertTrue(captured > 0)
            assertEquals(captured, buffer.levels.samples)
            assertEquals(captured, (metrics["queuedSamples"] as Number).toLong())
            assertFalse(capture.isCapturing)
            Log.i("ITANTRA_STT_DEVICE", "MICROPHONE_HANDOFF ${JSONObject(metrics)} delivered=${buffer.levels.samples}")
        } finally {
            capture.stop()
            capture.shutdown()
            worker.shutdown()
            worker.awaitTermination(10, TimeUnit.SECONDS)
        }
    }

    @Test fun pttDeliversCompleteMicrophoneUtteranceAndDecodesOnce() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val ready = CountDownLatch(1)
        val recording = CountDownLatch(1)
        val stopped = CountDownLatch(1)
        val available = AtomicBoolean(false)
        val captureMetrics = AtomicReference<Map<String, Any?>?>(null)
        val sttMetrics = AtomicReference<Map<String, Any?>?>(null)
        val failure = AtomicReference<String?>(null)
        val orchestrator = VoicePipelineOrchestrator(context) { event ->
            when (event["type"]) {
                "stt_ready" -> { available.set(event["available"] == true); ready.countDown() }
                "capture_state" -> when (event["state"]) {
                    "recording" -> recording.countDown()
                    "stopped" -> stopped.countDown()
                }
                "capture_metrics" -> captureMetrics.set(event)
                "stt_metrics" -> sttMetrics.set(event)
                "error" -> failure.set(event["text"].toString())
            }
        }
        try {
            orchestrator.initialize("en")
            assertTrue("STT preparation timed out", ready.await(60, TimeUnit.SECONDS))
            assertTrue("Real STT backend is unavailable", available.get())
            orchestrator.startListening(true, "device-ptt", System.currentTimeMillis(), "en")
            assertTrue("Listening was not confirmed by microphone frames", recording.await(10, TimeUnit.SECONDS))
            Thread.sleep(250)
            orchestrator.stopListening("device-ptt")
            assertTrue("PTT finalization timed out", stopped.await(60, TimeUnit.SECONDS))
            assertNull(failure.get())
            val captured = captureMetrics.get()!!
            val recognized = sttMetrics.get()!!
            assertEquals(true, captured["captureValid"])
            assertEquals(true, recognized["recognitionValid"])
            assertTrue((captured["capturedSamples"] as Number).toLong() > 0)
            assertEquals(captured["capturedSamples"], captured["deliveredSamples"])
            assertEquals(captured["capturedSamples"], recognized["deliveredSamples"])
            assertEquals(1, captured["decodeCalls"])
            assertEquals(1, recognized["decodeCalls"])
            assertNotNull(captured["firstFrameLatencyMs"])
            Log.i("ITANTRA_STT_DEVICE", "PTT_HANDOFF ${JSONObject(captured)}")
        } finally {
            orchestrator.dispose()
        }
    }

    @Test fun evaluateFourPhrasesWithInstalledOfflineTtsAndBundledNemo() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val ready = CountDownLatch(1)
        var initStatus = TextToSpeech.ERROR
        lateinit var tts: TextToSpeech
        instrumentation.runOnMainSync {
            tts = TextToSpeech(context) { status -> initStatus = status; ready.countDown() }
        }
        val stt = SttEngine(context) { Log.i("ITANTRA_STT_DEVICE", it) }
        try {
            assertTrue("TTS initialization timed out", ready.await(30, TimeUnit.SECONDS))
            assertEquals(TextToSpeech.SUCCESS, initStatus)
            val voices = tts.voices.orEmpty().filter {
                !it.isNetworkConnectionRequired && it.locale.language == "en" &&
                    TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED !in it.features.orEmpty()
            }
            assumeTrue("No installed offline English TTS voice; human-device phrase validation remains required", voices.isNotEmpty())
            val voice = voices.firstOrNull { it.locale.country == "US" } ?: voices.first()
            assertEquals(TextToSpeech.SUCCESS, tts.setVoice(voice))
            stt.initialize("en")
            assertTrue("Bundled NeMo recognizer did not prepare", stt.recognitionAvailable)
            val results = JSONArray()
            val mismatches = mutableListOf<String>()
            for (phrase in listOf("fire", "wire", "live wire", "not a fire")) {
                val done = CountDownLatch(1)
                val failure = AtomicReference<String?>(null)
                tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {}
                    override fun onDone(utteranceId: String?) { done.countDown() }
                    @Suppress("OVERRIDE_DEPRECATION")
                    override fun onError(utteranceId: String?) { failure.set("TTS synthesis failed"); done.countDown() }
                })
                val wav = File.createTempFile("stt-phrase-", ".wav", context.cacheDir)
                val samples = try {
                    assertEquals(TextToSpeech.SUCCESS, tts.synthesizeToFile(phrase, Bundle(), wav, "validation-$phrase"))
                    assertTrue("TTS synthesis timed out for $phrase", done.await(30, TimeUnit.SECONDS))
                    assertNull(failure.get())
                    readMono16kPcm(wav.readBytes())
                } finally {
                    wav.delete()
                }
                val cpuStartedAt = Process.getElapsedCpuTime()
                stt.beginSession()
                var offset = 0
                while (offset < samples.size) {
                    val end = minOf(offset + 320, samples.size)
                    assertNull(stt.acceptAudio(samples.copyOfRange(offset, end), 16_000).partial)
                    offset = end
                }
                val result = stt.finalizeSession()
                assertNull(result.error)
                assertEquals(1, result.metrics["decodeCalls"])
                assertEquals(samples.size.toLong(), result.metrics["deliveredSamples"])
                assertEquals(true, result.metrics["recognitionValid"])
                val text = result.finalText.orEmpty()
                val matched = text.lowercase(Locale.ROOT).trim().trimEnd('.', '!', '?') == phrase
                if (!matched) mismatches.add("$phrase -> $text")
                val report = JSONObject(result.metrics + mapOf(
                    "expected" to phrase, "recognized" to text, "matched" to matched,
                    "cpuTimeMs" to Process.getElapsedCpuTime() - cpuStartedAt,
                    "processPssMb" to Debug.getPss() / 1024.0,
                ))
                results.put(report)
                Log.i("ITANTRA_STT_DEVICE", "OFFLINE_TTS_PHRASE $report")
            }
            val report = JSONObject(mapOf(
                "source" to "installed_offline_tts_not_human_microphone",
                "voice" to voice.name, "networkVoice" to false,
                "backend" to stt.backendName, "results" to results,
            ))
            File(context.cacheDir, "stt_validation_report.json").writeText(report.toString(2))
            assertTrue("Synthetic-voice recognition mismatches: $mismatches", mismatches.isEmpty())
        } finally {
            stt.shutdown()
            instrumentation.runOnMainSync { tts.shutdown() }
        }
    }

    private fun readMono16kPcm(bytes: ByteArray): ShortArray {
        require(String(bytes, 0, 4, Charsets.US_ASCII) == "RIFF")
        require(String(bytes, 8, 4, Charsets.US_ASCII) == "WAVE")
        val data = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var position = 12
        var sampleRate = 0
        var channels = 0
        var dataStart = 0
        var dataSize = 0
        while (position + 8 <= bytes.size) {
            val name = String(bytes, position, 4, Charsets.US_ASCII)
            val size = data.getInt(position + 4)
            require(size >= 0 && position + 8L + size <= bytes.size)
            if (name == "fmt ") {
                require(size >= 16 && data.getShort(position + 8).toInt() == 1)
                channels = data.getShort(position + 10).toInt()
                sampleRate = data.getInt(position + 12)
                require(data.getShort(position + 22).toInt() == 16)
            } else if (name == "data") {
                dataStart = position + 8
                dataSize = size
            }
            position += 8 + size + size % 2
        }
        require(sampleRate > 0 && channels in 1..2 && dataSize > 0)
        val mono = ShortArray(dataSize / (2 * channels)) { frame ->
            var sum = 0
            for (channel in 0 until channels) sum += data.getShort(dataStart + (frame * channels + channel) * 2)
            (sum / channels).toShort()
        }
        if (sampleRate == 16_000) return mono
        return ShortArray((mono.size.toLong() * 16_000 / sampleRate).toInt()) { index ->
            val sourcePosition = index * sampleRate / 16_000.0
            val left = sourcePosition.toInt().coerceAtMost(mono.lastIndex)
            val right = minOf(left + 1, mono.lastIndex)
            (mono[left] + (mono[right] - mono[left]) * (sourcePosition - left)).roundToInt()
                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
    }
}
