import 'package:flutter/material.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import '../../domain/enums.dart';

class StatusIndicator extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;
  final double? width;

  const StatusIndicator({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
    this.width,
  });

  const StatusIndicator.online({super.key})
    : label = 'online',
      color = AppTheme.successText,
      backgroundColor = AppTheme.successBg,
      width = null;

  const StatusIndicator.offline({super.key})
    : label = 'offline',
      color = AppTheme.statusNeutralText,
      backgroundColor = AppTheme.idleBg,
      width = null;

  const StatusIndicator.connecting({super.key})
    : label = 'connecting',
      color = AppTheme.statusConnecting,
      backgroundColor = AppTheme.warningBg,
      width = null;

  const StatusIndicator.reconnecting({super.key})
    : label = 'reconnecting',
      color = AppTheme.statusConnecting,
      backgroundColor = AppTheme.warningBg,
      width = null;

  const StatusIndicator.disconnected({super.key})
    : label = 'offline',
      color = AppTheme.statusDisconnected,
      backgroundColor = AppTheme.disconnectedBg,
      width = null;

  const StatusIndicator.serverLost({super.key})
    : label = 'offline',
      color = AppTheme.serverLostText,
      backgroundColor = AppTheme.serverLostBg,
      width = null;

  factory StatusIndicator.sessionStatus(SessionStatus status) {
    switch (status) {
      case SessionStatus.running:
        return const StatusIndicator(
          label: 'running',
          color: AppTheme.successText,
          backgroundColor: AppTheme.successBg,
          width: 72,
        );
      case SessionStatus.waitingApproval:
        return const StatusIndicator(
          label: 'awaiting',
          color: AppTheme.warning,
          backgroundColor: AppTheme.warningBg,
          width: 72,
        );
      case SessionStatus.error:
        return const StatusIndicator(
          label: 'failed',
          color: AppTheme.errorText,
          backgroundColor: AppTheme.errorBg,
          width: 72,
        );
      case SessionStatus.done:
      case SessionStatus.idle:
        return const StatusIndicator(
          label: 'done',
          color: AppTheme.statusNeutralText,
          backgroundColor: AppTheme.statusNeutralBg,
          width: 72,
        );
    }
  }

  factory StatusIndicator.toolStatus(ToolStatus status) {
    switch (status) {
      case ToolStatus.pending:
        return const StatusIndicator(
          label: 'pending',
          color: AppTheme.statusNeutralText,
          backgroundColor: AppTheme.statusNeutralBg,
          width: 72,
        );
      case ToolStatus.inProgress:
        return const StatusIndicator(
          label: 'running',
          color: AppTheme.successText,
          backgroundColor: AppTheme.successBg,
          width: 72,
        );
      case ToolStatus.completed:
        return const StatusIndicator(
          label: 'done',
          color: AppTheme.statusNeutralText,
          backgroundColor: AppTheme.statusNeutralBg,
          width: 72,
        );
      case ToolStatus.failed:
        return const StatusIndicator(
          label: 'failed',
          color: AppTheme.warning,
          backgroundColor: AppTheme.warningBg,
          width: 72,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: width ?? 66,
        maxWidth: width ?? double.infinity,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.mono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
