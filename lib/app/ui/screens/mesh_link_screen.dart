import 'package:flutter/material.dart';

import '../../models/connection_config.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/pulsing_dot.dart';

/// Mesh Link tab — connection management + server/client config.
class MeshLinkScreen extends StatefulWidget {
  const MeshLinkScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MeshLinkScreen> createState() => _MeshLinkScreenState();
}

class _MeshLinkScreenState extends State<MeshLinkScreen> {
  final TextEditingController _hostController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hostController.text =
        widget.controller.connectionConfig.host;
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 76, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'MESH LINK CONFIG',
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.outline,
                letterSpacing: 0.14,
              ),
            ),
            const SizedBox(height: 12),
            _ConnectionCard(controller: controller, hostController: _hostController),
            const SizedBox(height: 12),
            _StatusCard(connected: controller.isConnected),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.controller,
    required this.hostController,
  });

  final AppController controller;
  final TextEditingController hostController;

  @override
  Widget build(BuildContext context) {
    final ConnectionConfig config = controller.connectionConfig;
    final bool connected = controller.isConnected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionLabel('LINK MODE'),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _ModeChip(
                label: 'SERVER / RELAY',
                icon: Icons.cast,
                selected: config.runAsServer,
                onTap: () => controller.updateConnectionConfig(
                  config.copyWith(runAsServer: true),
                ),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: 'CLIENT / PEER',
                icon: Icons.hub,
                selected: !config.runAsServer,
                onTap: () => controller.updateConnectionConfig(
                  config.copyWith(runAsServer: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionLabel('PEER ADDRESS'),
          const SizedBox(height: 8),
          TextField(
            controller: hostController,
            enabled: !config.runAsServer,
            style: AppTypography.telemetryMd.copyWith(
              color: AppColors.onSurface,
            ),
            decoration: const InputDecoration(
              hintText: '192.168.4.1',
              prefixIcon: Icon(
                Icons.wifi_tethering,
                color: AppColors.outline,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionLabel('PORT'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.lan, size: 18, color: AppColors.outline),
                const SizedBox(width: 8),
                Text(
                  '7070',
                  style: AppTypography.telemetryLg.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'FIXED',
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ConnectButton(
            connected: connected,
            onTap: () {
              controller.updateConnectionConfig(
                controller.connectionConfig.copyWith(
                  host: hostController.text.trim(),
                ),
              );
              if (connected) {
                controller.disconnect();
              } else {
                controller.connect();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelCaps.copyWith(color: AppColors.outline),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected
            ? AppColors.secondary.withValues(alpha: 0.15)
            : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.secondary : AppColors.outline,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTypography.labelCaps.copyWith(
                    color: selected ? AppColors.secondary : AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.connected, required this.onTap});

  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: connected ? AppColors.tertiaryContainer : AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      shadowColor: Colors.black,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                connected ? Icons.link_off : Icons.link,
                size: 20,
                color: connected
                    ? AppColors.onTertiaryContainer
                    : AppColors.onPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                connected ? 'DISCONNECT' : 'ESTABLISH LINK',
                style: AppTypography.headlineSm.copyWith(
                  color: connected
                      ? AppColors.onTertiaryContainer
                      : AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final Color color = connected ? AppColors.tertiary : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          PulsingDot(color: color, size: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  connected
                      ? 'MESH LINK ESTABLISHED'
                      : 'STANDING BY',
                  style: AppTypography.headlineSm.copyWith(color: color),
                ),
                Text(
                  connected
                      ? 'Local network communication active on TCP:7070'
                      : 'Configure a connection above to join the local mesh',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}