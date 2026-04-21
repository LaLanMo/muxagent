import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/app_typography.dart';
import '../../../config/theme.dart';
import '../../../domain/approval.dart';
import '../../../domain/enums.dart';
import '../../../i18n/tx.dart';
import 'code_block.dart';

class PlanApprovalCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final accent = approval.resolved
        ? AppTheme.chipBorder
        : AppTheme.planAccent;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(LucideIcons.fileText, size: 14, color: accent),
                const SizedBox(width: 8),
                Text(
                  approval.resolved
                      ? Tx.chatPlanReview.tr
                      : Tx.chatReviewPlan.tr,
                  style: AppTypography.sans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: _buildPlanBody(),
          ),
          if (!approval.resolved) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: _buildActionSection(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanBody() {
    final markdown = _planMarkdown;
    if (markdown == null) {
      return Text(
        Tx.chatPlanFallback.tr,
        style: AppTypography.sans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppTheme.textSecondary,
          height: 1.5,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: SelectionArea(
        child: GptMarkdown(
          markdown,
          style: AppTypography.sans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
          codeBuilder: (context, name, code, closed) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: CodeBlock(text: code),
          ),
        ),
      ),
    );
  }

  String? get _planMarkdown {
    final markdown = approval.planMarkdown?.trim();
    if (markdown != null && markdown.isNotEmpty) {
      return markdown;
    }

    final sections = <String>[];
    final description =
        _normalizeText(approval.reason) ?? _normalizeText(approval.bodyText);
    if (description != null) {
      sections.add(description);
    }

    if (approval.allowedPrompts.isNotEmpty) {
      if (sections.isNotEmpty) {
        sections.add('');
      }
      sections.add('**${Tx.chatRequestedPermissions.tr}**');
      sections.add('');
      sections.addAll(approval.allowedPrompts.map((item) => '- $item'));
    }

    if (sections.isEmpty) {
      return null;
    }
    return sections.join('\n');
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Widget _buildActionSection() {
    final primary =
        _firstOption(PermOptionKind.allowAlways) ??
        _firstOption(PermOptionKind.allowOnce);
    final secondary = primary?.kind == PermOptionKind.allowAlways
        ? _firstOption(PermOptionKind.allowOnce)
        : null;
    final reject =
        _firstOption(PermOptionKind.rejectOnce) ??
        _firstOption(PermOptionKind.rejectAlways);

    final children = <Widget>[
      Text(
        Tx.chatReadyToCode.tr,
        style: AppTypography.sans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    ];

    if (primary != null) {
      children.add(const SizedBox(height: 12));
      children.add(_buildPrimaryButton(primary));
    }

    if (secondary != null) {
      children.add(const SizedBox(height: 12));
      children.add(_buildSecondaryButton(secondary));
    }

    if (reject != null) {
      children.add(const SizedBox(height: 12));
      children.add(_buildTextAction(reject));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  PermOption? _firstOption(PermOptionKind kind) {
    for (final option in approval.options) {
      if (option.kind == kind) {
        return option;
      }
    }
    return null;
  }

  Widget _buildPrimaryButton(PermOption option) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onReply(option.optionId) : null,
      child: Container(
        width: double.infinity,
        height: 44,
        color: enabled ? AppTheme.primary : AppTheme.borderStrong,
        alignment: Alignment.center,
        child: Text(
          option.name,
          style: AppTypography.sans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.surface,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(PermOption option) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onReply(option.optionId) : null,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.chipBorder),
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

  Widget _buildTextAction(PermOption option) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onReply(option.optionId) : null,
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: Center(
          child: Text(
            option.name,
            style: AppTypography.sans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: enabled ? AppTheme.textTertiary : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
