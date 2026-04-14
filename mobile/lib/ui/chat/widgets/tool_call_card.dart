import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/tool_activity.dart';
import '../../../routing/routes.dart';
import 'edit_diff_view.dart';

class ToolCallCard extends StatelessWidget {
  final ToolActivity tool;
  final List<ToolActivity> childTools;
  final bool foldDiff;

  const ToolCallCard({
    super.key,
    required this.tool,
    this.childTools = const [],
    this.foldDiff = false,
  });

  bool get _isRunning =>
      tool.status == ToolStatus.pending || tool.status == ToolStatus.inProgress;

  bool get _isFailed => tool.status == ToolStatus.failed;

  bool get _isCompleted => tool.status == ToolStatus.completed;

  bool get _isEditWithDiff {
    if (tool.effectiveKind != ToolKind.edit) return false;
    final diffs = tool.diffs;
    return diffs != null && diffs.isNotEmpty;
  }

  bool get _shouldShowDiff => _isEditWithDiff && !foldDiff;

  static const _accentSuccess = Color(0xFF4CB782);
  static const _accentFailure = Color(0xFFC65B52);

  static final _previewStyle = AppTypography.mono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static final _labelStyle = AppTypography.mono(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    final kind = tool.effectiveKind;
    final accentColor = _isFailed ? _accentFailure : _accentSuccess;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(width: 3, color: accentColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: _shouldShowDiff ? _buildEditLayout(kind) : _buildDefaultLayout(kind),
    );
  }

