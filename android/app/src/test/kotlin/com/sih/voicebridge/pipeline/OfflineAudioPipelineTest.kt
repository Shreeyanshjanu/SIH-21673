package com.sih.voicebridge.pipeline

import org.junit.Assert.*
import org.junit.Test
import java.util.ArrayDeque
import java.util.concurrent.Executor

class OfflineAudioPipelineTest {
    class FakeStream(private val failAccept: Boolean = false) {
        var samples = floatArrayOf()
        var accepts = 0
        var releases = 0
        fun acceptWaveform(samples: FloatArray, sampleRate: Int) {
            accepts++
            if (failAccept) error("accept failed")
            check(sampleRate == 16_000)
            this.samples = samples.copyOf()
        }
        fun release() { releases++ }
    }

    data class FakeResult(val text: String)

    class FakeRecognizer(val text: String, val failAccept: Boolean = false, val failDecode: Boolean = false) {
        val streams = mutableListOf<FakeStream>()
        var decodes = 0
        fun createStream(): FakeStream = FakeStream(failAccept).also { streams.add(it) }
        fun decode(stream: FakeStream) {
            decodes++
            check(stream.accepts == 1)
            if (failDecode) error("decode failed")
        }
        fun getResult(stream: FakeStream): FakeResult = FakeResult(text)
        fun release() {}
    }

    @Test fun completePcmAndAllFourTextsSurviveOneOfflineDecode() {
        for (text in listOf("fire", "wire", "live wire", "not a fire")) {
            val recognizer = FakeRecognizer(text)
            val session = SherpaOnnxReflectiveSession(OfflineRecognizerApi(recognizer))
            val frames = listOf(ShortArray(320) { 1 }, ShortArray(320) { 12000 }, ShortArray(320), ShortArray(320) { 2 })
            repeat(5) {
                for (frame in frames) assertNull(session.acceptAudio(frame, 16_000))
                assertEquals(0, recognizer.decodes)
                assertTrue(recognizer.streams.isEmpty())
            }
            assertEquals(text, session.finalizeText())
            val expected = (0 until 5).flatMap { frames.flatMap { frame -> frame.toList() } }
                .map { it / 32768.0f }.toFloatArray()
            assertArrayEquals(expected, recognizer.streams.single().samples, 0.0f)
            assertEquals(1, recognizer.decodes)
            assertEquals(1, recognizer.streams.single().accepts)
            assertEquals(1, recognizer.streams.single().releases)
            assertEquals(true, session.metrics["recognitionValid"])
            assertEquals(6400L, session.metrics["deliveredSamples"])
            assertEquals(400.0, session.metrics["audioDurationMs"])
            assertThrows(IllegalStateException::class.java) { session.finalizeText() }
            assertThrows(IllegalStateException::class.java) { session.acceptAudio(shortArrayOf(1), 16_000) }
        }
    }

    @Test fun overflowCannotProduceATruncatedTranscript() {
        val recognizer = FakeRecognizer("must not escape")
        val session = SherpaOnnxReflectiveSession(OfflineRecognizerApi(recognizer), PcmUtteranceBuffer(maxSamples = 4))
        session.acceptAudio(shortArrayOf(1, 2, 3, 4), 16_000)
        assertThrows(IllegalStateException::class.java) { session.acceptAudio(shortArrayOf(5), 16_000) }
        assertThrows(IllegalStateException::class.java) { session.finalizeText() }
        assertEquals(0, recognizer.decodes)
        assertTrue(recognizer.streams.isEmpty())
        assertEquals(false, session.metrics["recognitionValid"])
        assertEquals(true, session.metrics["overflowed"])
    }

    @Test fun waveformAndDecodeExceptionsAreNotReportedAsSuccess() {
        for (failAccept in listOf(true, false)) {
            val recognizer = FakeRecognizer("invalid", failAccept = failAccept, failDecode = !failAccept)
            val session = SherpaOnnxReflectiveSession(OfflineRecognizerApi(recognizer))
            session.acceptAudio(ShortArray(1600) { 2000 }, 16_000)
            val error = assertThrows(IllegalStateException::class.java) { session.finalizeText() }
            assertEquals(if (failAccept) "accept failed" else "decode failed", error.message)
            assertEquals(if (failAccept) 0 else 1, recognizer.decodes)
            assertEquals(1, recognizer.streams.single().releases)
            assertEquals(false, session.metrics["recognitionValid"])
        }
    }

