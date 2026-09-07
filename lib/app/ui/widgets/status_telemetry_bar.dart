import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import 'pulsing_dot.dart';

/// Mission status + signal telemetry bar with the language selector pill.
class StatusTelemetryBar extends StatelessWidget {
  const StatusTelemetryBar({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final bool connected = controller.isConnected;

    final Color statusColor =
        connected ? AppColors.tertiary : AppColors.error;
    final String statusLabel = connected
        ? 'LOCAL MESH RELAY // ONLINE'
        : 'STANDING BY // OFFLINE';

    final String host = controller.connectionConfig.host.isEmpty
        ? '0.0.0.0'
        : controller.connectionConfig.host;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    PulsingDot(color: statusColor, size: 10),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        statusLabel,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelCaps.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const _LatencyBadge(),
              const SizedBox(width: 6),
              const _StabilityBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.wifi_tethering,
                        size: 16,
                        color: AppColors.outline,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$host:${controller.connectionConfig.port}',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.telemetrySm.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        'TCP',
                        style: AppTypography.telemetrySm.copyWith(
                          color: AppColors.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LatencyBadge extends StatelessWidget {
  const _LatencyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '18ms',
        style: AppTypography.telemetrySm.copyWith(color: AppColors.secondary),
      ),
    );
  }
}

class _StabilityBadge extends StatelessWidget {
  const _StabilityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'STABLE',
        style: AppTypography.telemetrySm.copyWith(color: AppColors.tertiary),
      ),
    );
  }
}