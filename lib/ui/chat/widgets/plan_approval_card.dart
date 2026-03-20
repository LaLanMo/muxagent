import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../domain/approval.dart';
import '../../../domain/enums.dart';
import 'code_block.dart';

class PlanApprovalCard extends StatefulWidget {
  final ApprovalRequest approval;
  final bool enabled;
  final void Function(String optionId) onReply;

  const PlanApprovalCard({
    super.key,
    required this.approval,
    this.enabled = true,
    required this.onReply,
  });

  @override
  State<PlanApprovalCard> createState() => _PlanApprovalCardState();
}

class _PlanApprovalCardState extends State<PlanApprovalCard> {
  String? get _planText {
    final plan = widget.approval.planMarkdown?.trim();
    if (plan == null || plan.isEmpty) return null;
    return plan;
  }

  List<String> get _allowedPrompts {
    return widget.approval.allowedPrompts;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = widget.approval.resolved;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(
            color: resolved ? AppTheme.textTertiary : AppTheme.planAccent,
            width: 3,
          ),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(
                  LucideIcons.fileText,
                  color: resolved ? AppTheme.textTertiary : AppTheme.planAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.approval.resolved ? 'Plan (Rejected)' : 'Review Plan',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.approval.resolved
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppTheme.border),
          ),

          // Plan body
          if (_planText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SelectionArea(
                child: GptMarkdown(
                  _planText!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                  codeBuilder: (context, name, code, closed) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: CodeBlock(text: code),
                  ),
                ),
              ),
            ),

          // Requested Permissions
          if (_allowedPrompts.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppTheme.border),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requested Permissions',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._allowedPrompts.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.terminal,
                            size: 13,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action section (hidden after resolved)
          if (!widget.approval.resolved) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppTheme.border),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildButtonsView(),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildButtonsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ready to code?',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ..._buildActionButtons(),
      ],
    );
  }

  List<Widget> _buildActionButtons() {
    final widgets = <Widget>[];

    for (final option in widget.approval.options) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 10));
      }

      switch (option.kind) {
        case PermOptionKind.allowAlways:
          widgets.add(_buildFilledButton(option));
        case PermOptionKind.allowOnce:
          widgets.add(_buildOutlinedButton(option));
        case PermOptionKind.rejectOnce:
        case PermOptionKind.rejectAlways:
          widgets.add(_buildMutedButton(option));
      }
    }

    return widgets;
  }

  void _handleTap(PermOption option) {
    if (!widget.enabled) return;
    widget.onReply(option.optionId);
  }

  Widget _buildFilledButton(PermOption option) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(option),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          option.name,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(PermOption option) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(option),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          option.name,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMutedButton(PermOption option) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(option),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        alignment: Alignment.center,
        child: Text(
          option.name,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMetadata,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
