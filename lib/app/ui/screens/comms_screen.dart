import 'package:flutter/material.dart';

import '../../models/speech_message.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/comms_message_bubble.dart';

/// Comms Log tab — chat-style transmission history.
class CommsScreen extends StatelessWidget {
  const CommsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final List<SpeechMessage> history = controller.history;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 76, 16, 12),
            child: Row(
              children: <Widget>[
                Text(
                  'COMMS LOG',
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.outline,
                    letterSpacing: 0.14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${history.length} MSG',
                  style: AppTypography.telemetrySm.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? const _EmptyComms()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: history.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: CommsMessageBubble(message: history[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyComms extends StatelessWidget {
  const _EmptyComms();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: AppColors.outlineVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'No transmissions logged',
            style: AppTypography.bodyLg.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Voice or text messages will appear here',
            style: AppTypography.telemetrySm.copyWith(
              color: AppColors.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}