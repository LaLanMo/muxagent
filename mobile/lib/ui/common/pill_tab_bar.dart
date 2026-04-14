import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';

class PillTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCreateTap;
  final int activeBadgeCount;

  const PillTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onCreateTap,
    this.activeBadgeCount = 0,
  });

  static const _tabs = [
    _TabDef(icon: LucideIcons.radio, label: 'Active Sessions'),
    _TabDef(icon: LucideIcons.clock4, label: 'History'),
    _TabDef(icon: LucideIcons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              border: Border.all(color: AppTheme.borderStrong),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ...List.generate(
                  _tabs.length,
                  (i) => _buildTabSlot(index: i, tab: _tabs[i]),
                ),
                _buildComposeSlot(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSlot({required int index, required _TabDef tab}) {
    final selected = index == currentIndex;
    return SizedBox(
      width: 44,
      height: 44,
      child: Semantics(
        label: tab.label,
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap(index);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: _buildTabIcon(
                  tab.icon,
                  color: selected
                      ? AppTheme.textPrimary
                      : AppTheme.textTertiary,
                  showBadge: index == 0 && activeBadgeCount > 0,
                ),
              ),
              if (selected)
                const Positioned(
                  left: 12,
                  right: 12,
                  bottom: 6,
                  child: SizedBox(
                    height: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppTheme.accent),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposeSlot() {
    return SizedBox(
      width: 44,
      height: 44,
      child: Semantics(
        label: 'New Session',
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            onCreateTap?.call();
          },
          child: const Center(
            child: Icon(LucideIcons.pencil, size: 20, color: AppTheme.accent),
          ),
        ),
      ),
    );
  }

  Widget _buildTabIcon(
    IconData icon, {
    required Color color,
    required bool showBadge,
  }) {
    final baseIcon = Icon(icon, size: 20, color: color);
    if (!showBadge) {
      return baseIcon;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        const Positioned(
          right: -4,
          top: -2,
          child: SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabDef {
  final IconData icon;
  final String label;

  const _TabDef({required this.icon, required this.label});
}
