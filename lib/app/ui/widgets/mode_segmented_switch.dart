import 'package:flutter/material.dart';

import '../../models/operation_mode.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';

/// Walkie-talkie / Continuous segmented switch.
class ModeSegmentedSwitch extends StatelessWidget {
  const ModeSegmentedSwitch({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final bool isPtt =
        controller.operationMode == OperationMode.walkieTalkie;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ModeButton(
              icon: Icons.radio_button_checked,
              label: 'WALKIE-TALKIE (PTT)',
              active: isPtt,
              onTap: () =>
                  controller.setOperationMode(OperationMode.walkieTalkie),
            ),
          ),
          Expanded(
            child: _ModeButton(
              icon: Icons.stream,
              label: 'CONTINUOUS STREAM',
              active: !isPtt,
              onTap: () => controller.setOperationMode(OperationMode.continuous),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? AppColors.secondary : AppColors.outlineVariant;
    final Color bg = active ? AppColors.surfaceContainer : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(9),
      elevation: active ? 2 : 0,
      shadowColor: Colors.black,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelCaps.copyWith(
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}