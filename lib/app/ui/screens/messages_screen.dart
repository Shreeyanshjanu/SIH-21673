import 'package:flutter/material.dart';

import '../../models/speech_message.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/pulsing_dot.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _msgInputController = TextEditingController();

  @override
  void dispose() {
    _msgInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;
    final List<SpeechMessage> messages = controller.history;

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          // Scrollable messages stream
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 76, 16, 12),
              children: <Widget>[
                // Mesh Channel Status Banner
                _buildMeshBanner(controller),
                const SizedBox(height: 12),

                // Header Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('RECENT MESSAGES', style: AppTypography.headlineSm),
                        Text(
                          'Stored offline on this device',
                          style: AppTypography.bodySm,
                        ),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        minimumSize: const Size(48, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: messages.isEmpty ? null : controller.clearHistory,
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: Text('Clear All', style: AppTypography.bodySm),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Message bubbles stream
                if (messages.isEmpty)
                  _buildEmptyState()
                else
                  for (final SpeechMessage msg in messages) ...<Widget>[
                    _buildMessageCard(msg, controller),
                    const SizedBox(height: 10),
                  ],

                const SizedBox(height: 12),
                // Quick Presets
                _buildPresets(controller),
              ],
            ),
          ),

          // Sticky Bottom Compose Bar
          _buildStickyCompose(controller),
        ],
      ),
    );
  }

  Widget _buildMeshBanner(AppController controller) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cell_tower, color: AppColors.secondary, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SECTOR B MESH CHANNEL',
                  style: AppTypography.labelCaps.copyWith(color: AppColors.onSurface),
                ),
                Text(
                  'Direct device-to-device • No internet needed',
                  style: AppTypography.bodySm,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.tertiaryFixed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                const PulsingDot(color: AppColors.onTertiaryFixed, size: 6),
                const SizedBox(width: 4),
                Text(
                  controller.isConnected ? 'ONLINE' : 'LOCAL',
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.onTertiaryFixed,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(SpeechMessage msg, AppController controller) {
    final bool isEmergency = msg.type == MessageType.emergency;
    final bool isLocal = msg.origin == MessageOrigin.local;

    if (isEmergency) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'CRITICAL EMERGENCY',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Broadcast • ${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                        style: AppTypography.telemetrySm,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'URGENT',
                    style: AppTypography.labelCaps.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                msg.message,
                style: AppTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!isLocal) {
      // Incoming transmission
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          msg.languageCode.toUpperCase(),
                          style: AppTypography.labelCaps.copyWith(
                            color: AppColors.onSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Remote Unit', style: AppTypography.headlineSm),
                        Text(
                          '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                          style: AppTypography.telemetrySm,
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'VOICE NOTE',
                    style: AppTypography.labelCaps.copyWith(
                      color: AppColors.onSecondaryContainer,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '“${msg.message}”',
              style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
            ),
          ],
        ),
      );
    }

    // Outgoing transmission
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('YOU SENT', style: AppTypography.labelCaps.copyWith(color: AppColors.primary)),
                Text(
                  '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: AppTypography.telemetrySm,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              msg.message,
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                const Icon(Icons.done_all, size: 14, color: AppColors.tertiary),
                const SizedBox(width: 4),
                Text(
                  'Delivered to mesh',
                  style: AppTypography.telemetrySm.copyWith(color: AppColors.tertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: <Widget>[
            const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.outlineVariant),
            const SizedBox(height: 8),
            Text('No messages yet', style: AppTypography.headlineSm),
            const SizedBox(height: 4),
            Text('Mesh transmissions will log here offline', style: AppTypography.bodySm),
          ],
        ),
      ),
    );
  }

  Widget _buildPresets(AppController controller) {
    const List<String> presets = <String>[
      '👍 I am OK',
      '🆘 Need Help',
      '📍 Arrived at Location',
      '📡 Check In',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('QUICK PRESETS (TAP TO SEND)', style: AppTypography.labelCaps),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: presets.map((String text) {
            final bool isSos = text.contains('Need Help');
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSos
                    ? AppColors.errorContainer.withValues(alpha: 0.4)
                    : AppColors.surfaceContainerLow,
                foregroundColor: isSos ? AppColors.error : AppColors.onSurface,
                side: BorderSide(color: isSos ? AppColors.error : AppColors.outline),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () {
                if (isSos) {
                  controller.sendEmergencyPreset();
                } else {
                  controller.sendTypedMessage(text);
                }
              },
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSos ? AppColors.error : AppColors.onSurface,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStickyCompose(AppController controller) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.paddingOf(context).bottom + 74,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: TextField(
                controller: _msgInputController,
                decoration: const InputDecoration(
                  hintText: 'Type a quick message...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: (String val) {
                  if (val.trim().isNotEmpty) {
                    controller.sendTypedMessage(val.trim());
                    _msgInputController.clear();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.onSecondary,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final String val = _msgInputController.text.trim();
                if (val.isNotEmpty) {
                  controller.sendTypedMessage(val);
                  _msgInputController.clear();
                }
              },
              child: const Icon(Icons.arrow_upward, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
