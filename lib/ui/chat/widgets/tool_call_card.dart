import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/tool_activity.dart';
import '../../../routing/routes.dart';
import 'edit_diff_view.dart';

class ToolCallCard extends StatefulWidget {
  final ToolActivity tool;
  final List<ToolActivity> childTools;

  const ToolCallCard({
    super.key,
    required this.tool,
    this.childTools = const [],
  });

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;
  Timer? _dotTimer;
  int _dotCount = 3;

  bool get _isRunning =>
      widget.tool.status == ToolStatus.pending ||
      widget.tool.status == ToolStatus.inProgress;

  bool get _isFailed => widget.tool.status == ToolStatus.failed;

  bool get _isCompleted => widget.tool.status == ToolStatus.completed;

  bool get _isEditWithDiff {
    if (widget.tool.effectiveKind != ToolKind.edit) return false;
    final input = widget.tool.input;
    if (input == null) return false;
    final old = input['old_string'];
    final neu = input['new_string'];
    return old is String && neu is String;
  }

  @override
  void initState() {
    super.initState();
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
  void didUpdateWidget(covariant ToolCallCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tool.status != widget.tool.status) {
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    if (_isRunning) {
      _breathController.repeat(reverse: true);
      _dotTimer ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
        setState(() => _dotCount = _dotCount % 3 + 1);
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

  @override
  Widget build(BuildContext context) {
    final kind = widget.tool.effectiveKind;
    final accentColor = _isFailed ? AppTheme.failedRed : AppTheme.successText;

    return AnimatedBuilder(
      animation: _breathAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                width: 3,
                color: accentColor.withValues(
                  alpha: _isRunning ? _breathAnimation.value : 1.0,
                ),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: child,
        );
      },
      child: _isEditWithDiff
          ? _buildEditLayout(kind)
          : _buildDefaultLayout(kind),
    );
  }

  // -------------------------------------------------------------------------
  // Default layout (all non-edit tools, or edit without diff data)
  // -------------------------------------------------------------------------

  Widget _buildDefaultLayout(ToolKind kind) {
    final hasChildren = widget.childTools.isNotEmpty;
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.toolDetail, arguments: {
        'tool': widget.tool,
        'childTools': widget.childTools,
      }),
      child: hasChildren
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderRow(kind),
                _buildChildSummary(),
              ],
            )
          : _buildHeaderRow(kind),
    );
  }

  Widget _buildChildSummary() {
    final count = widget.childTools.length;
    final noun = count == 1 ? 'tool call' : 'tool calls';
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 4),
      child: Row(
        children: [
          const Icon(LucideIcons.wrench, size: 12, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Text(
            '$count $noun',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Edit layout: header + collapsible diff
  // -------------------------------------------------------------------------

  Widget _buildEditLayout(ToolKind kind) {
    final input = widget.tool.input!;
    final oldString = input['old_string'] as String;
    final newString = input['new_string'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderRow(kind),
        if (_isCompleted)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: EditDiffView(
              oldString: oldString,
              newString: newString,
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Shared header row
  // -------------------------------------------------------------------------

  Widget _buildHeaderRow(ToolKind kind) {
    final iconColor =
        _isFailed ? AppTheme.failedRed : AppTheme.textSecondary;

    final hasChildren = widget.childTools.isNotEmpty;
    final icon = hasChildren ? LucideIcons.layers : _iconForKind(kind);

    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: _buildPreviewContent(kind)),
        // Running status label + animated dots
        if (_isRunning) ...[
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _runningLabel(kind),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppTheme.successText,
                ),
              ),
              SizedBox(
                width: 18,
                child: Text(
                  '.' * _dotCount,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppTheme.successText,
                  ),
                ),
              ),
            ],
          ),
        ],
        // Navigate to tool detail (edit tools only)
        if (_isEditWithDiff) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => Get.toNamed(Routes.toolDetail, arguments: {
              'tool': widget.tool,
              'childTools': widget.childTools,
            }),
            child: Icon(
              LucideIcons.arrowUpRight,
              size: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Icon / preview helpers
  // -------------------------------------------------------------------------

  String _runningLabel(ToolKind kind) {
    switch (kind) {
      case ToolKind.read:
        return 'reading';
      case ToolKind.search:
        return 'searching';
      case ToolKind.edit:
        return 'editing';
      case ToolKind.execute:
        return 'running';
      case ToolKind.fetch:
        return 'fetching';
      case ToolKind.delete:
        return 'deleting';
      case ToolKind.move:
        return 'moving';
      case ToolKind.think:
        return 'thinking';
      case ToolKind.switchMode:
        return 'switching';
      case ToolKind.other:
        return 'running';
    }
  }

  IconData _iconForKind(ToolKind kind) {
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

  String _headerText(ToolKind kind) {
    final t = widget.tool.title ?? widget.tool.name;
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

  static const _previewStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Builds the preview content widget for the header row.
  /// For file-path based tools (read/edit/delete), uses Finder-style
  /// middle truncation: keeps the last two path segments visible.
  Widget _buildPreviewContent(ToolKind kind) {
    final text = _bodyPreview(kind) ?? _headerText(kind);
    final style = _previewStyle.copyWith(color: AppTheme.textPrimary);

    const pathKinds = {ToolKind.read, ToolKind.edit, ToolKind.delete};
    if (pathKinds.contains(kind)) {
      final segments = text.split('/');
      if (segments.length > 3) {
        final display = '\u2026/${segments.sublist(segments.length - 2).join('/')}';
        return Text(display, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
      }
    }

    return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  String? _bodyPreview(ToolKind kind) {
    final input = widget.tool.input;
    if (input == null) return null;

    switch (kind) {
      case ToolKind.execute:
        final desc = input['description'];
        if (desc is String && desc.isNotEmpty) return desc;
        final cmd = input['command'];
        if (cmd is String && cmd.isNotEmpty) return cmd;
        return null;
      case ToolKind.read:
        final fp = input['file_path'];
        if (fp is String && fp.isNotEmpty) return fp;
        return null;
      case ToolKind.edit:
        final fp = input['file_path'];
        if (fp is String && fp.isNotEmpty) return fp;
        return null;
      case ToolKind.search:
        final pattern = input['pattern'];
        if (pattern is String && pattern.isNotEmpty) return pattern;
        final fp = input['file_path'];
        if (fp is String && fp.isNotEmpty) return fp;
        return null;
      case ToolKind.fetch:
        final url = input['url'];
        if (url is String && url.isNotEmpty) return url;
        return null;
      case ToolKind.delete:
        final fp = input['file_path'] ?? input['path'];
        if (fp is String && fp.isNotEmpty) return fp;
        return null;
      case ToolKind.move:
        final src = input['source'] ?? input['path'];
        if (src is String && src.isNotEmpty) return src;
        return null;
      case ToolKind.think:
        return null;
      case ToolKind.switchMode:
        final mode = input['mode'];
        if (mode is String && mode.isNotEmpty) return mode;
        return null;
      case ToolKind.other:
        for (final v in input.values) {
          if (v is String && v.isNotEmpty) return v;
        }
        return null;
    }
  }
}
