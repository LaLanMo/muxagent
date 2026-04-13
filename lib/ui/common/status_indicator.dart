import 'package:flutter/material.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import '../../domain/enums.dart';

class StatusIndicator extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;

  const StatusIndicator({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  factory StatusIndicator.sessionStatus(SessionStatus status) {
    switch (status) {
      case SessionStatus.running:
        return const StatusIndicator(
          label: 'running',
          color: AppTheme.successText,
          backgroundColor: AppTheme.successBg,
        );
      case SessionStatus.waitingApproval:
        return const StatusIndicator(
          label: 'awaiting',
          color: AppTheme.warning,
          backgroundColor: AppTheme.warningBg,
        );
      case SessionStatus.error:
        return const StatusIndicator(
          label: 'failed',
          color: AppTheme.errorText,
          backgroundColor: AppTheme.errorBg,
        );
      case SessionStatus.done:
      case SessionStatus.idle:
        return const StatusIndicator(
          label: 'done',
          color: AppTheme.statusNeutralText,
          backgroundColor: AppTheme.statusNeutralBg,
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
        );
      case ToolStatus.inProgress:
        return const StatusIndicator(
          label: 'running',
          color: AppTheme.successText,
          backgroundColor: AppTheme.successBg,
        );
      case ToolStatus.completed:
        return const StatusIndicator(
          label: 'done',
          color: AppTheme.statusNeutralText,
          backgroundColor: AppTheme.statusNeutralBg,
        );
      case ToolStatus.failed:
        return const StatusIndicator(
          label: 'failed',
          color: AppTheme.warning,
          backgroundColor: AppTheme.warningBg,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Text(
        label,
        style: AppTypography.mono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
