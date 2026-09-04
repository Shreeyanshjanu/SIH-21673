package com.sih.voicebridge.pipeline

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.ArrayDeque
import java.util.Locale

private enum class AndroidTtsInitState {
    INITIALIZING,
    READY,
    FAILED,
}

private data class PendingTtsRequest(
    val text: String,
    val languageCode: String,
    val emergency: Boolean,
    val messageId: String,
    val onPlaybackFinished: (() -> Unit)?,
)

private interface TtsBackend {
    val backendName: String

    fun speak(request: PendingTtsRequest): Boolean

    fun shutdown()
}

private data class TtsModelSpec(
    val languageCode: String,
    val backend: String,
    val modelAssetPath: String?,
    val tokensAssetPath: String?,
    val dataDirAssetPath: String?,
    val lexiconAssetPath: String?,
)

private data class ResolvedTtsModel(
    val languageCode: String,
    val backend: String,
    val modelFile: File?,
    val tokensFile: File?,
    val dataDir: File?,
    val lexiconFile: File?,
)

private class TtsModelResolver(
    private val context: Context,
    private val emitStatus: (String) -> Unit,
) {
    companion object {
        private const val FLUTTER_ASSET_PREFIX = "flutter_assets/"
        private const val MANIFEST_RELATIVE_PATH = "assets/models/tts/model_manifest.json"
    }

    private var loadedManifest: Map<String, TtsModelSpec> = emptyMap()
    private var manifestLoaded = false

    fun resolve(languageCode: String): ResolvedTtsModel? {
        val manifest = loadManifest()
        if (manifest.isEmpty()) {
            return null
        }

        val spec = manifest[languageCode.lowercase()] ?: return null
        return ResolvedTtsModel(
            languageCode = spec.languageCode,
            backend = spec.backend,
            modelFile = copyOptional(spec.modelAssetPath),
            tokensFile = copyOptional(spec.tokensAssetPath),
            dataDir = copyDirectoryOptional(spec.dataDirAssetPath),
            lexiconFile = copyOptional(spec.lexiconAssetPath),
        )
    }

    private fun loadManifest(): Map<String, TtsModelSpec> {
        if (manifestLoaded) {
            return loadedManifest
        }

        manifestLoaded = true

        val manifestPayload = try {
            context.assets.open("$FLUTTER_ASSET_PREFIX$MANIFEST_RELATIVE_PATH")
                .bufferedReader()
                .use { it.readText() }
        } catch (_: Throwable) {
            emitStatus("TTS manifest not found at $MANIFEST_RELATIVE_PATH. Using Android TTS fallback.")
            loadedManifest = emptyMap()
            return loadedManifest
        }

        loadedManifest = try {
            parseManifest(manifestPayload)
        } catch (error: JSONException) {
            emitStatus("Invalid TTS manifest JSON: ${error.message}")
            emptyMap()
        }

        return loadedManifest
    }

    @Throws(JSONException::class)
    private fun parseManifest(payload: String): Map<String, TtsModelSpec> {
        val root = JSONObject(payload)
        val languages = if (root.has("languages")) {
            root.getJSONObject("languages")
        } else {
            root
        }

        val table = mutableMapOf<String, TtsModelSpec>()
        val keys = languages.keys()
        while (keys.hasNext()) {
            val languageCode = keys.next()
            val node = languages.optJSONObject(languageCode) ?: continue

            table[languageCode.lowercase()] = TtsModelSpec(
                languageCode = languageCode.lowercase(),
                backend = node.optString("backend", "android_tts"),
                modelAssetPath = pickFirstNonBlank(node.optString("model", ""), node.optString("modelAsset", "")),
                tokensAssetPath = pickFirstNonBlank(node.optString("tokens", ""), node.optString("tokensAsset", "")),
                dataDirAssetPath = pickFirstNonBlank(node.optString("data", ""), node.optString("dataDir", "")),
                lexiconAssetPath = pickFirstNonBlank(node.optString("lexicon", ""), node.optString("lexiconAsset", "")),
            )
        }

        return table
    }

    private fun copyOptional(assetPath: String?): File? {
        if (assetPath.isNullOrBlank()) {
            return null
        }

        val normalized = assetPath.trim().removePrefix("/")
        val flutterAssetPath = "$FLUTTER_ASSET_PREFIX$normalized"
        val target = File(context.filesDir, "tts_models/$normalized")

        if (target.exists() && target.length() > 0L) {
            return target
        }

        return try {
            target.parentFile?.mkdirs()
            context.assets.open(flutterAssetPath).use { input ->
                FileOutputStream(target).use { output ->
                    input.copyTo(output)
                }
            }
            target
        } catch (_: Throwable) {
            null
        }
    }

    private fun copyDirectoryOptional(assetPath: String?): File? {
        if (assetPath.isNullOrBlank()) {
            return null
        }

        val normalized = assetPath.trim().removePrefix("/").trimEnd('/')
        val flutterPrefix = "$FLUTTER_ASSET_PREFIX$normalized"
        val targetDir = File(context.filesDir, "tts_models/$normalized")
        targetDir.mkdirs()

        val children = try {
            context.assets.list(flutterPrefix)
        } catch (_: Throwable) {
            null
        } ?: return null

        for (child in children) {
            val childAssetPath = "$flutterPrefix/$child"
            val childFile = File(targetDir, child)
            if (childFile.exists() && childFile.length() > 0L) {
                continue
            }
            try {
                context.assets.open(childAssetPath).use { input ->
                    FileOutputStream(childFile).use { output ->
                        input.copyTo(output)
                    }
                }
            } catch (_: Throwable) {
                return null
            }
        }

        return targetDir
    }

    private fun pickFirstNonBlank(vararg values: String?): String? {
        for (value in values) {
            if (!value.isNullOrBlank()) {
                return value
            }
        }
        return null
    }
}

