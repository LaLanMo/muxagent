import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/fonts.dart';
import '../../../config/theme.dart';
import '../../../domain/approval.dart';
import 'code_block.dart';

class PermissionCard extends StatelessWidget {
  final ApprovalRequest approval;
  final void Function(String optionId) onReply;

  const PermissionCard({
    super.key,
    required this.approval,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningCardBg,
        border: Border.all(color: AppTheme.warning, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                'Permission Required',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tool name + kind
          Text(
            approval.toolName,
            style: AppFonts.codeLabel(color: AppTheme.textPrimary),
          ),
          if (approval.kind != null && approval.kind!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              approval.kind!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],

          // Command preview
          if (_commandText != null) ...[
            const SizedBox(height: 10),
            CodeBlock(
              text: _commandText!,
              backgroundColor: const Color(0xFF1A1A1A),
              showCopyButton: false,
            ),
          ],

          // Option buttons
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: approval.options.map((option) {
              return _buildOptionButton(option);
            }).toList(),
          ),
        ],
      ),
    );
  }

  String? get _commandText {
    final input = approval.input;
    if (input == null) return null;
    final command = input['command'];
    if (command is String && command.isNotEmpty) return command;
    return null;
  }

  Widget _buildOptionButton(PermOption option) {
    final name = option.name.toLowerCase();

    // "Allow" variants get teal filled
    if (name == 'allow' || name == 'yes') {
      return ElevatedButton(
        onPressed: () => onReply(option.optionId),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(option.name),
      );
    }

    // "Deny" variants get outlined with warning color
    if (name == 'deny' || name == 'reject' || name == 'no') {
      return OutlinedButton(
        onPressed: () => onReply(option.optionId),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.warning,
          side: const BorderSide(color: AppTheme.warning),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(option.name),
      );
    }

    // Everything else gets outlined neutral
    return OutlinedButton(
      onPressed: () => onReply(option.optionId),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: AppTheme.border),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(option.name),
    );
  }
}
