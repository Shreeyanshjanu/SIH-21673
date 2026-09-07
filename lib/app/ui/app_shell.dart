import 'dart:ui';
import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'screens/messages_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/talk_screen.dart';
import 'widgets/tactical_header.dart';

/// The 3-tab cockpit shell matching the Stitch design.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final List<Widget> screens = <Widget>[
          TalkScreen(controller: widget.controller),
          MessagesScreen(controller: widget.controller),
          SettingsScreen(controller: widget.controller),
        ];

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: <Widget>[
              IndexedStack(index: _currentIndex, children: screens),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TacticalHeader(
                  controller: widget.controller,
                  activeTabTitle: _tabName(_currentIndex),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _TacticalBottomNav(
            currentIndex: _currentIndex,
            onSelect: (int index) => setState(() => _currentIndex = index),
          ),
        );
      },
    );
  }

  String _tabName(int index) {
    switch (index) {
      case 0:
        return 'Talk';
      case 1:
        return 'Messages';
      case 2:
        return 'Settings';
      default:
        return '';
    }
  }
}

class _TacticalBottomNav extends StatelessWidget {
  const _TacticalBottomNav({
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
            border: const Border(
              top: BorderSide(color: AppColors.outline, width: 1),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 4,
            top: 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _NavItem(
                icon: Icons.mic,
                label: 'Talk',
                selected: currentIndex == 0,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble,
                label: 'Messages',
                selected: currentIndex == 1,
                onTap: () => onSelect(1),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Settings',
                selected: currentIndex == 2,
                onTap: () => onSelect(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.primary : AppColors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label tab',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  selected ? (selectedIcon ?? icon) : icon,
                  size: 26,
                  color: color,
                ),
                const SizedBox(height: 3),
                Text(
                  label.toUpperCase(),
                  style: AppTypography.labelCaps.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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