private class AndroidSystemTtsBackend(
    private val context: Context,
    private val emitEvent: (Map<String, Any?>) -> Unit,
    private val emitStatus: (String) -> Unit,
    private val emitError: (String?, String) -> Unit,
) : TtsBackend {
    override val backendName: String = "android_tts"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingQueue = ArrayDeque<PendingTtsRequest>()
    private val activeByUtteranceId = mutableMapOf<String, PendingTtsRequest>()

    private var initState = AndroidTtsInitState.INITIALIZING
    private var textToSpeech: TextToSpeech? = null

    init {
        mainHandler.post {
            initialize()
        }
    }

    override fun speak(request: PendingTtsRequest): Boolean {
        mainHandler.post {
            when (initState) {
                AndroidTtsInitState.READY -> speakInternal(request)
                AndroidTtsInitState.INITIALIZING -> pendingQueue.addLast(request)
                AndroidTtsInitState.FAILED -> {
                    emitError(request.messageId, "Android TextToSpeech unavailable")
                    request.onPlaybackFinished?.invoke()
                }
            }
        }
        return true
    }

    override fun shutdown() {
        mainHandler.post {
            for (request in activeByUtteranceId.values) {
                request.onPlaybackFinished?.invoke()
            }
            activeByUtteranceId.clear()

            while (pendingQueue.isNotEmpty()) {
                pendingQueue.removeFirst().onPlaybackFinished?.invoke()
            }

            textToSpeech?.stop()
            textToSpeech?.shutdown()
            textToSpeech = null
            initState = AndroidTtsInitState.FAILED
        }
    }

    private fun initialize() {
        if (textToSpeech != null) {
            return
        }

        textToSpeech = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                initState = AndroidTtsInitState.READY
                textToSpeech?.setOnUtteranceProgressListener(progressListener())
                emitStatus("Native Android TTS initialized")
                flushPending()
            } else {
                initState = AndroidTtsInitState.FAILED
                emitError(null, "TTS initialization failed (status=$status)")
                while (pendingQueue.isNotEmpty()) {
                    pendingQueue.removeFirst().onPlaybackFinished?.invoke()
                }
            }
        }
    }

    private fun flushPending() {
        while (pendingQueue.isNotEmpty()) {
            speakInternal(pendingQueue.removeFirst())
        }
    }

    private fun speakInternal(request: PendingTtsRequest) {
        val tts = textToSpeech
        if (tts == null || initState != AndroidTtsInitState.READY) {
            pendingQueue.addLast(request)
            return
        }

        val localeStatus = tts.setLanguage(localeForCode(request.languageCode))
        if (localeStatus == TextToSpeech.LANG_NOT_SUPPORTED ||
            localeStatus == TextToSpeech.LANG_MISSING_DATA
        ) {
            tts.setLanguage(Locale.US)
            emitStatus("TTS locale ${request.languageCode} unavailable, falling back to en-US")
        }

        emitEvent(
            mapOf(
                "type" to "tts_started",
                "text" to request.text,
                "languageCode" to request.languageCode,
                "messageId" to request.messageId,
                "emergency" to request.emergency,
                "backend" to backendName,
            ),
        )

        val utteranceId = "utt-${request.messageId}-${System.nanoTime()}"
        activeByUtteranceId[utteranceId] = request

        val params = Bundle().apply {
            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, if (request.emergency) 1.0f else 0.9f)
        }
        val queueMode = if (request.emergency) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD

        val result = tts.speak(request.text, queueMode, params, utteranceId)
        if (result == TextToSpeech.ERROR) {
            activeByUtteranceId.remove(utteranceId)
            emitError(request.messageId, "TTS speak() returned error")
            request.onPlaybackFinished?.invoke()
        }
    }

    private fun progressListener(): UtteranceProgressListener {
        return object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                val request = getRequest(utteranceId) ?: return
                emitEvent(
                    mapOf(
                        "type" to "audio_started",
                        "text" to request.text,
                        "messageId" to request.messageId,
                        "emergency" to request.emergency,
                        "backend" to backendName,
                    ),
                )
            }

            override fun onDone(utteranceId: String?) {
                removeRequest(utteranceId)?.onPlaybackFinished?.invoke()
            }

            override fun onStop(utteranceId: String?, interrupted: Boolean) {
                if (interrupted) {
                    emitStatus("TTS playback interrupted")
                }
                removeRequest(utteranceId)?.onPlaybackFinished?.invoke()
            }

            override fun onError(utteranceId: String?) {
                val request = removeRequest(utteranceId)
                emitError(request?.messageId, "TTS playback error")
                request?.onPlaybackFinished?.invoke()
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                val request = removeRequest(utteranceId)
                emitError(request?.messageId, "TTS playback error code=$errorCode")
                request?.onPlaybackFinished?.invoke()
            }
        }
    }

    private fun getRequest(utteranceId: String?): PendingTtsRequest? {
        if (utteranceId.isNullOrBlank()) {
            return null
        }
        return activeByUtteranceId[utteranceId]
    }

    private fun removeRequest(utteranceId: String?): PendingTtsRequest? {
        if (utteranceId.isNullOrBlank()) {
            return null
        }
        return activeByUtteranceId.remove(utteranceId)
    }

    private fun localeForCode(languageCode: String): Locale {
        return when (languageCode.lowercase()) {
            "en" -> Locale.US
            "hi" -> Locale("hi", "IN")
            "gu" -> Locale("gu", "IN")
            "mr" -> Locale("mr", "IN")
            "kn" -> Locale("kn", "IN")
            "ml" -> Locale("ml", "IN")
            "ta" -> Locale("ta", "IN")
            "te" -> Locale("te", "IN")
            "bn" -> Locale("bn", "IN")
            "or" -> Locale("or", "IN")
            else -> Locale.forLanguageTag(languageCode)
        }
    }
}

