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
          label: 'Running',
          color: AppTheme.successText,
          backgroundColor: AppTheme.successBg,
        );
      case SessionStatus.waitingApproval:
        return const StatusIndicator(
          label: 'Approval',
          color: AppTheme.warning,
          backgroundColor: AppTheme.warningBg,
        );
      case SessionStatus.error:
        return const StatusIndicator(
          label: 'Error',
          color: AppTheme.errorText,
          backgroundColor: AppTheme.errorBg,
        );
      case SessionStatus.done:
      case SessionStatus.idle:
        return StatusIndicator(
          label: 'Idle',
          color: AppTheme.textSecondary,
          backgroundColor: AppTheme.idleBg,
        );
    }
  }

  factory StatusIndicator.toolStatus(ToolStatus status) {
    switch (status) {
      case ToolStatus.pending:
        return StatusIndicator(
          label: 'Pending',
          color: AppTheme.textSecondary,
          backgroundColor: AppTheme.idleBg,
        );
      case ToolStatus.inProgress:
        return const StatusIndicator(
          label: 'Running',
          color: AppTheme.successText,
          backgroundColor: AppTheme.successBg,
        );
      case ToolStatus.completed:
        return const StatusIndicator(
          label: 'Done',
          color: AppTheme.successText,
          backgroundColor: AppTheme.successBg,
        );
      case ToolStatus.failed:
        return const StatusIndicator(
          label: 'Failed',
          color: AppTheme.warning,
          backgroundColor: AppTheme.warningBg,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.sans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
