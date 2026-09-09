# Offline STT reliability patch

## Scope and behavior

- Keeps the bundled English NeMo CTC model and Sherpa AAR. Capture remains 16 kHz, mono, PCM16, `VOICE_RECOGNITION`, with 320-sample (20 ms) reads. Recognition remains CPU, two threads, `greedy_search`, `maxActivePaths = 4`, and 80 feature bins.
- PTT buffers every captured frame, including quiet consonants, internal silence, and the final read. It does not gate PCM with VAD.
- Continuous mode uses the existing energy VAD for utterance boundaries, retains approximately 200 ms of pre-roll, and keeps all frames inside an utterance, including its trailing silence. VAD timing uses sample counts, not executor scheduling delays. Idle silence outside utterances is not transcribed.
- Pre-roll only contains audio recorded after AudioRecord starts. PTT does not keep the microphone running before a press. Wait for the actual Listening status before speaking; cold initialization time is not recoverable audio.
- The recognizer is prepared before capture. Listening is reported only after AudioRecord enters the recording state and a real PCM frame arrives. A release during preparation is honored; a late readiness event cannot restart listening.
- A single pipeline executor owns PCM delivery, utterance finalization, session release, and language changes. The microphone reader only reads, copies, measures, and enqueues audio. Normal stop completes the current read, drains available buffered audio with a limit, and queues finalization after all frame deliveries; it does not cancel the reader future.
- Each nonempty, valid utterance converts its complete PCM to one FloatArray, calls `OfflineStream.acceptWaveform(float[], int)` once, calls `OfflineRecognizer.decode(OfflineStream)` once, reads the result, then releases its stream. There are no periodic offline decodes or synthetic partial transcripts. No `inputFinished()` call is made.
- Reflection validates the bundled method signatures and required configuration properties. Successful void invocation is distinct from an exception. Acceptance/decoding failures invalidate the result and never produce a fallback message.
- PCM storage is capped at 30 seconds per utterance, and pending frame delivery is capped at five seconds. Overflow or failure to drain the microphone explicitly stops/rejects the affected utterance rather than transmitting a truncated sentence. Already completed continuous-mode utterances are not recalled.
- No new model, online API, gain adjustment, word substitution, or runtime dependency is added. Existing punctuation/whitespace cleanup, TCP transport, emergency handling, and native TTS remain in place. Missing native backends no longer fabricate recognition or playback-success events.

The full-size PCM plus its FloatArray use approximately 2.9 MB at the 30-second limit, before queue/object overhead and Sherpa's own model/decoder allocations. This is not a total process RAM estimate.

## Audio metrics

Native log tag: `ITANTRA_STT`. The existing event channel carries `stt_ready`, `capture_state`, `stt_metrics`, and `capture_metrics`; the controller exposes `latestSttMetrics` and `latestCaptureMetrics` for inspection.

| Field | Meaning |
| --- | --- |
| `capturedSamples`, `queuedSamples` | Samples actually returned by AudioRecord, and accepted by the delivery queue |
| `deliveredSamples` | Samples appended to STT utterance storage |
| `capturedDurationMs`, `audioDurationMs` | Actual sample count divided by 16000, converted to milliseconds |
| `firstFrameLatencyMs` | Flutter PTT entry timestamp to the first successful microphone read; includes initialization if necessary |
| `decodeCalls`, `decodeDurationMs` | Actual decode attempts and time spent decoding/reading the result |
| `processingDurationMs` | Final conversion, waveform acceptance, decode/result retrieval, and stream release wall time |
| `rms`, `peak` | Normalized amplitude measurements, not automatically applied gain |
| `clippedSamples`, `clippingPercent` | Samples at the PCM16 minimum or maximum; an indicator, not a detector of every possible distortion |
| `sampleRate`, `bufferSizeBytes`, `actualBufferSizeFrames` | Validated rate and requested/actual AudioRecord buffer sizes |
| `recognitionValid`, `captureValid`, `fallback`, `overflowed`, `error` | Explicit validity/failure markers; invalid/fallback results are not sent over TCP |
| `idleSamplesNotTranscribed` | Continuous-mode samples outside recognized utterances; expected to be nonzero during idle silence |

For a successful PTT capture, `capturedSamples == queuedSamples == deliveredSamples`, and a nonempty utterance has exactly one decode. A read/queue/PCM failure may break that equality, but must carry an explicit failure and must not transmit a truncated result. Zero captured samples cause zero decodes.

`audioStartEpochMs` and `audioEndEpochMs` are sample-based capture boundaries anchored to the recording-start clock, not phonetic speech timestamps or hardware AudioTimestamp measurements. Native completion time and measured durations are retained rather than overwritten by Dart arrival times or word-count estimates. Existing `resource_metrics` reports sampled process CPU/RAM; the synthetic device phrase test also logs process CPU time and PSS. Neither is isolated model-only resource usage.

## Build and automated checks

Run from the project root in PowerShell:

```powershell
flutter test --no-pub test/stt_pipeline_test.dart
flutter analyze --no-pub lib/app/state/app_controller.dart lib/app/services/native_bridge_service.dart lib/app/services/benchmark_tracker.dart test/stt_pipeline_test.dart
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio1\jbr'
.\android\gradlew.bat -p android :app:testDebugUnitTest :app:assembleDebugAndroidTest
flutter build apk --debug --no-pub
```

Recorded results on September 9, 2026:

