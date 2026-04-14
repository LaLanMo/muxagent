import 'package:flutter/material.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/fonts.dart';
import '../../../config/theme.dart';
import '../../../domain/approval.dart';
import '../../../domain/enums.dart';

class PermissionCard extends StatelessWidget {
  final ApprovalRequest approval;
  final bool enabled;
  final void Function(String optionId) onReply;

  const PermissionCard({
    super.key,
    required this.approval,
    this.enabled = true,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final title = approval.title.trim().isNotEmpty
        ? approval.title.trim()
        : 'Permission Required';
    final description =
        approval.descriptionText != null && approval.descriptionText != title
        ? approval.descriptionText
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(
          left: BorderSide(color: Color(0xFFC39229), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.shieldAlert,
                color: Color(0xFFC39229),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.sans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (description != null)
            Text(
              description,
              style: AppTypography.sans(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
              ),
            ),

          if (approval.commandText != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: const BoxDecoration(color: AppTheme.codeBg),
              child: Text(
                approval.commandText!,
                style: AppFonts.code(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.codeText,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: _buildActionButtons()),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    // Find Allow, Always, and Deny options
    Widget? allowButton;
    Widget? alwaysButton;
    Widget? denyButton;

    for (final option in approval.options) {
      switch (option.kind) {
        case PermOptionKind.allowOnce:
          allowButton = _buildAllowButton(option);
        case PermOptionKind.allowAlways:
          alwaysButton = _buildTextButton(option, AppTheme.textTertiary);
        case PermOptionKind.rejectOnce:
        case PermOptionKind.rejectAlways:
          denyButton = _buildTextButton(option, AppTheme.textTertiary);
      }
    }

    if (allowButton == null && alwaysButton == null && denyButton == null) {
      return approval.options.map((option) {
        return Expanded(child: _buildTextButton(option, AppTheme.textTertiary));
      }).toList();
    }

    final buttons = <Widget>[];
    if (allowButton != null) {
      buttons.add(Expanded(child: allowButton));
    }
    if (alwaysButton != null) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 12));
      buttons.add(Expanded(child: alwaysButton));
    }
    if (denyButton != null) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 12));
      buttons.add(Expanded(child: denyButton));
    }

    return buttons;
  }

  Widget _buildAllowButton(PermOption option) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!enabled) return;
        onReply(option.optionId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          border: Border.all(
            color: enabled ? AppTheme.chipBorder : AppTheme.textMuted,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          option.name,
          style: AppTypography.sans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildTextButton(PermOption option, Color color) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!enabled) return;
        onReply(option.optionId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Text(
          option.name,
          style: AppTypography.sans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: enabled ? color : AppTheme.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
