package com.sih.voicebridge.pipeline

import android.content.Context
import android.media.AudioManager

class EmergencyAudioController(
    context: Context,
) {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var previousMusicVolume: Int? = null

    fun prepareMaxVolume() {
        if (previousMusicVolume == null) {
            previousMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        }
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, max, 0)
    }

    fun restoreVolume() {
        val previous = previousMusicVolume ?: return
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, previous, 0)
        previousMusicVolume = null
    }
}

