package com.sih.voicebridge.pipeline

import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Method

class OfflineRecognizerApi(private val recognizer: Any) {
    private val createStream = recognizer.javaClass.getMethod("createStream")
    private val streamType = createStream.returnType
    private val acceptWaveform = streamType.getMethod(
        "acceptWaveform", FloatArray::class.java, Int::class.javaPrimitiveType!!,
    )
    private val decode = recognizer.javaClass.getMethod("decode", streamType)
    private val getResult = recognizer.javaClass.getMethod("getResult", streamType)
    private val getText = getResult.returnType.getMethod("getText")
    private val releaseStream = streamType.getMethod("release")
    private val releaseRecognizer = recognizer.javaClass.getMethod("release")

    init {
        check(acceptWaveform.returnType == Void.TYPE && decode.returnType == Void.TYPE) {
            "Unexpected Sherpa offline API signatures"
        }
    }

    fun recognize(samples: FloatArray, sampleRate: Int, onDecode: (() -> String) -> String): String {
        val stream = invoke(createStream, recognizer) ?: error("Sherpa createStream() returned null")
        try {
            invoke(acceptWaveform, stream, samples, sampleRate)
            return onDecode {
                invoke(decode, recognizer, stream)
                val result = invoke(getResult, recognizer, stream) ?: error("Sherpa getResult() returned null")
                invoke(getText, result) as? String ?: error("Sherpa result text is not a String")
            }.trim()
        } finally {
            invoke(releaseStream, stream)
        }
    }

    fun release() { invoke(releaseRecognizer, recognizer) }

    private fun invoke(method: Method, target: Any, vararg arguments: Any?): Any? {
        return try { method.invoke(target, *arguments) }
        catch (error: InvocationTargetException) { throw error.targetException }
    }
}

class SherpaOnnxReflectiveSession(
    private val api: OfflineRecognizerApi,
    private val buffer: PcmUtteranceBuffer = PcmUtteranceBuffer(),
) : StreamingSttSession {
    private var completed = false
    private var decodeCalls = 0
    private var decodeDurationMs = 0.0
    private var processingDurationMs = 0.0
    private var recognitionValid = false

    override val metrics: Map<String, Any>
        get() = buffer.levels.toMap(buffer.sampleRate) + mapOf(
            "deliveredSamples" to buffer.levels.samples,
            "decodeCalls" to decodeCalls,
            "decodeDurationMs" to decodeDurationMs,
            "processingDurationMs" to processingDurationMs,
            "recognitionValid" to recognitionValid,
            "overflowed" to buffer.overflowed,
            "fallback" to false,
        )

    @Synchronized
    override fun acceptAudio(samples: ShortArray, sampleRate: Int): String? {
        check(!completed) { "Cannot append to a completed STT session" }
        buffer.append(samples, sampleRate)
        return null
    }

    @Synchronized
    override fun finalizeText(): String {
        check(!completed) { "STT session has already been finalized" }
        completed = true
        val startedAt = System.nanoTime()
        try {
            val samples = buffer.toFloatArray()
            if (samples.isEmpty()) return ""
            val text = api.recognize(samples, buffer.sampleRate) { decode ->
                decodeCalls++
                val decodeStartedAt = System.nanoTime()
                try { decode() }
                finally { decodeDurationMs = (System.nanoTime() - decodeStartedAt) / 1_000_000.0 }
            }
            recognitionValid = true
            return text
        } finally {
            processingDurationMs = (System.nanoTime() - startedAt) / 1_000_000.0
            buffer.clear()
        }
    }

    @Synchronized
    override fun close() {
        completed = true
        buffer.clear()
    }
}
