import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';

/// Live STT transcript viewfinder with copy/clear actions.
class SttTranscriptView extends StatelessWidget {
  const SttTranscriptView({super.key, required this.controller});

  final AppController controller;

  String get _transcript {
    final String partial = controller.partialTranscript.trim();
    if (partial.isNotEmpty) {
      return '"$partial"';
    }
    const String placeholder = '"[No recent transmission detected]"';
    return controller.history.isEmpty ? placeholder : '"[Ready]"';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.graphic_eq,
                size: 16,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'OFFLINE SHERPA-ONNX • READY',
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Text(
                'AUTO-LOGGED',
                style: AppTypography.telemetrySm.copyWith(
                  color: AppColors.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _transcript,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              _SmallButton(
                icon: Icons.content_copy,
                label: 'Copy',
                onTap: () => controller.exportLatestBenchmarkAsJson(),
              ),
              const SizedBox(width: 6),
              _SmallButton(
                icon: Icons.backspace,
                label: 'Clear',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 14, color: AppColors.onSurface),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.telemetrySm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}