private class PiperSherpaTtsBackend(
    private val modelResolver: TtsModelResolver,
    private val emitEvent: (Map<String, Any?>) -> Unit,
    private val emitStatus: (String) -> Unit,
    private val emitError: (String?, String) -> Unit,
) : TtsBackend {
    override val backendName: String = "piper_sherpa"

    private var probeDone = false
    private var available = false
    private var warnedUnavailable = false

    override fun speak(request: PendingTtsRequest): Boolean {
        if (!isAvailable()) {
            if (!warnedUnavailable) {
                emitStatus("Piper/Sherpa TTS classes unavailable. Falling back to Android TTS.")
                warnedUnavailable = true
            }
            return false
        }

        val model = modelResolver.resolve(request.languageCode)
        if (model == null || model.backend.lowercase() != backendName) {
            return false
        }

        val modelFile = model.modelFile
        if (modelFile == null || !modelFile.exists()) {
            emitStatus("Piper model missing for ${request.languageCode}. Falling back to Android TTS.")
            return false
        }

        val success = synthesizeWithReflection(request, model)
        if (!success) {
            emitStatus("Piper reflective synthesis unavailable for current Sherpa API. Falling back.")
            return false
        }

        return true
    }

    override fun shutdown() {
    }

    private fun isAvailable(): Boolean {
        if (probeDone) {
            return available
        }

        probeDone = true
        available = try {
            Class.forName("com.k2fsa.sherpa.onnx.OfflineTts")
            true
        } catch (_: Throwable) {
            false
        }
        return available
    }

    private fun synthesizeWithReflection(request: PendingTtsRequest, model: ResolvedTtsModel): Boolean {
        return try {
            val offlineTtsClass = Class.forName("com.k2fsa.sherpa.onnx.OfflineTts")
            val methods = offlineTtsClass.methods + offlineTtsClass.declaredMethods

            val factoryMethod = methods.firstOrNull { method ->
                method.name.equals("create", ignoreCase = true) &&
                    method.parameterTypes.any { type -> type == String::class.java }
            }

            if (factoryMethod == null) {
                return false
            }

            val args = factoryMethod.parameterTypes.map { type ->
                when {
                    type == String::class.java -> model.modelFile?.absolutePath ?: ""
                    type == Boolean::class.javaPrimitiveType || type == Boolean::class.java -> false
                    type == Int::class.javaPrimitiveType || type == Int::class.java -> 0
                    type == Float::class.javaPrimitiveType || type == Float::class.java -> 1.0f
                    else -> null
                }
            }.toTypedArray()

            factoryMethod.isAccessible = true
            val offlineTts = factoryMethod.invoke(null, *args) ?: return false

            val synthesizeMethod = (offlineTts.javaClass.methods + offlineTts.javaClass.declaredMethods)
                .firstOrNull { method ->
                    method.name.contains("synth", ignoreCase = true) && method.parameterTypes.isNotEmpty()
                } ?: return false

            val synthArgs = synthesizeMethod.parameterTypes.mapIndexed { index, type ->
                when {
                    index == 0 && type == String::class.java -> request.text
                    type == Int::class.javaPrimitiveType || type == Int::class.java -> 0
                    type == Float::class.javaPrimitiveType || type == Float::class.java -> 1.0f
                    type == Boolean::class.javaPrimitiveType || type == Boolean::class.java -> false
                    else -> null
                }
            }.toTypedArray()

            synthesizeMethod.isAccessible = true
            synthesizeMethod.invoke(offlineTts, *synthArgs)

            emitEvent(
                mapOf(
                    "type" to "tts_started",
                    "text" to request.text,
                    "languageCode" to request.languageCode,
                    "messageId" to request.messageId,
                    "emergency" to request.emergency,
                    "backend" to backendName,
                ),
            )

            emitEvent(
                mapOf(
                    "type" to "audio_started",
                    "text" to request.text,
                    "messageId" to request.messageId,
                    "emergency" to request.emergency,
                    "backend" to backendName,
                ),
            )

            invokeOptional(offlineTts, "close")
            invokeOptional(offlineTts, "release")

            request.onPlaybackFinished?.invoke()
            true
        } catch (error: Throwable) {
            emitError(request.messageId, "Piper reflective synthesis failed: ${error.message}")
            false
        }
    }

    private fun invokeOptional(target: Any, methodName: String) {
        val method = (target.javaClass.methods + target.javaClass.declaredMethods).firstOrNull {
            it.name.equals(methodName, ignoreCase = true) && it.parameterTypes.isEmpty()
        } ?: return

        try {
            method.isAccessible = true
            method.invoke(target)
        } catch (_: Throwable) {
        }
    }
}

