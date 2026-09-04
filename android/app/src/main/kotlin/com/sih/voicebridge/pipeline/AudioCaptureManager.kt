package com.sih.voicebridge.pipeline

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

data class AudioFrame(
    val samples: ShortArray,
    val sampleRate: Int,
    val timestampMs: Long,
)

class AudioCaptureManager {
    companion object {
        const val SAMPLE_RATE = 16_000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
        private const val FRAME_MS = 20
        private val FRAME_SIZE = (SAMPLE_RATE * FRAME_MS) / 1000
    }

    private val readExecutor = Executors.newSingleThreadExecutor()
    private var readTask: Future<*>? = null
    private var audioRecord: AudioRecord? = null
    private val capturing = AtomicBoolean(false)

    val isCapturing: Boolean
        get() = capturing.get()

    @SuppressLint("MissingPermission")
    fun start(
        onFrame: (AudioFrame) -> Unit,
        onError: (String) -> Unit,
    ): Boolean {
        if (capturing.get()) {
            return true
        }

        val minBufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            ENCODING,
        )

        if (minBufferSize <= 0) {
            onError("AudioRecord min buffer size unavailable: $minBufferSize")
            return false
        }

        val bufferSize = max(minBufferSize, FRAME_SIZE * 8)
        val record = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            ENCODING,
            bufferSize,
        )

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            onError("AudioRecord initialization failed")
            record.release()
            return false
        }

        audioRecord = record
        capturing.set(true)

        try {
            record.startRecording()
        } catch (error: IllegalStateException) {
            capturing.set(false)
            record.release()
            audioRecord = null
            onError("Failed to start recording: ${error.message}")
            return false
        }

        readTask = readExecutor.submit {
            try {
                val frameBuffer = ShortArray(FRAME_SIZE)
                while (capturing.get()) {
                    val samplesRead = record.read(frameBuffer, 0, frameBuffer.size)
                    if (samplesRead > 0) {
                        onFrame(
                            AudioFrame(
                                samples = frameBuffer.copyOf(samplesRead),
                                sampleRate = SAMPLE_RATE,
                                timestampMs = System.currentTimeMillis(),
                            ),
                        )
                    } else if (samplesRead < 0) {
                        onError("AudioRecord read error: $samplesRead")
                        break
                    }
                }
            } catch (error: Throwable) {
                if (capturing.get()) {
                    onError("Audio capture failure: ${error.message}")
                }
            }
        }

        return true
    }

    fun stop() {
        if (!capturing.getAndSet(false)) {
            return
        }

        readTask?.cancel(true)
        readTask = null

        val record = audioRecord
        audioRecord = null

        if (record != null) {
            try {
                record.stop()
            } catch (_: IllegalStateException) {
            }
            record.release()
        }
    }
}
