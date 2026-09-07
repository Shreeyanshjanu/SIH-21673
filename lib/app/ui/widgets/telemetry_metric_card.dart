import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Single telemetry metric display card.
class TelemetryMetricCard extends StatelessWidget {
  const TelemetryMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? AppColors.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppTypography.labelCaps.copyWith(
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.telemetryLg.copyWith(color: accent),
                ),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: AppTypography.telemetrySm.copyWith(
                    color: AppColors.outlineVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}