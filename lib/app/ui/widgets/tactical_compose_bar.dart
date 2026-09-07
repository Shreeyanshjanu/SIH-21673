import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';

/// Tactical compose bar — text input + transmit + emergency SOS.
class TacticalComposeBar extends StatefulWidget {
  const TacticalComposeBar({super.key, required this.controller});

  final AppController controller;

  @override
  State<TacticalComposeBar> createState() => _TacticalComposeBarState();
}

class _TacticalComposeBarState extends State<TacticalComposeBar> {
  final TextEditingController _composeController = TextEditingController();

  @override
  void dispose() {
    _composeController.dispose();
    super.dispose();
  }

  void _transmit() {
    final String text = _composeController.text;
    _composeController.clear();
    widget.controller.sendTypedMessage(text);
  }

  void _sos() {
    final String typed = _composeController.text.trim();
    _composeController.clear();
    if (typed.isNotEmpty) {
      widget.controller.sendTypedMessage(typed, emergency: true);
    } else {
      widget.controller.sendEmergencyPreset();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Tactical Message / TTS Synthesizer',
                style: AppTypography.labelCaps.copyWith(
                  color: AppColors.outline,
                ),
              ),
              const Spacer(),
              Text(
                'TCP BROADCAST',
                style: AppTypography.telemetrySm.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _composeController,
            maxLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _transmit(),
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'Type tactical broadcast message...',
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.keyboard_voice,
                  color: AppColors.outline,
                ),
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionButton(
                  icon: Icons.cell_tower,
                  label: 'TRANSMIT',
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimary,
                  onTap: _transmit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SosButton(onTap: _sos),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
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
              Icon(icon, size: 20, color: foregroundColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.headlineSm.copyWith(
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosButton extends StatefulWidget {
  const _SosButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: Material(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(10),
        elevation: 2,
        shadowColor: Colors.black,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onTap,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.warning,
                  size: 22,
                  color: AppColors.onErrorContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  'EMERGENCY SOS',
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.onErrorContainer,
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