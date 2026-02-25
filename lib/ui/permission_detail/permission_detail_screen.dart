import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/fonts.dart';
import '../../config/theme.dart';
import '../../domain/approval.dart';
import '../../ui/chat/widgets/code_block.dart';
import 'permission_detail_viewmodel.dart';

class PermissionDetailScreen extends GetView<PermissionDetailViewModel> {
  const PermissionDetailScreen({super.key});

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  @override
  Widget build(BuildContext context) {
    final approval = controller.approval;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Permission Request',
          style: GoogleFonts.newsreader(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tool name
            Text(
              approval.toolName,
              style: AppFonts.codeLabel(color: AppTheme.textPrimary),
            ),

            // Kind label
            if (approval.kind != null && approval.kind!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  approval.kind!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ),
            ],

            // Title
            const SizedBox(height: 12),
            Text(
              approval.title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),

            // Input
            if (approval.input != null) ...[
              const SizedBox(height: 20),
              _buildSectionLabel('INPUT'),
              const SizedBox(height: 8),
              CodeBlock(text: _jsonEncoder.convert(approval.input)),
            ],

            // Option buttons
            const SizedBox(height: 24),
            _buildSectionLabel('ACTIONS'),
            const SizedBox(height: 12),
            Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: approval.options.map((option) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildOptionButton(
                        option,
                        controller.isReplying.value,
                      ),
                    );
                  }).toList(),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildOptionButton(PermOption option, bool disabled) {
    final name = option.name.toLowerCase();

    // "Allow" variants get teal filled
    if (name == 'allow' || name == 'yes') {
      return ElevatedButton(
        onPressed: disabled ? null : () => controller.replyApproval(option.optionId),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(option.name),
      );
    }

    // "Deny" variants get outlined warning
    if (name == 'deny' || name == 'reject' || name == 'no') {
      return OutlinedButton(
        onPressed: disabled ? null : () => controller.replyApproval(option.optionId),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.warning,
          side: const BorderSide(color: AppTheme.warning),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(option.name),
      );
    }

    // Everything else gets outlined neutral
    return OutlinedButton(
      onPressed: disabled ? null : () => controller.replyApproval(option.optionId),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: AppTheme.border),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(option.name),
    );
  }
}
