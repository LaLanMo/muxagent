import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../utils/diff_utils.dart';

const _kRemovedBg = Color(0x12EF4444);
const _kAddedBg = Color(0x1222C55E);
const _kRemovedAccent = AppTheme.diffRemoved;
const _kAddedAccent = AppTheme.diffAdded;
const _kSeparatorColor = AppTheme.border;
const _kRemovedTokenBg = Color(0x30EF4444);
const _kAddedTokenBg = Color(0x3022C55E);

/// Renders a unified line diff between [oldString] and [newString] inline.
///
/// [maxCollapsedLines] controls how many diff lines are visible before the
/// "show more" button appears. [contextLines] controls how many unchanged
/// lines surround each changed block.
///
/// [dark] switches to a dark code-block style (used in ToolDetailScreen).
class EditDiffView extends StatefulWidget {
  final String oldString;
  final String newString;
  final int maxCollapsedLines;
  final int contextLines;
  final bool dark;

  const EditDiffView({
    super.key,
    required this.oldString,
    required this.newString,
    this.maxCollapsedLines = 8,
    this.contextLines = 2,
    this.dark = false,
  });

  @override
  State<EditDiffView> createState() => _EditDiffViewState();
}

class _EditDiffViewState extends State<EditDiffView> {
  late DiffResult _diff;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _diff = computeLineDiff(
      widget.oldString,
      widget.newString,
      contextLines: widget.contextLines,
    );
  }

  @override
  void didUpdateWidget(covariant EditDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldString != widget.oldString ||
        oldWidget.newString != widget.newString ||
        oldWidget.contextLines != widget.contextLines) {
      setState(() {
        _diff = computeLineDiff(
          widget.oldString,
          widget.newString,
          contextLines: widget.contextLines,
        );
      });
    }
  }

  // Build a flat list of segments: DiffLine or null (hunk separator)
  List<Object?> get _segments {
    final segs = <Object?>[];
    for (int h = 0; h < _diff.hunks.length; h++) {
      if (h > 0) segs.add(null); // separator
      segs.addAll(_diff.hunks[h].lines);
    }
    return segs;
  }

  @override
  Widget build(BuildContext context) {
    final segs = _segments;
    final totalLineCount = segs.whereType<DiffLine>().length;
    final limited =
        !_expanded && totalLineCount > widget.maxCollapsedLines;
    final hiddenCount =
        limited ? totalLineCount - widget.maxCollapsedLines : 0;

    // Build the visible segment list, respecting the collapsed limit
    final visible = <Object?>[];
    if (limited) {
      int linesAdded = 0;
      for (final seg in segs) {
        if (linesAdded >= widget.maxCollapsedLines) break;
        visible.add(seg);
        if (seg is DiffLine) linesAdded++;
      }
    } else {
      visible.addAll(segs);
    }

    final bgColor =
        widget.dark ? AppTheme.codeBg : const Color(0xFFF8F9FA);
    final contextTextColor =
        widget.dark ? const Color(0xFFB0B0B0) : AppTheme.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: widget.dark
                ? null
                : Border.all(color: _kSeparatorColor, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < visible.length; i++)
                    visible[i] == null
                        ? _buildSeparatorRow(contextTextColor)
                        : _buildLineRow(
                            visible[i] as DiffLine,
                            contextTextColor,
                          ),
                ],
              ),
            ),
          ),
        ),

        // Stats + expand button
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              _buildStats(),
              const Spacer(),
              if (hiddenCount > 0)
                GestureDetector(
                  onTap: () => setState(() => _expanded = true),
                  child: Text(
                    'Show $hiddenCount more line${hiddenCount == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.textSecondary,
                    ),
                  ),
                ),
              if (_expanded && totalLineCount > widget.maxCollapsedLines)
                GestureDetector(
                  onTap: () => setState(() => _expanded = false),
                  child: Text(
                    'Collapse',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineRow(DiffLine line, Color contextTextColor) {
    Color? bgColor;
    Color prefixColor;
    String prefix;

    switch (line.type) {
      case DiffLineType.removed:
        bgColor = _kRemovedBg;
        prefixColor = _kRemovedAccent;
        prefix = '-';
      case DiffLineType.added:
        bgColor = _kAddedBg;
        prefixColor = _kAddedAccent;
        prefix = '+';
      case DiffLineType.context:
        bgColor = null;
        prefixColor = contextTextColor;
        prefix = ' ';
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed-width prefix column
          SizedBox(
            width: 12,
            child: Text(
              prefix,
              style: _codeStyle(color: prefixColor),
            ),
          ),
          const SizedBox(width: 6),
          // Content — use RichText for inline tokens, Text otherwise
          line.tokens != null
              ? _buildRichContent(line.tokens!, contextTextColor)
              : Text(
                  line.content,
                  style: _codeStyle(color: contextTextColor),
                  softWrap: false,
                ),
        ],
      ),
    );
  }

  Widget _buildRichContent(List<DiffToken> tokens, Color baseColor) {
    final spans = tokens.map((t) {
      Color? bg;
      if (t.removed) bg = _kRemovedTokenBg;
      if (t.added) bg = _kAddedTokenBg;
      return TextSpan(
        text: t.value,
        style: _codeStyle(color: baseColor).copyWith(
          backgroundColor: bg,
        ),
      );
    }).toList();

    return Text.rich(
      TextSpan(children: spans),
      softWrap: false,
    );
  }

  Widget _buildSeparatorRow(Color textColor) {
    return Container(
      color: const Color(0xFFF0F0F0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Text(
        '···',
        style: _codeStyle(color: textColor, fontSize: 11),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_diff.additions > 0)
          Text(
            '+${_diff.additions}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kAddedAccent,
            ),
          ),
        if (_diff.additions > 0 && _diff.deletions > 0)
          const SizedBox(width: 6),
        if (_diff.deletions > 0)
          Text(
            '-${_diff.deletions}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kRemovedAccent,
            ),
          ),
      ],
    );
  }

  TextStyle _codeStyle({Color? color, double fontSize = 12}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.6,
    );
  }
}
