import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
    _TabDef(icon: LucideIcons.radio),
    _TabDef(icon: LucideIcons.clock4),
    _TabDef(icon: LucideIcons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pill tab bar — fixed width per design
          Container(
            width: 210,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.chipBorder),
            ),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final selected = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTap(i);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.selectedBg
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: _buildIcon(tab, i),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          // Create button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              onCreateTap?.call();
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.chipBorder),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.pencil,
                  size: 22,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(_TabDef tab, int index) {
    final icon = Icon(
      tab.icon,
      size: 22,
      color: AppTheme.primary,
    );

    // Show badge on Active tab (index 0)
    if (index == 0 && activeBadgeCount > 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppTheme.errorText,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  activeBadgeCount > 9 ? '9+' : '$activeBadgeCount',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return icon;
  }
}

class _TabDef {
  final IconData icon;
  const _TabDef({required this.icon});
}