  Widget _buildDefaultLayout(ToolKind kind) {
    final hasChildren = childTools.isNotEmpty;
    return GestureDetector(
      onTap: () => Get.toNamed(
        Routes.toolDetail,
        arguments: {'tool': tool, 'childTools': childTools},
      ),
      child: hasChildren
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_buildHeaderRow(kind), _buildChildSummary()],
            )
          : _buildHeaderRow(kind),
    );
  }

  Widget _buildChildSummary() {
    final count = childTools.length;
    final noun = count == 1 ? 'tool call' : 'tool calls';
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 6),
      child: Row(
        children: [
          const Icon(
            LucideIcons.wrench,
            size: 12,
            color: AppTheme.textMetadata,
          ),
          const SizedBox(width: 6),
          Text(
            '$count $noun',
            style: AppTypography.mono(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppTheme.textMetadata,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditLayout(ToolKind kind) {
    final diffs = tool.diffs!;
    final previewDiff = diffs.first;
    final extraDiffCount = diffs.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderRow(kind),
        if (_isCompleted)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (extraDiffCount > 0) ...[
                  Text(
                    'Previewing 1 of ${diffs.length} file changes',
                    style: AppTypography.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textMetadata,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                EditDiffView(
                  oldString: previewDiff.oldText ?? '',
                  newString: previewDiff.newText,
                  maxCollapsedLines: 5,
                  contextLines: 1,
                ),
                if (extraDiffCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '+$extraDiffCount more file ${extraDiffCount == 1 ? 'change' : 'changes'} in details',
                    style: AppTypography.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textMetadata,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderRow(ToolKind kind) {
    final iconColor = _isFailed ? _accentFailure : AppTheme.textTertiary;
    final hasChildren = childTools.isNotEmpty;
    final icon = hasChildren ? LucideIcons.layers : _iconForKind(kind);

    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: _buildPreviewContent(kind)),
        const SizedBox(width: 10),
        _buildKindBadge(kind),
        if (_shouldShowDiff) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => Get.toNamed(
              Routes.toolDetail,
              arguments: {'tool': tool, 'childTools': childTools},
            ),
            child: const Icon(
              LucideIcons.arrowUpRight,
              size: 14,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewContent(ToolKind kind) {
    final text = _displayPreviewText(kind);
    final style = _previewStyle.copyWith(color: AppTheme.textPrimary);

    return Text(
      text,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildKindBadge(ToolKind kind) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: _badgeBackground(kind),
      child: Text(
        _badgeLabel(kind),
        style: _labelStyle.copyWith(color: _badgeForeground(kind)),
      ),
    );
  }

  String _badgeLabel(ToolKind kind) {
    if (_isFailed) return 'FAILED';
    if (_isRunning) return 'RUNNING';
    if (_isCompleted) return 'DONE';
    return _kindLabel(kind);
  }

  Color _badgeBackground(ToolKind kind) {
    if (_isFailed) return AppTheme.errorBg;
    if (_isRunning || _isCompleted) {
      return const Color(0xFFD6EDDC);
    }
    return AppTheme.surfaceMuted;
  }

  Color _badgeForeground(ToolKind kind) {
    if (_isFailed) return AppTheme.errorText;
    if (_isRunning || _isCompleted) {
      return const Color(0xFF1A6B3A);
    }
    return AppTheme.textSecondary;
  }

  String _headerText(ToolKind kind) {
    final t = tool.title ?? tool.name;
    if (t.isNotEmpty) return t;
    switch (kind) {
      case ToolKind.execute:
        return 'Bash';
      case ToolKind.read:
        return 'Read';
      case ToolKind.edit:
        return 'Edit';
      case ToolKind.search:
        return 'Search';
      case ToolKind.fetch:
        return 'Fetch';
      case ToolKind.delete:
        return 'Delete';
      case ToolKind.move:
        return 'Move';
      case ToolKind.think:
        return 'Think';
      case ToolKind.switchMode:
        return 'Switch Mode';
      case ToolKind.other:
        return 'Tool';
    }
  }

  String? _bodyPreview(ToolKind kind) {
    final input = tool.input;
    if (input == null) return null;

    switch (kind) {
      case ToolKind.execute:
        if (input.description != null && input.description!.isNotEmpty) {
          return input.description;
        }
        final cmd = input.command?.display;
        if (cmd != null && cmd.isNotEmpty) return cmd;
        return null;
      case ToolKind.read:
        return input.filePath;
      case ToolKind.edit:
        final diffs = tool.diffs;
        if (diffs != null && diffs.isNotEmpty) return diffs.first.path;
        return input.filePath;
      case ToolKind.search:
        return input.pattern ?? input.filePath;
      case ToolKind.fetch:
        return input.url;
      case ToolKind.delete:
        return input.filePath;
      case ToolKind.move:
        return input.sourcePath;
      case ToolKind.think:
        return null;
      case ToolKind.switchMode:
        return input.mode;
      case ToolKind.other:
        return input.description ??
            input.command?.display ??
            input.filePath ??
            input.sourcePath ??
            input.targetPath ??
            input.pattern ??
            input.url ??
            input.mode;
    }
  }

  String _displayPreviewText(ToolKind kind) {
    final raw = (_bodyPreview(kind) ?? _headerText(kind)).trim();
    if (raw.isEmpty) {
      return _headerText(kind);
    }
    return _formatPathPreview(raw);
  }

  String _formatPathPreview(String value) {
    final normalized = value
        .replaceFirst(RegExp(r'^/(Users|home)/[^/]+'), '~')
        .trim();
    final segments = normalized.split('/');
    if (segments.length > 4) {
      return '\u2026/${segments.sublist(segments.length - 2).join('/')}';
    }
    return normalized;
  }

  IconData _iconForKind(ToolKind kind) {
    switch (kind) {
      case ToolKind.execute:
        return LucideIcons.terminal;
      case ToolKind.read:
        return LucideIcons.fileText;
      case ToolKind.edit:
        return LucideIcons.pencil;
      case ToolKind.search:
        return LucideIcons.search;
      case ToolKind.fetch:
        return LucideIcons.globe;
      case ToolKind.delete:
        return LucideIcons.trash2;
      case ToolKind.move:
        return LucideIcons.folderInput;
      case ToolKind.think:
        return LucideIcons.brain;
      case ToolKind.switchMode:
        return LucideIcons.repeat2;
      case ToolKind.other:
        return LucideIcons.wrench;
    }
  }

  String _kindLabel(ToolKind kind) {
    switch (kind) {
      case ToolKind.execute:
        return 'RUN';
      case ToolKind.read:
        return 'READ';
      case ToolKind.edit:
        return 'EDIT';
      case ToolKind.search:
        return 'SEARCH';
      case ToolKind.fetch:
        return 'FETCH';
      case ToolKind.delete:
        return 'DELETE';
      case ToolKind.move:
        return 'MOVE';
      case ToolKind.think:
        return 'THINK';
      case ToolKind.switchMode:
        return 'MODE';
      case ToolKind.other:
        return 'TOOL';
    }
  }
}
