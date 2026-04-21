import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/app_typography.dart';
import '../../config/fonts.dart';
import '../../config/theme.dart';
import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../i18n/tx.dart';
import 'permission_detail_viewmodel.dart';

class PermissionDetailScreen extends GetView<PermissionDetailViewModel> {
  const PermissionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final approval = controller.approval;
    final description = approval.commandText == null
        ? approval.descriptionText?.trim()
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (approval.commandText != null)
                    _buildCodeBlock(approval.commandText!)
                  else if (description != null && description.isNotEmpty) ...[
                    Text(
                      description,
                      style: AppTypography.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const Spacer(),
                  SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 20),
                    child: Obx(
                      () => _buildActions(
                        approval,
                        disabled: controller.isReplying.value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.borderStrong)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: Get.back,
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      LucideIcons.chevronLeft,
                      size: 20,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Tx.permissionRequest.tr,
                    style: AppTypography.sans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBlock(String command) {
    return Container(
      width: double.infinity,
      color: AppTheme.codeBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: SelectableText(
        command,
        style: AppFonts.code(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppTheme.codeText,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildActions(ApprovalRequest approval, {required bool disabled}) {
    final allow = _firstOption(approval, const [
      PermOptionKind.allowOnce,
      PermOptionKind.allowAlways,
    ]);
    final secondary = _firstOption(approval, const [
      PermOptionKind.allowAlways,
    ]);
    final deny = _firstOption(approval, const [
      PermOptionKind.rejectOnce,
      PermOptionKind.rejectAlways,
    ]);
    final actions = <Widget>[];

    void pushAction(Widget action) {
      if (actions.isNotEmpty) {
        actions.add(const SizedBox(height: 12));
      }
      actions.add(action);
    }

    if (allow != null) {
      pushAction(_buildAllowButton(allow, disabled));
    }
    if (secondary != null && secondary.optionId != allow?.optionId) {
      pushAction(_buildTextAction(secondary, disabled));
    }
    if (deny != null) {
      pushAction(_buildTextAction(deny, disabled));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: actions,
    );
  }

  PermOption? _firstOption(
    ApprovalRequest approval,
    List<PermOptionKind> kinds,
  ) {
    for (final kind in kinds) {
      for (final option in approval.options) {
        if (option.kind == kind) {
          return option;
        }
      }
    }
    return null;
  }

  Widget _buildAllowButton(PermOption option, bool disabled) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : () => controller.replyApproval(option.optionId),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(
            color: disabled ? AppTheme.textMuted : AppTheme.textPrimary,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          option.name,
          style: AppTypography.sans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: disabled ? AppTheme.textMuted : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTextAction(PermOption option, bool disabled) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : () => controller.replyApproval(option.optionId),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Text(
          option.name,
          style: AppTypography.sans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: disabled ? AppTheme.textMuted : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
