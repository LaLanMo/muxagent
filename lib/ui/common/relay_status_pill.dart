import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      if (isReconnecting) return const StatusIndicator.reconnecting();
      return const StatusIndicator.disconnected();
    });
  }
}
