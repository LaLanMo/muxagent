import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          left: BorderSide(color: AppTheme.warning, width: 3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                LucideIcons.shieldAlert,
                color: AppTheme.warning,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Permission Required',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          if (approval.descriptionText != null)
            Text(
              approval.descriptionText!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
              ),
            ),

          // Command preview
          if (approval.commandText != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.codeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                approval.commandText!,
                style: AppFonts.code(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.codeText,
                ),
              ),
            ),
          ],

          if (approval.cwd != null && approval.cwd!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'cwd: ${approval.cwd!}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary,
              ),
            ),
          ],

          // Action buttons: 3 equal columns
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
          denyButton = _buildTextButton(option, AppTheme.textSecondary);
      }
    }

    // Fall back to showing all options as equal columns if no match
    if (allowButton == null && alwaysButton == null && denyButton == null) {
      return approval.options.map((option) {
        return Expanded(
          child: _buildTextButton(option, AppTheme.textSecondary),
        );
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
        debugPrint('[PermCard] tapped Allow: ${option.optionId}');
        onReply(option.optionId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          option.name,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
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
        debugPrint('[PermCard] tapped ${option.name}: ${option.optionId}');
        onReply(option.optionId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Text(
          option.name,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: enabled ? color : AppTheme.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
