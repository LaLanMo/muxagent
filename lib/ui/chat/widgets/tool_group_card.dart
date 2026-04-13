import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/tool_activity.dart';
import '../../../routing/routes.dart';

/// Collapses 2+ consecutive tool calls into a single expandable card.
///
/// Collapsed: wrench icon + "N tool calls" + summary "Read ×3 · Grep"
/// Expanded:  header + divider + individual compact tool rows
class ToolGroupCard extends StatefulWidget {
  final List<ToolActivity> tools;
  final bool initiallyExpanded;

  const ToolGroupCard({
    super.key,
    required this.tools,
    this.initiallyExpanded = false,
  });

  @override
  State<ToolGroupCard> createState() => _ToolGroupCardState();
}

class _ToolGroupCardState extends State<ToolGroupCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;
  Timer? _dotTimer;
  int _dotCount = 3;
  late bool _expanded;

  bool get _hasRunning => widget.tools.any(
    (t) => t.status == ToolStatus.pending || t.status == ToolStatus.inProgress,
  );

  bool get _hasFailed => widget.tools.any((t) => t.status == ToolStatus.failed);

  Color get _accentColor =>
      _hasFailed ? AppTheme.failedRed : AppTheme.successText;

  static final _labelStyle = AppTypography.mono(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _breathAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant ToolGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-collapse when streaming ends
    if (oldWidget.initiallyExpanded && !widget.initiallyExpanded) {
      setState(() => _expanded = false);
    }

    // Sync breathing animation if status changed
    if (_statusChanged(oldWidget.tools, widget.tools)) {
      _syncAnimations();
    }
  }

  static bool _statusChanged(
    List<ToolActivity> oldTools,
    List<ToolActivity> newTools,
  ) {
    if (oldTools.length != newTools.length) return true;
    for (int i = 0; i < oldTools.length; i++) {
      if (oldTools[i].status != newTools[i].status) return true;
    }
    return false;
  }

  void _syncAnimations() {
    if (_hasRunning) {
      _breathController.repeat(reverse: true);
      _dotTimer ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() => _dotCount = _dotCount % 3 + 1);
      });
    } else {
      _breathController.stop();
      _breathController.value = 0.0;
      _dotTimer?.cancel();
      _dotTimer = null;
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              left: BorderSide(
                width: 3,
                color: _accentColor.withValues(
                  alpha: _hasRunning ? _breathAnimation.value : 1.0,
                ),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (!_expanded) ...[
            _buildSummary(),
            if (_hasFailed) _buildFailureHint(),
          ],
          if (_expanded) _buildExpandedRows(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header row
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final count = widget.tools.length;
    final noun = count == 1 ? 'tool call' : 'tool calls';
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(LucideIcons.layers, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(
            '$count $noun',
            style: AppTypography.sans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            _headerStatusLabel(),
            style: _labelStyle.copyWith(
              color: _hasFailed ? AppTheme.failedRed : AppTheme.successText,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            _expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Collapsed summary
  // ---------------------------------------------------------------------------

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 4),
      child: Text(
        _summaryText(),
        style: AppTypography.mono(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.textMetadata,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _summaryText() {
    final counts = <ToolKind, int>{};
    final seen = <ToolKind>[];
    for (final t in widget.tools) {
      final k = t.effectiveKind;
      counts[k] = (counts[k] ?? 0) + 1;
      if (!seen.contains(k)) seen.add(k);
    }
    return seen
        .map((k) {
          final label = _kindLabel(k);
          final count = counts[k]!;
          return count > 1 ? '$label \u00D7$count' : label;
        })
        .join(' \u00B7 ');
  }

  String _headerStatusLabel() {
    if (_hasFailed) return 'FAILED';
    if (_hasRunning) return 'RUNNING${'.' * _dotCount}';
    return 'TOOLS';
  }

  // ---------------------------------------------------------------------------
  // Failure hint (collapsed only)
  // ---------------------------------------------------------------------------

  Widget _buildFailureHint() {
    final failed = widget.tools.where((t) => t.status == ToolStatus.failed);
    if (failed.isEmpty) return const SizedBox.shrink();

    final first = failed.first;
    final preview = _previewText(first);
    final extra = failed.length - 1;
    final suffix = extra > 0 ? ' (+$extra more failed)' : '';

    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 4),
      child: Row(
        children: [
          const Icon(LucideIcons.x, size: 12, color: AppTheme.failedRed),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$preview$suffix',
              style: AppTypography.mono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.failedRed,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Expanded tool rows
  // ---------------------------------------------------------------------------

  Widget _buildExpandedRows() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 6),
          ...widget.tools.map(_buildToolRow),
        ],
      ),
    );
  }

  Widget _buildToolRow(ToolActivity tool) {
    final kind = tool.effectiveKind;
    final isFailed = tool.status == ToolStatus.failed;
    final iconColor = isFailed ? AppTheme.failedRed : AppTheme.textSecondary;
    final preview = _previewText(tool);

    return GestureDetector(
      onTap: () => Get.toNamed(
        Routes.toolDetail,
        arguments: {'tool': tool, 'childTools': <ToolActivity>[]},
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(_iconForKind(kind), size: 14, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preview,
                style: AppTypography.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isFailed ? AppTheme.failedRed : AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _kindLabel(kind).toUpperCase(),
              style: AppTypography.mono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppTheme.textMetadata,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers (duplicated from ToolCallCard — extract to shared utility later)
  // ---------------------------------------------------------------------------

  String _previewText(ToolActivity tool) {
    final kind = tool.effectiveKind;
    final input = tool.input;

    // Try to get a meaningful preview from tool input
    String? preview;
    if (input != null) {
      switch (kind) {
        case ToolKind.execute:
          preview = input.description ?? input.command?.display;
        case ToolKind.read:
          preview = input.filePath;
        case ToolKind.edit:
          final diffs = tool.diffs;
          preview = (diffs != null && diffs.isNotEmpty)
              ? diffs.first.path
              : input.filePath;
        case ToolKind.search:
          preview = input.pattern ?? input.filePath;
        case ToolKind.fetch:
          preview = input.url;
        case ToolKind.delete:
          preview = input.filePath;
        case ToolKind.move:
          preview = input.sourcePath;
        case ToolKind.think:
          preview = null;
        case ToolKind.switchMode:
          preview = input.mode;
        case ToolKind.other:
          preview =
              input.description ??
              input.command?.display ??
              input.filePath ??
              input.pattern ??
              input.url;
      }
    }

    if (preview != null && preview.isNotEmpty) {
      // Middle-truncate file paths (keep last 2 segments)
      const pathKinds = {ToolKind.read, ToolKind.edit, ToolKind.delete};
      if (pathKinds.contains(kind)) {
        final segments = preview.split('/');
        if (segments.length > 3) {
          return '\u2026/${segments.sublist(segments.length - 2).join('/')}';
        }
      }
      return preview;
    }

    return tool.title ?? tool.name;
  }

  static IconData _iconForKind(ToolKind kind) {
    switch (kind) {
      case ToolKind.execute:
        return LucideIcons.terminal;
      case ToolKind.read:
        return LucideIcons.eye;
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

  static String _kindLabel(ToolKind kind) {
    switch (kind) {
      case ToolKind.read:
        return 'Read';
      case ToolKind.edit:
        return 'Edit';
      case ToolKind.search:
        return 'Search';
      case ToolKind.execute:
        return 'Bash';
      case ToolKind.fetch:
        return 'Fetch';
      case ToolKind.delete:
        return 'Delete';
      case ToolKind.move:
        return 'Move';
      case ToolKind.think:
        return 'Think';
      case ToolKind.switchMode:
        return 'Mode';
      case ToolKind.other:
        return 'Tool';
    }
  }
}