- Focused Flutter regressions: six passed.
- Kotlin unit tests: nine passed, zero skipped, zero failures.
- Targeted Dart analysis: no issues.
- Final debug APK and Android instrumentation APK: built successfully.
- Full Flutter suite: six passed; the unchanged accessibility test failed with `pumpAndSettle timed out`.
- Connected instrumentation: could not execute (`No connected devices!`). No microphone, synthetic-model phrase accuracy, audible playback, or two-phone result is claimed from this run.

The Kotlin unit tests verify quiet-frame preservation, exact PCM scaling, one-shot decoding, rejected overflow, reflection exceptions, stream cleanup, bounded ordered delivery, pre-roll, sample-clock VAD, and fallback rejection. They use a fake recognizer and do not measure acoustic accuracy.

The Flutter regression tests verify startup/release handling, unavailable-backend status, rejection of unverified transcripts, real-duration/timestamp preservation, and real loopback TCP in both directions. The exact strings `fire`, `wire`, `live wire`, and `not a fire` pass through typed and injected validated-voice messages; emergency flags and the emergency preset are checked. STT and playback are simulated in those transport tests, so they do not prove microphone recognition, audible TTS, or two-phone communication.

The broader `flutter test --no-pub` run also includes the existing accessibility test. Its `pumpAndSettle` timeout is outside this STT patch; the existing repeating UI animations and accessibility test are unchanged.

## Connected-device checks

The instrumentation tests require a connected, authorized Android device. They briefly capture microphone audio locally; they do not save that microphone audio or send it over TCP. The offline-TTS phrase test creates temporary WAVs and removes them after reading.

```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adb devices -l
.\android\gradlew.bat -p android :app:connectedDebugAndroidTest '-Pandroid.testInstrumentationRunnerArguments.class=com.sih.voicebridge.pipeline.NativeSttDeviceTest'
& $adb logcat -d -s ITANTRA_STT:I ITANTRA_STT_DEVICE:I '*:S'
& $adb shell run-as com.sih.voicebridge cat cache/stt_validation_report.json
```

Device tests cover AudioRecord's ordered stop handoff, the complete PTT AudioRecord-to-real-Sherpa path with sample equality and one decode, and all four phrases synthesized by an already-installed offline English Android TTS voice. The phrase report records expected and actual text, decode time, sample count, CPU time, PSS, and whether each phrase matched. Any mismatch fails the phrase test after collecting all four results. With no installed offline English voice, that test is skipped explicitly; this is not a recognition pass. The report source is `installed_offline_tts_not_human_microphone`.

Synthetic TTS is only a smoke test of the bundled model/backend. It cannot establish improvement for a human saying `fire` versus `wire`, or reproduce room noise, pronunciation, microphone placement, and low-energy consonants.

## Human and two-phone validation still required

1. Keep both phones offline from the internet while retaining the local Wi-Fi/hotspot TCP link. Confirm `stt_ready.available = true` and `fallback = false`.
2. Say exactly `fire`, `wire`, `live wire`, and `not a fire`, at least ten times each in quiet and representative background noise. Record the unmodified recognized text and the metrics for each attempt. Do not count fallback or failed captures as successful recognition.
3. Test immediate speech at press versus waiting for Listening, rapid press/release during initialization, release at the last consonant, internal quiet syllables, long pauses, and continuous utterance boundaries. Confirm that startup latency, not pre-roll, explains audio spoken before capture begins.
4. Hold PTT beyond 30 seconds: expect an explicit rejected-utterance error and no truncated message. Exercise continuous mode on the slowest target phone to check whether decoding creates a five-second backlog.
5. Send each exact phrase as typed text from phone A to B and back. Verify unchanged text, reception, and real audible TTS.
6. Repeat using microphone speech through STT, TCP, and the receiving phone's audible TTS. Compare the sent transcript to what was actually spoken, especially the negation in `not a fire`.
7. Test typed emergency messages and the emergency preset in both directions. Verify the emergency flag, priority/volume behavior, audible playback, and volume restoration.
8. Compare recognition error counts, first-frame latency, decode latency, clipping, CPU, and RAM against the stable version on the same devices and conditions. Passing unit/transport tests is not evidence of improved acoustic accuracy.

## Changed files

- `android/app/src/main/kotlin/com/sih/voicebridge/pipeline/AudioBuffers.kt` (new)
- `android/app/src/main/kotlin/com/sih/voicebridge/pipeline/OfflineSttSession.kt` (new)
- `android/app/src/main/kotlin/com/sih/voicebridge/pipeline/AudioCaptureManager.kt`
- `android/app/src/main/kotlin/com/sih/voicebridge/pipeline/SttEngine.kt`
- `android/app/src/main/kotlin/com/sih/voicebridge/pipeline/VadProcessor.kt`
- `android/app/src/main/kotlin/com/sih/voicebridge/pipeline/VoicePipelineOrchestrator.kt`
- `android/app/src/main/kotlin/com/sih/voicebridge/bridge/NativeBridgeHandler.kt`
- `lib/app/services/native_bridge_service.dart`
- `lib/app/services/benchmark_tracker.dart`
- `lib/app/state/app_controller.dart`
- `android/app/build.gradle` (test dependencies/runner only)
- `android/app/src/test/kotlin/com/sih/voicebridge/pipeline/OfflineAudioPipelineTest.kt` (new)
- `android/app/src/androidTest/kotlin/com/sih/voicebridge/pipeline/NativeSttDeviceTest.kt` (new)
- `test/stt_pipeline_test.dart` (new)
- `docs/stt-validation.md` (new)
