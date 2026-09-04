# SIH Voice Bridge

Offline speech-to-speech emergency communication app aligned to your architecture:

- `Flutter` UI for PTT, language, connection, alerts, and benchmarking.
- `Flutter MethodChannel + EventChannel` bridge to Android/Kotlin native pipeline.
- Local-network `TCP` text transfer (no internet required).
- Structured timeline metrics (`T0..T6`) for latency/RTF benchmarking.

## Current implementation status

This repository is a phase-oriented scaffold that directly follows your roadmap:

- Phase 0: environment structure ✅
- Phase 1: mic capture + VAD + streaming STT session contract + transcript UI ✅
- Phase 2: native Android TextToSpeech playback + utterance events ✅
- Phase 3: one-phone loop ✅ (auto local TTS when peer not connected)
- Phase 4: two-phone text communication over TCP/Wi-Fi ✅
- Phase 5: sentence-finalization pipeline hooks ✅
- Phase 6: walkie-talkie hold-to-talk UI ✅
- Phase 7: emergency message type + priority playback hook ✅
- Phase 8+: modularized to extend bidirectional + multilingual + optimization ✅

> Native Kotlin classes now run real PCM microphone capture (`16kHz mono`) and energy-based pause detection.
> `SttEngine` now includes a Sherpa-ONNX reflective backend loader with safe fallback if dependency/model files are missing.
> `TtsEngine` now supports pluggable backends with Android `TextToSpeech` fallback and manifest-based Piper/Sherpa routing.
> Native resource telemetry now streams phase-wise CPU/RAM/model/APK metrics to Flutter benchmark UI.

## Project layout

- `lib/app/state/app_controller.dart`: app orchestration and mode/state transitions.
- `lib/app/services/native_bridge_service.dart`: Dart-side Method/Event channels.
- `lib/app/services/tcp_message_service.dart`: local TCP communication transport.
- `lib/app/services/benchmark_tracker.dart`: `T0..T6`, latency, and RTF capture.
- `lib/app/ui/home_screen.dart`: main operator UI (connection, language, PTT, alerts, metrics).
- `android/app/src/main/kotlin/com/sih/voicebridge/pipeline`: native Android pipeline modules.

## Message schema

```json
{
  "id": "1725218320000000",
  "type": "speech",
  "language": "en",
  "message": "Emergency assistance is required",
  "timestamp": 1725218320000
}
```

Emergency message uses `"type": "emergency"`.

## Benchmarking captured

- `T0`: speech starts
- `T1`: speech ends
- `T2`: STT final result
- `T3`: message sent
- `T4`: message received
- `T5`: TTS starts
- `T6`: first audio playback

Calculated outputs:

- `STT latency = T2 - T1`
- `Network latency = T4 - T3`
- `TTS latency = T6 - T4`
- `End-to-end latency = T6 - T0`
- `RTF = processing_time / audio_duration`

Runtime resource telemetry:

- `Idle RAM`, `STT RAM`, `TTS RAM`, `Peak RAM`
- `Idle CPU %`, `STT CPU %`, `TTS CPU %`
- `STT model size`, `TTS model size`, `APK size`
- One-tap benchmark export from UI (`Copy JSON`, `Copy CSV`)
- Multi-sample benchmark history export (`History JSON`, `History CSV`, max 50 samples)
- Benchmark history persistence across app restarts

## Setup

1. Install Flutter + Android toolchain.
2. Run `flutter pub get`.
3. Put STT/TTS assets under:
   - `assets/models/stt/`
   - `assets/models/tts/`
4. Configure STT manifest at:
   - `assets/models/stt/model_manifest.json`
5. Configure TTS manifest at:
   - `assets/models/tts/model_manifest.json`
6. Place per-language model files at paths referenced in manifests.
7. Add Sherpa Android dependency in `android/app/build.gradle` (if not already included in your local setup).
8. Launch app once and grant microphone permission.
9. Run on Android with `flutter run`.

## TTS notes

- Backend selection is language-driven via `assets/models/tts/model_manifest.json`.
- If Piper/Sherpa backend is unavailable or model assets are missing, runtime automatically falls back to Android `TextToSpeech`.
- Emergency messages use flush-priority utterances and restore system volume after playback completion.
- Keep `tts_started` / `audio_started` events unchanged so benchmarking remains consistent across backend swaps.

## Language roadmap mapping

Configured language set includes:

- English
- Hindi
- Gujarati
- Marathi
- Kannada
- Malayalam
- Tamil
- Telugu
- Bengali
- Odia (flagged as pending model availability)

## Next integration step

Finalize Sherpa binding by ensuring your exact Sherpa Java API version is on classpath, then tune silence threshold (`500-1000ms`) and benchmark on-device.
