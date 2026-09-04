package com.sih.voicebridge.pipeline

import android.app.ActivityManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

enum class ResourcePhase {
    IDLE,
    STT,
    TTS,
}

private data class PhaseAccumulator(
    var cpuSum: Double = 0.0,
    var cpuCount: Int = 0,
    var ramSum: Double = 0.0,
    var ramCount: Int = 0,
) {
    fun addSample(cpuPercent: Double?, ramMb: Double) {
        if (cpuPercent != null) {
            cpuSum += cpuPercent
            cpuCount += 1
        }
        ramSum += ramMb
        ramCount += 1
    }

    fun averageCpuPercent(): Double? {
        if (cpuCount <= 0) {
            return null
        }
        return cpuSum / cpuCount
    }

    fun averageRamMb(): Double? {
        if (ramCount <= 0) {
            return null
        }
        return ramSum / ramCount
    }
}

class ResourceMonitor(
    context: Context,
    private val emitEvent: (Map<String, Any?>) -> Unit,
) {
    private val appContext = context.applicationContext
    private val activityManager = appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val processorCount = max(1, Runtime.getRuntime().availableProcessors())

    private var currentPhase = ResourcePhase.IDLE
    private var running = false
    private var peakRamMb = 0.0
    private var lastCpuTimeMs: Long? = null
    private var lastWallClockMs: Long? = null

    private var sttModelSizeMb: Double? = null
    private var ttsModelSizeMb: Double? = null
    private var apkSizeMb: Double? = apkSizeMb()

    private val phaseStats = mutableMapOf(
        ResourcePhase.IDLE to PhaseAccumulator(),
        ResourcePhase.STT to PhaseAccumulator(),
        ResourcePhase.TTS to PhaseAccumulator(),
    )

    private val sampler = object : Runnable {
        override fun run() {
            sampleAndEmit()
            if (running) {
                mainHandler.postDelayed(this, 1000L)
            }
        }
    }

    fun start() {
        if (running) {
            return
        }

        running = true
        lastCpuTimeMs = Process.getElapsedCpuTime()
        lastWallClockMs = SystemClock.elapsedRealtime()
        sampleAndEmit()
        mainHandler.postDelayed(sampler, 1000L)
    }

    fun stop() {
        running = false
        mainHandler.removeCallbacks(sampler)
    }

    fun setPhase(phase: ResourcePhase) {
        currentPhase = phase
        sampleAndEmit()
    }

    fun updateModelSizes(
        sttModelSizeMb: Double?,
        ttsModelSizeMb: Double?,
    ) {
        this.sttModelSizeMb = sttModelSizeMb
        this.ttsModelSizeMb = ttsModelSizeMb
        this.apkSizeMb = apkSizeMb()
        sampleAndEmit()
    }

    private fun sampleAndEmit() {
        val ramMb = readCurrentProcessRamMb()
        val cpuPercent = readProcessCpuPercent()

        peakRamMb = max(peakRamMb, ramMb)
        phaseStats[currentPhase]?.addSample(cpuPercent, ramMb)

        emitEvent(
            mapOf(
                "type" to "resource_metrics",
                "phase" to currentPhase.name.lowercase(),
                "currentRamMb" to roundTwo(ramMb),
                "peakRamMb" to roundTwo(peakRamMb),
                "idleRamMb" to roundTwoOrNull(phaseStats[ResourcePhase.IDLE]?.averageRamMb()),
                "sttRamMb" to roundTwoOrNull(phaseStats[ResourcePhase.STT]?.averageRamMb()),
                "ttsRamMb" to roundTwoOrNull(phaseStats[ResourcePhase.TTS]?.averageRamMb()),
                "idleCpuPct" to roundTwoOrNull(phaseStats[ResourcePhase.IDLE]?.averageCpuPercent()),
                "sttCpuPct" to roundTwoOrNull(phaseStats[ResourcePhase.STT]?.averageCpuPercent()),
                "ttsCpuPct" to roundTwoOrNull(phaseStats[ResourcePhase.TTS]?.averageCpuPercent()),
                "sttModelSizeMb" to roundTwoOrNull(sttModelSizeMb),
                "ttsModelSizeMb" to roundTwoOrNull(ttsModelSizeMb),
                "apkSizeMb" to roundTwoOrNull(apkSizeMb),
            ),
        )
    }

    private fun readCurrentProcessRamMb(): Double {
        val processMemory = activityManager.getProcessMemoryInfo(intArrayOf(Process.myPid()))
            .firstOrNull()
            ?.totalPss
            ?: 0

        return processMemory / 1024.0
    }

    private fun readProcessCpuPercent(): Double? {
        val nowCpuMs = Process.getElapsedCpuTime()
        val nowWallMs = SystemClock.elapsedRealtime()

        val previousCpuMs = lastCpuTimeMs
        val previousWallMs = lastWallClockMs

        lastCpuTimeMs = nowCpuMs
        lastWallClockMs = nowWallMs

        if (previousCpuMs == null || previousWallMs == null) {
            return null
        }

        val deltaCpuMs = (nowCpuMs - previousCpuMs).coerceAtLeast(0L)
        val deltaWallMs = (nowWallMs - previousWallMs).coerceAtLeast(1L)

        val rawCpu = (deltaCpuMs.toDouble() / (deltaWallMs.toDouble() * processorCount)) * 100.0
        return rawCpu.coerceIn(0.0, 100.0)
    }

    private fun apkSizeMb(): Double? {
        val apkPath = appContext.packageCodePath ?: return null
        val apkFile = File(apkPath)
        if (!apkFile.exists()) {
            return null
        }
        return apkFile.length() / (1024.0 * 1024.0)
    }

    private fun roundTwo(value: Double): Double {
        return (value * 100.0).roundToInt() / 100.0
    }

    private fun roundTwoOrNull(value: Double?): Double? {
        if (value == null) {
            return null
        }
        return roundTwo(value)
    }
}
