import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../domain/enums.dart';
import '../main/main_shell_viewmodel.dart';

class RelayStatusPill extends StatelessWidget {
  const RelayStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Get.find<MainShellViewModel>();
    return Obx(() {
      final connected = vm.relayConnected.value;
      final state = vm.relayConnectionState.value;

      if (connected) return const SizedBox.shrink();

      final bool isReconnecting = state == ConnState.reconnecting;

      final Color bg;
      final Color fg;
      final IconData icon;
      final String label;

      if (isReconnecting) {
        bg = AppTheme.warningBg;
        fg = AppTheme.statusConnecting;
        icon = LucideIcons.refreshCw;
        label = 'Reconnecting\u2026';
      } else {
        bg = AppTheme.disconnectedBg;
        fg = AppTheme.statusDisconnected;
        icon = LucideIcons.cloudOff;
        label = 'Server unreachable';
      }

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      );
    });
  }
}