class TtsEngine(
    context: Context,
    private val emitEvent: (Map<String, Any?>) -> Unit,
    private val emitStatus: (String) -> Unit,
) {
    private val appContext = context.applicationContext
    private val modelResolver = TtsModelResolver(appContext, emitStatus)

    private val androidBackend = AndroidSystemTtsBackend(
        context = appContext,
        emitEvent = emitEvent,
        emitStatus = emitStatus,
        emitError = ::emitError,
    )

    private val piperBackend = PiperSherpaTtsBackend(
        modelResolver = modelResolver,
        emitEvent = emitEvent,
        emitStatus = emitStatus,
        emitError = ::emitError,
    )

    fun currentModelSizeMb(languageCode: String): Double? {
        val model = modelResolver.resolve(languageCode) ?: return null
        val backend = model.backend.lowercase()
        if (backend != "piper_sherpa" && backend != "piper" && backend != "sherpa_piper") {
            return null
        }

        val files = listOf(
            model.modelFile,
            model.tokensFile,
            model.lexiconFile,
        )

        var bytes = 0L
        for (file in files) {
            if (file != null && file.exists()) {
                bytes += file.length()
            }
        }

        bytes += directorySize(model.dataDir)

        if (bytes <= 0L) {
            return null
        }

        return bytes / (1024.0 * 1024.0)
    }

    fun speak(
        text: String,
        languageCode: String,
        emergency: Boolean,
        messageId: String,
        onPlaybackFinished: (() -> Unit)? = null,
    ) {
        val request = PendingTtsRequest(
            text = text,
            languageCode = languageCode,
            emergency = emergency,
            messageId = messageId,
            onPlaybackFinished = onPlaybackFinished,
        )

        val backend = selectBackendFor(languageCode)
        val spoken = backend.speak(request)
        if (!spoken && backend !== androidBackend) {
            androidBackend.speak(request)
        }
    }

    fun shutdown() {
        piperBackend.shutdown()
        androidBackend.shutdown()
    }

    private fun selectBackendFor(languageCode: String): TtsBackend {
        val model = modelResolver.resolve(languageCode)
        val backend = model?.backend?.lowercase() ?: "android_tts"
        return when (backend) {
            "piper_sherpa", "piper", "sherpa_piper" -> piperBackend
            else -> androidBackend
        }
    }

    private fun emitError(messageId: String?, text: String) {
        emitEvent(
            mapOf(
                "type" to "error",
                "text" to text,
                "messageId" to messageId,
            ),
        )
    }

    private fun directorySize(directory: File?): Long {
        if (directory == null || !directory.exists()) {
            return 0L
        }
        if (!directory.isDirectory) {
            return directory.length()
        }

        var bytes = 0L
        val children = directory.listFiles() ?: return 0L
        for (child in children) {
            bytes += directorySize(child)
        }
        return bytes
    }
}
