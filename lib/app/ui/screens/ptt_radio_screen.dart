import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/language_selector.dart';
import '../widgets/mode_segmented_switch.dart';
import '../widgets/ptt_button.dart';
import '../widgets/status_telemetry_bar.dart';
import '../widgets/stt_transcript_view.dart';
import '../widgets/tactical_compose_bar.dart';
import '../widgets/transmission_preview.dart';

/// Primary PTT Radio tab — the tactical control surface.
class PttRadioScreen extends StatelessWidget {
  const PttRadioScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final bool isListening = controller.isListening;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 76, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 4),
            StatusTelemetryBar(controller: controller),
            const SizedBox(height: 8),
            LanguageSelector(controller: controller),
            const SizedBox(height: 8),
            ModeSegmentedSwitch(controller: controller),
            const SizedBox(height: 8),
            PttButton(controller: controller),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  AudioVisualizer(active: isListening),
                  const SizedBox(height: 8),
                  SttTranscriptView(controller: controller),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TacticalComposeBar(controller: controller),
            const SizedBox(height: 8),
            TransmissionPreview(controller: controller),
          ],
        ),
      ),
    );
  }
}