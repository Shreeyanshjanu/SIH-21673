package com.sih.voicebridge.pipeline

import java.util.ArrayDeque
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.abs
import kotlin.math.sqrt

class AudioLevels {
    var samples: Long = 0
        private set
    private var sumSquares = 0.0
    private var peakAmplitude = 0
    private var fullScaleSamples = 0L

    fun add(audio: ShortArray) {
        for (sample in audio) {
            val amplitude = sample.toInt()
            sumSquares += amplitude.toDouble() * amplitude
            peakAmplitude = maxOf(peakAmplitude, abs(amplitude))
            if (sample == Short.MIN_VALUE || sample == Short.MAX_VALUE) fullScaleSamples++
        }
        samples += audio.size
    }

    fun toMap(sampleRate: Int): Map<String, Any> = mapOf(
        "samples" to samples,
        "audioDurationMs" to samples * 1000.0 / sampleRate,
        "rms" to if (samples == 0L) 0.0 else sqrt(sumSquares / samples) / 32768.0,
        "peak" to peakAmplitude / 32768.0,
        "clippedSamples" to fullScaleSamples,
        "clippingPercent" to if (samples == 0L) 0.0 else fullScaleSamples * 100.0 / samples,
    )
}

class PcmUtteranceBuffer(
    val sampleRate: Int = SAMPLE_RATE,
    private val maxSamples: Int = sampleRate * MAX_DURATION_SECONDS,
) {
    companion object {
        const val SAMPLE_RATE = 16_000
        const val MAX_DURATION_SECONDS = 30
    }

    private val chunks = ArrayList<ShortArray>()
    val levels = AudioLevels()
    var overflowed = false
        private set

    init { require(sampleRate > 0 && maxSamples > 0) }

    fun append(samples: ShortArray, rate: Int) {
        check(!overflowed) { "This utterance already exceeded its PCM limit" }
        require(rate == sampleRate) { "Expected $sampleRate Hz PCM, received $rate Hz" }
        if (levels.samples + samples.size > maxSamples) {
            overflowed = true
            chunks.clear()
            error("PCM limit exceeded (${maxSamples * 1000L / sampleRate} ms); utterance discarded, not truncated")
        }
        if (samples.isNotEmpty()) {
            chunks.add(samples.copyOf())
            levels.add(samples)
        }
    }

    fun toFloatArray(): FloatArray {
        check(!overflowed) { "Cannot decode an overflowed utterance" }
        val result = FloatArray(levels.samples.toInt())
        var offset = 0
        for (chunk in chunks) {
            for (sample in chunk) result[offset++] = sample / 32768.0f
        }
        return result
    }

    fun clear() { chunks.clear() }
}

class AudioPreRoll(private val maxSamples: Int = PcmUtteranceBuffer.SAMPLE_RATE / 5) {
    private val frames = ArrayDeque<AudioFrame>()
    private var sampleCount = 0

    fun add(frame: AudioFrame) {
        frames.addLast(frame)
        sampleCount += frame.samples.size
        while (sampleCount > maxSamples && frames.isNotEmpty()) {
            val first = frames.removeFirst()
            val excess = sampleCount - maxSamples
            if (first.samples.size > excess) {
                frames.addFirst(first.copy(
                    samples = first.samples.copyOfRange(excess, first.samples.size),
                    timestampMs = first.timestampMs + excess * 1000L / first.sampleRate,
                ))
                sampleCount -= excess
            } else {
                sampleCount -= first.samples.size
            }
        }
    }

    fun drain(): List<AudioFrame> {
        val result = frames.toList()
        frames.clear()
        sampleCount = 0
        return result
    }
}

class BoundedAudioFrameQueue(
    private val executor: Executor,
    private val maxPendingSamples: Int = PcmUtteranceBuffer.SAMPLE_RATE * 5,
) {
    private val pendingSamples = AtomicInteger(0)

    fun offer(frame: AudioFrame, consume: (AudioFrame) -> Unit): Boolean {
        if (pendingSamples.addAndGet(frame.samples.size) > maxPendingSamples) {
            pendingSamples.addAndGet(-frame.samples.size)
            return false
        }
        try {
            executor.execute {
                try { consume(frame) }
                finally { pendingSamples.addAndGet(-frame.samples.size) }
            }
        } catch (error: RuntimeException) {
            pendingSamples.addAndGet(-frame.samples.size)
            throw error
        }
        return true
    }
}