    @Test fun emptyAudioNeverInvokesTheRecognizer() {
        val recognizer = FakeRecognizer("invalid")
        val session = SherpaOnnxReflectiveSession(OfflineRecognizerApi(recognizer))
        assertEquals("", session.finalizeText())
        assertEquals(0, recognizer.decodes)
        assertTrue(recognizer.streams.isEmpty())
    }

    @Test fun pcmScalingLevelsClippingAndSampleRateAreExplicit() {
        val buffer = PcmUtteranceBuffer()
        buffer.append(shortArrayOf(Short.MIN_VALUE, 0, Short.MAX_VALUE), 16_000)
        assertArrayEquals(floatArrayOf(-1.0f, 0.0f, 32767 / 32768.0f), buffer.toFloatArray(), 0.0f)
        val metrics = buffer.levels.toMap(16_000)
        assertEquals(3L, metrics["samples"])
        assertEquals(2L, metrics["clippedSamples"])
        assertEquals(1.0, metrics["peak"])
        assertEquals(0.81648, metrics["rms"] as Double, 0.0001)
        assertThrows(IllegalArgumentException::class.java) { buffer.append(shortArrayOf(1), 48_000) }
    }

    @Test fun preRollKeepsTheLast200msIncludingQuietAudio() {
        val preRoll = AudioPreRoll()
        repeat(20) { index -> preRoll.add(AudioFrame(ShortArray(320) { index.toShort() }, 16_000, index * 20L)) }
        val retained = preRoll.drain()
        assertEquals(3200, retained.sumOf { it.samples.size })
        assertEquals(10.toShort(), retained.first().samples.first())
        assertEquals(19.toShort(), retained.last().samples.last())
        assertTrue(preRoll.drain().isEmpty())
    }

    @Test fun queuedFramesRunBeforeFinalizationAndBacklogIsBounded() {
        val tasks = ArrayDeque<Runnable>()
        val executor = Executor { tasks.addLast(it) }
        val queue = BoundedAudioFrameQueue(executor, maxPendingSamples = 8)
        val delivered = mutableListOf<Short>()
        val first = AudioFrame(shortArrayOf(0, 1, 2, 0), 16_000, 0)
        val last = AudioFrame(shortArrayOf(3, 0, 4, 0), 16_000, 1)
        assertTrue(queue.offer(first) { delivered.addAll(it.samples.toList()) })
        assertTrue(queue.offer(last) { delivered.addAll(it.samples.toList()) })
        assertFalse(queue.offer(first) { fail("Overflowed frame must not be accepted") })
        executor.execute { assertEquals(listOf<Short>(0, 1, 2, 0, 3, 0, 4, 0), delivered) }
        while (tasks.isNotEmpty()) tasks.removeFirst().run()
        assertTrue(queue.offer(first) { throw IllegalStateException("consumer failed") })
        assertThrows(IllegalStateException::class.java) { tasks.removeFirst().run() }
        assertTrue(queue.offer(last) {})
    }

    @Test fun vadUsesAudioDurationInsteadOfCallbackSchedulingGaps() {
        val vad = VadProcessor()
        repeat(15) { vad.process(AudioFrame(ShortArray(320) { 12000 }, 16_000, it * 10000L)) }
        repeat(34) {
            assertFalse(vad.process(AudioFrame(ShortArray(320), 16_000, 999999L)).pauseDetected)
        }
        assertTrue(vad.process(AudioFrame(ShortArray(320), 16_000, 999999L)).pauseDetected)
    }

    @Test fun fallbackNeverFabricatesSpeech() {
        val fallback = FallbackSttSession("en")
        assertNull(fallback.acceptAudio(ShortArray(16000) { 5000 }, 16_000))
        assertEquals("", fallback.finalizeText())
        assertEquals(true, fallback.metrics["fallback"])
        assertEquals(false, fallback.metrics["recognitionValid"])
    }
}
