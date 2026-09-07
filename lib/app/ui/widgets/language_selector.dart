import 'package:flutter/material.dart';

import '../../models/language_option.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';

/// Language selection pill trigger + expandable grid drawer.
class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key, required this.controller});

  final AppController controller;

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  bool _expanded = false;

  String get _triggerLabel {
    final LanguageOption lang = widget.controller.selectedLanguage;
    final int supporting = kLanguageOptions
        .where((LanguageOption l) => l.sttSupported)
        .length;
    return '${lang.code.toUpperCase()} • ${lang.label}+${supporting - 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _LanguageTriggerButton(
          label: _triggerLabel,
          expanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded ? _buildDrawer(context) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
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
              Text(
                'EDGE OFFLINE STT ENGINE',
                style: AppTypography.labelCaps.copyWith(
                  color: AppColors.outline,
                ),
              ),
              const Spacer(),
              Text(
                '${kLanguageOptions.length} Vani Models',
                style: AppTypography.telemetrySm.copyWith(
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 3.2,
            children: kLanguageOptions
                .map(
                  (LanguageOption lang) => _LanguageButton(
                    language: lang,
                    selected: lang.code ==
                        widget.controller.selectedLanguage.code,
                    onTap: () {
                      widget.controller.setLanguage(lang);
                      setState(() {});
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LanguageTriggerButton extends StatelessWidget {
  const _LanguageTriggerButton({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.translate,
                size: 16,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.telemetrySm.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: AppColors.outlineVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final LanguageOption language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.secondary.withValues(alpha: 0.15)
          : AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  language.label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.telemetrySm.copyWith(
                    color: selected
                        ? AppColors.secondary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check,
                  size: 14,
                  color: AppColors.secondary,
                )
              else if (!language.sttSupported)
                Text(
                  'Offline',
                  style: AppTypography.telemetrySm.copyWith(
                    fontSize: 10,
                    color: AppColors.outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}