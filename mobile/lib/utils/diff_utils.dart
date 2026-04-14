import 'dart:math';

import 'package:diff_match_patch/diff_match_patch.dart';

enum DiffLineType { added, removed, context }

/// A single token within a diff line for inline word-level highlighting.
class DiffToken {
  final String value;
  final bool added;
  final bool removed;

  const DiffToken(this.value, {this.added = false, this.removed = false});
}

/// A single line in a diff result.
class DiffLine {
  final DiffLineType type;
  final String content;

  /// Word-level tokens for inline highlighting. Null when not applicable
  /// (e.g. context lines, or when no adjacent pair was found).
  List<DiffToken>? tokens;

  DiffLine(this.type, this.content, {this.tokens});
}

/// A contiguous block of changed lines with surrounding context.
class DiffHunk {
  final List<DiffLine> lines;
  const DiffHunk(this.lines);
}

class DiffResult {
  final List<DiffHunk> hunks;
  final int additions;
  final int deletions;

  const DiffResult(
    this.hunks, {
    required this.additions,
    required this.deletions,
  });

  /// Total number of lines across all hunks (excluding hunk separators).
  int get totalLineCount => hunks.fold(0, (s, h) => s + h.lines.length);
}

/// Computes a unified line-level diff between [oldText] and [newText].
///
/// [contextLines] controls how many unchanged lines appear around each change.
/// Adjacent changed/added lines that look similar get word-level inline tokens.
DiffResult computeLineDiff(
  String oldText,
  String newText, {
  int contextLines = 2,
}) {
  final oldLines = _splitLines(trimIdent(oldText));
  final newLines = _splitLines(trimIdent(newText));

  final m = oldLines.length;
  final n = newLines.length;

  // LCS DP table
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      if (oldLines[i - 1] == newLines[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
  }

  // Backtrack iteratively to produce diff lines in reverse, then flip
  final reversed = <DiffLine>[];
  int additions = 0;
  int deletions = 0;
  int i = m, j = n;

  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1]) {
      reversed.add(DiffLine(DiffLineType.context, oldLines[i - 1]));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      reversed.add(DiffLine(DiffLineType.added, newLines[j - 1]));
      additions++;
      j--;
    } else {
      reversed.add(DiffLine(DiffLineType.removed, oldLines[i - 1]));
      deletions++;
      i--;
    }
  }

  final rawLines = reversed.reversed.toList();

  // Inline word-level highlighting for adjacent removed/added pairs
  _addInlineTokens(rawLines);

  final hunks = _createHunks(rawLines, contextLines);

  return DiffResult(hunks, additions: additions, deletions: deletions);
}

/// Removes the minimum common leading indentation from all non-blank lines.
String trimIdent(String text) {
  if (text.isEmpty) return text;
  final lines = text.split('\n');

  int? minIndent;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    var indent = 0;
    for (final codeUnit in line.codeUnits) {
      if (codeUnit == 0x20 || codeUnit == 0x09) {
        indent++;
      } else {
        break;
      }
    }
    if (minIndent == null || indent < minIndent) minIndent = indent;
  }

  if (minIndent == null || minIndent == 0) return text;

  return lines
      .map((l) => l.length >= minIndent! ? l.substring(minIndent) : l)
      .join('\n');
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

void _addInlineTokens(List<DiffLine> lines) {
  final dmp = DiffMatchPatch();

  for (int idx = 0; idx < lines.length - 1; idx++) {
    if (lines[idx].type == DiffLineType.removed &&
        lines[idx + 1].type == DiffLineType.added) {
      final diffs = dmp.diff(lines[idx].content, lines[idx + 1].content);
      dmp.diffCleanupSemantic(diffs);

      final removedTokens = <DiffToken>[];
      final addedTokens = <DiffToken>[];

      for (final d in diffs) {
        if (d.operation == DIFF_EQUAL) {
          removedTokens.add(DiffToken(d.text));
          addedTokens.add(DiffToken(d.text));
        } else if (d.operation == DIFF_DELETE) {
          removedTokens.add(DiffToken(d.text, removed: true));
        } else if (d.operation == DIFF_INSERT) {
          addedTokens.add(DiffToken(d.text, added: true));
        }
      }

      lines[idx].tokens = removedTokens;
      lines[idx + 1].tokens = addedTokens;
      idx++; // skip the paired added line
    }
  }
}

List<DiffHunk> _createHunks(List<DiffLine> lines, int contextLines) {
  if (lines.isEmpty) return [];

  final changedIdxs = <int>[
    for (int i = 0; i < lines.length; i++)
      if (lines[i].type != DiffLineType.context) i,
  ];

  if (changedIdxs.isEmpty) return [];

  final hunks = <DiffHunk>[];
  int start = max(0, changedIdxs.first - contextLines);
  int end = min(lines.length - 1, changedIdxs.first + contextLines);

  for (int k = 1; k < changedIdxs.length; k++) {
    final ci = changedIdxs[k];
    final newStart = max(0, ci - contextLines);
    if (newStart <= end + 1) {
      end = min(lines.length - 1, ci + contextLines);
    } else {
      hunks.add(DiffHunk(List.unmodifiable(lines.sublist(start, end + 1))));
      start = newStart;
      end = min(lines.length - 1, ci + contextLines);
    }
  }

  hunks.add(DiffHunk(List.unmodifiable(lines.sublist(start, end + 1))));
  return hunks;
}

List<String> _splitLines(String text) {
  if (text.isEmpty) return [];
  final parts = text.split('\n');
  // Drop trailing empty line produced by a terminal newline
  if (parts.isNotEmpty && parts.last.isEmpty) {
    return parts.sublist(0, parts.length - 1);
  }
  return parts;
}
