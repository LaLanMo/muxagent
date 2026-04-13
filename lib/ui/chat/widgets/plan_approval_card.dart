import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/app_typography.dart';
import '../../../config/theme.dart';
import '../../../domain/approval.dart';
import '../../../domain/enums.dart';

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
    final plan = _PlanContent.fromApproval(approval);

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
                  approval.resolved ? 'Plan Review' : 'Review Plan',
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
            child: _buildPlanBody(plan),
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

  Widget _buildPlanBody(_PlanContent plan) {
    final children = <Widget>[];

    if (plan.title != null) {
      children.add(
        Text(
          plan.title!,
          style: AppTypography.sans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      );
    }

    if (plan.description != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 10));
      }
      children.add(
        Text(
          plan.description!,
          style: AppTypography.sans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      );
    }

    if (plan.steps.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 10));
      }
      children.add(
        Text(
          'Steps:',
          style: AppTypography.sans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      );
      children.add(const SizedBox(height: 4));
      children.addAll(
        plan.steps.map(
          (step) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              step,
              style: AppTypography.mono(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
    } else if (plan.permissions.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 10));
      }
      children.add(
        Text(
          'Requested Permissions',
          style: AppTypography.sans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      );
      children.add(const SizedBox(height: 4));
      children.addAll(
        plan.permissions.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              item,
              style: AppTypography.mono(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
    }

    if (children.isEmpty) {
      children.add(
        Text(
          'Review the proposed implementation before switching to coding.',
          style: AppTypography.sans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
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
        'Ready to code?',
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

class _PlanContent {
  final String? title;
  final String? description;
  final List<String> steps;
  final List<String> permissions;

  const _PlanContent({
    this.title,
    this.description,
    this.steps = const [],
    this.permissions = const [],
  });

  factory _PlanContent.fromApproval(ApprovalRequest approval) {
    final prose = <String>[];
    final steps = <String>[];

    final lines = (approval.planMarkdown ?? '')
        .split('\n')
        .map(_cleanMarkdownLine)
        .where((line) => line.isNotEmpty)
        .toList();

    for (final line in lines) {
      if (_isStructuralLabel(line)) {
        continue;
      }

      final numbered = RegExp(r'^\d+[.)]\s+(.+)$').firstMatch(line);
      if (numbered != null) {
        steps.add(numbered.group(1)!.trim());
        continue;
      }

      final bullet = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
      if (bullet != null) {
        steps.add(bullet.group(1)!.trim());
        continue;
      }

      prose.add(line);
    }

    final explicitTitle = _normalizeText(approval.title);
    final hasSpecificTitle =
        explicitTitle != null && !_isGenericPlanTitle(explicitTitle);
    String? title = hasSpecificTitle ? explicitTitle : null;

    final descriptionCandidate = _normalizeText(approval.descriptionText);
    String? description =
        descriptionCandidate != null && descriptionCandidate != title
        ? descriptionCandidate
        : null;

    if (title == null && prose.isNotEmpty) {
      title = prose.removeAt(0);
    }

    if (description == null && prose.isNotEmpty) {
      description = prose.removeAt(0);
    }

    if (prose.isNotEmpty) {
      final remainder = prose.join(' ');
      description = description == null ? remainder : '$description $remainder';
    }

    return _PlanContent(
      title: title,
      description: description,
      steps: steps,
      permissions: approval.allowedPrompts,
    );
  }

  static String _cleanMarkdownLine(String line) {
    return line
        .replaceFirst(RegExp(r'^#+\s*'), '')
        .replaceFirst(RegExp(r'^>\s*'), '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('`', '')
        .trim();
  }

  static bool _isStructuralLabel(String line) {
    final lower = line.toLowerCase();
    return lower == 'steps:' || lower == 'step:' || lower == 'plan:';
  }

  static String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static bool _isGenericPlanTitle(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'review plan' ||
        normalized == 'plan review' ||
        normalized == 'plan' ||
        normalized == 'approve plan';
  }
}
