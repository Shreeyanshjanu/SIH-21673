package com.sih.voicebridge.pipeline

class SentenceManager {
    fun finalizeSentence(rawText: String): String {
        val compact = rawText.trim().replace(Regex("\\s+"), " ")
        if (compact.isEmpty()) {
            return compact
        }

        val lastChar = compact.last()
        return if (lastChar == '.' || lastChar == '!' || lastChar == '?') {
            compact
        } else {
            "$compact."
        }
    }
}

