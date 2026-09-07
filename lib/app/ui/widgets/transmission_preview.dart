import 'package:flutter/material.dart';

import '../../models/speech_message.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import 'pulsing_dot.dart';

/// Last incoming transmission preview card.
class TransmissionPreview extends StatelessWidget {
  const TransmissionPreview({super.key, required this.controller});

  final AppController controller;

  SpeechMessage? get _lastIncoming {
    for (final SpeechMessage message in controller.history) {
      if (message.origin == MessageOrigin.remote ||
          message.type == MessageType.system) {
        return message;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final SpeechMessage? message = _lastIncoming;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: message == null
          ? _buildEmpty(context)
          : _buildIncoming(context, message),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _PreviewHeader(),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              children: <Widget>[
                const Icon(
                  Icons.radio,
                  size: 28,
                  color: AppColors.outlineVariant,
                ),
                const SizedBox(height: 6),
                Text(
                  'Standing by for incoming transmissions...',
                  textAlign: TextAlign.center,
                  style: AppTypography.telemetryMd.copyWith(
                    color: AppColors.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncoming(BuildContext context, SpeechMessage message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const PulsingDot(color: AppColors.secondary, size: 8),
            const SizedBox(width: 6),
            Text(
              'LAST RX INCOMING // JUST NOW',
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const Spacer(),
            Text(
              'TTS SPOKEN',
              style: AppTypography.telemetrySm.copyWith(
                color: AppColors.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.volume_up,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Peer: ${message.languageCode.toUpperCase()} [RX]',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.telemetrySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '"${message.message}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.surfaceContainerHigh,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {},
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.replay,
                      size: 18,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const PulsingDot(color: AppColors.secondary, size: 8),
        const SizedBox(width: 6),
        Text(
          'LAST RX INCOMING // --',
          style: AppTypography.labelCaps.copyWith(color: AppColors.secondary),
        ),
        const Spacer(),
        Text(
          'TTS SPOKEN',
          style: AppTypography.telemetrySm.copyWith(color: AppColors.outline),
        ),
      ],
    );
  }
}