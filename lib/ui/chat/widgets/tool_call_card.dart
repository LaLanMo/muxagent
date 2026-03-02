import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/tool_activity.dart';
import '../../../routing/routes.dart';

class ToolCallCard extends StatefulWidget {
  final ToolActivity tool;

  const ToolCallCard({super.key, required this.tool});

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
    final iconColor =
        _isFailed ? AppTheme.failedRed : AppTheme.textSecondary;
    final label = _kindLabel(kind);
    final labelColor = _isFailed
        ? AppTheme.failedRed
        : _isRunning
            ? AppTheme.successText
            : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: () => Get.toNamed(Routes.toolDetail, arguments: widget.tool),
      child: AnimatedBuilder(
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
                      alpha: _isRunning ? _breathAnimation.value : 1.0),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: child,
          );
        },
        child: Row(
          children: [
            Icon(
              _iconForKind(kind),
              size: 16,
              color: iconColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _bodyPreview(kind) ?? _headerText(kind),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(ToolKind kind) {
    if (_isFailed) return 'FAILED';
    if (_isRunning) {
      final dots = '.' * _dotCount;
      switch (kind) {
        case ToolKind.read:
          return 'reading$dots';
        case ToolKind.search:
          return 'searching$dots';
        case ToolKind.edit:
          return 'editing$dots';
        case ToolKind.execute:
          return 'running$dots';
        case ToolKind.fetch:
          return 'fetching$dots';
        case ToolKind.other:
          return 'running$dots';
      }
    }
    switch (kind) {
      case ToolKind.read:
        return 'READ';
      case ToolKind.search:
        return 'SEARCH';
      case ToolKind.edit:
        return 'EDIT';
      case ToolKind.execute:
        return 'RUN';
      case ToolKind.fetch:
        return 'FETCH';
      case ToolKind.other:
        return 'TOOL';
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
      case ToolKind.other:
        return 'Tool';
    }
  }

  String? _bodyPreview(ToolKind kind) {
    final input = widget.tool.input;
    if (input == null) return null;

    switch (kind) {
      case ToolKind.execute:
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
      case ToolKind.other:
        for (final v in input.values) {
          if (v is String && v.isNotEmpty) return v;
        }
        return null;
    }
  }
}
