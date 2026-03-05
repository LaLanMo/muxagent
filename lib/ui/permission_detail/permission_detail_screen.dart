import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/fonts.dart';
import '../../config/theme.dart';
import '../../domain/approval.dart';
import 'permission_detail_viewmodel.dart';

class PermissionDetailScreen extends GetView<PermissionDetailViewModel> {
  const PermissionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final approval = controller.approval;

    return Scaffold(
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Command block
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.codeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Text(
                      _commandText(approval) ?? approval.title,
                      style: AppFonts.code(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.codeText,
                      ),
                    ),
                  ),

                  // Spacer fills remaining space
                  const Spacer(),

                  // Actions
                  Obx(() => _buildActions(approval, controller.isReplying.value)),
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Get.back(),
              child: const Icon(
                LucideIcons.chevronLeft,
                size: 22,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Permission Request',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _commandText(ApprovalRequest approval) {
    final input = approval.input;
    if (input == null) return null;
    final command = input['command'];
    if (command is String && command.isNotEmpty) return command;
    return null;
  }

  Widget _buildActions(ApprovalRequest approval, bool disabled) {
    final widgets = <Widget>[];

    for (final option in approval.options) {
      final name = option.name.toLowerCase();

      if (name == 'allow' || name == 'yes') {
        // "Allow" button: outlined with dark border
        widgets.add(
          GestureDetector(
            onTap: disabled
                ? null
                : () => controller.replyApproval(option.optionId),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                    Border.all(color: AppTheme.textPrimary, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                option.name,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        );
      } else {
        // "Always Allow" / "Deny" text buttons
        widgets.add(
          GestureDetector(
            onTap: disabled
                ? null
                : () => controller.replyApproval(option.optionId),
            child: SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  option.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Add gap between buttons
      if (option != approval.options.last) {
        widgets.add(const SizedBox(height: 10));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
}
