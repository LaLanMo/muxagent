import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import '../../domain/enums.dart';
import '../main/main_shell_viewmodel.dart';

class RelayStatusPill extends StatelessWidget {
  const RelayStatusPill({super.key});

  static const Color _reconnectingBg = Color(0xFFFFFAEF);
  static const Color _reconnectingBorder = Color(0xFFE7C98C);
  static const Color _reconnectingDot = Color(0xFFC48B2C);
  static const Color _disconnectedBorder = Color(0xFFE0B2AA);
  static const Color _disconnectedDot = Color(0xFFB95A50);

  @override
  Widget build(BuildContext context) {
    final vm = Get.find<MainShellViewModel>();
    return Obx(() {
      final connected = vm.relayConnected.value;
      final state = vm.relayConnectionState.value;

      if (connected) return const SizedBox.shrink();

      final bool isReconnecting = state == ConnState.reconnecting;
      return _RelayStatusChip(
        key: ValueKey(
          isReconnecting
              ? 'relay-status-pill-reconnecting'
              : 'relay-status-pill-disconnected',
        ),
        label: isReconnecting ? 'reconnecting' : 'offline',
        textColor: isReconnecting
            ? AppTheme.warning
            : AppTheme.statusDisconnected,
        backgroundColor: isReconnecting
            ? _reconnectingBg
            : AppTheme.disconnectedBg,
        borderColor: isReconnecting ? _reconnectingBorder : _disconnectedBorder,
        dotColor: isReconnecting ? _reconnectingDot : _disconnectedDot,
      );
    });
  }
}

class _RelayStatusChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color dotColor;

  const _RelayStatusChip({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusNone),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.mono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
