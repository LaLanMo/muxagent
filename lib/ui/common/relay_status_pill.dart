import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme.dart';
import '../../domain/enums.dart';
import '../main/main_shell_viewmodel.dart';
import 'status_indicator.dart';

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
      final String label;

      if (isReconnecting) {
        bg = AppTheme.warningBg;
        fg = AppTheme.statusConnecting;
        label = 'reconnecting';
      } else {
        bg = AppTheme.disconnectedBg;
        fg = AppTheme.statusDisconnected;
        label = 'offline';
      }

      return StatusIndicator(label: label, color: fg, backgroundColor: bg);
    });
  }
}
