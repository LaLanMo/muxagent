import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../../config/fonts.dart';
import '../../../config/theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import '../../../domain/run_diff_summary.dart';
import '../../../domain/tool_activity.dart';
import '../../../routing/routes.dart';

const _kAddedText = Color(0xFF4CB782);
const _kRemovedText = Color(0xFFD46F61);

class RunDiffSummaryCard extends StatelessWidget {
  final RunDiffSummary summary;

  const RunDiffSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Text(
                  '${summary.fileCount} file${summary.fileCount == 1 ? '' : 's'} changed',
                  style: AppTypography.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${summary.totalAdditions}',
                  style: AppFonts.code(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: _kAddedText,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '-${summary.totalDeletions}',
                  style: AppFonts.code(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: _kRemovedText,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < summary.files.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openFileDiff(summary.files[i]),
              child: Container(
                decoration: BoxDecoration(
                  border: i == 0
                      ? const Border(top: BorderSide(color: AppTheme.border))
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: i < summary.files.length - 1
                        ? const Border(
                            bottom: BorderSide(color: AppTheme.border),
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _displayPath(summary.files[i].path),
                          style: AppFonts.code(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${summary.files[i].additions}',
                        style: AppFonts.code(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: _kAddedText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '-${summary.files[i].deletions}',
                        style: AppFonts.code(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: _kRemovedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static void _openFileDiff(FileDiffStat file) {
    final tool = ToolActivity(
      id: 'run-diff-${file.path.hashCode}',
      name: 'Edit',
      kind: ToolKind.edit.value,
      status: ToolStatus.completed,
      title: _displayPath(file.path),
      diffs: [
        ToolDiff(
          path: file.path,
          oldText: file.oldText,
          newText: file.newText,
        ),
      ],
    );
    Get.toNamed(
      Routes.toolDetail,
      arguments: {'tool': tool, 'childTools': const <ToolActivity>[]},
    );
  }

  static String _displayPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final homeMatch = RegExp(r'^/(Users|home)/[^/]+').firstMatch(trimmed);
    if (homeMatch == null) {
      return trimmed;
    }
    return trimmed.replaceRange(0, homeMatch.group(0)!.length, '~');
  }
}
