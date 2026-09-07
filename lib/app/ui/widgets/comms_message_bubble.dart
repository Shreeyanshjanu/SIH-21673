import 'package:flutter/material.dart';

import '../../models/speech_message.dart';
import '../../theme/app_theme.dart';

/// Chat-style message bubble adaptive to origin & emergency type.
class CommsMessageBubble extends StatelessWidget {
  const CommsMessageBubble({super.key, required this.message});

  final SpeechMessage message;

  bool get _isLocal => message.origin == MessageOrigin.local;
  bool get _isEmergency => message.type == MessageType.emergency;

  @override
  Widget build(BuildContext context) {
    final Color bubbleColor = _isEmergency
        ? AppColors.errorContainer.withValues(alpha: 0.35)
        : _isLocal
            ? AppColors.primaryContainer.withValues(alpha: 0.16)
            : AppColors.surfaceContainerHigh;

    final Color accent = _isEmergency
        ? AppColors.error
        : _isLocal
            ? AppColors.primary
            : AppColors.secondary;

    final IconData icon = _isEmergency
        ? Icons.warning_amber_rounded
        : _isLocal
            ? Icons.north_east
            : Icons.south_west;

    return Align(
      alignment: _isLocal ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_isLocal ? 12 : 4),
              topRight: Radius.circular(_isLocal ? 4 : 12),
              bottomLeft: const Radius.circular(12),
              bottomRight: const Radius.circular(12),
            ),
            border: _isEmergency
                ? Border.all(color: AppColors.error, width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 14, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    _isLocal
                        ? 'YOU'
                        : message.languageCode.toUpperCase(),
                    style: AppTypography.labelCaps.copyWith(
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                message.message,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatTime(message.timestamp),
                style: AppTypography.telemetrySm.copyWith(
                  color: AppColors.outlineVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final DateTime local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}