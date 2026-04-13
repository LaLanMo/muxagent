import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/app_typography.dart';
import '../../config/fonts.dart';
import '../../config/theme.dart';
import '../../domain/approval.dart';
import '../../domain/enums.dart';
import 'permission_detail_viewmodel.dart';

class PermissionDetailScreen extends GetView<PermissionDetailViewModel> {
  const PermissionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final approval = controller.approval;
    final title = approval.title.trim().isNotEmpty
        ? approval.title.trim()
        : 'Permission Required';
    final description =
        approval.descriptionText != null && approval.descriptionText != title
        ? approval.descriptionText
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(title),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description != null) ...[
                    Text(
                      description,
                      style: AppTypography.sans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (approval.commandText != null)
                    Container(
                      width: double.infinity,
                      color: AppTheme.codeBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        approval.commandText!,
                        style: AppFonts.code(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.codeText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Obx(
                    () => _buildActions(
                      approval,
                      disabled: controller.isReplying.value,
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

  Widget _buildHeader(String title) {
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.sans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        height: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Permission Request',
                      style: AppTypography.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textTertiary,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (allow != null) _buildAllowButton(allow, disabled),
        if (secondary != null && secondary.optionId != allow?.optionId)
          _buildTextAction(secondary, disabled),
        if (deny != null) _buildTextAction(deny, disabled),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          border: Border.all(
            color: disabled ? AppTheme.textMuted : AppTheme.chipBorder,
          ),
        ),
        child: Text(
          option.name,
          style: AppTypography.sans(
            fontSize: 13,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          option.name,
          style: AppTypography.sans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: disabled ? AppTheme.textMuted : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
