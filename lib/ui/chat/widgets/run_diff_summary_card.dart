import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/fonts.dart';
import '../../../config/theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import '../../../domain/run_diff_summary.dart';
import '../../../domain/tool_activity.dart';
import '../../../routing/routes.dart';

const _kGreenText = Color(0xFF2E7D32);
const _kGreenBg = Color(0xFFE8F5E9);
const _kRedText = Color(0xFFCC4444);
const _kRedBg = Color(0xFFFFEBEE);

class RunDiffSummaryCard extends StatelessWidget {
  final RunDiffSummary summary;

  const RunDiffSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Text(
                  '${summary.fileCount} file${summary.fileCount == 1 ? '' : 's'} changed',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: '+${summary.totalAdditions}',
                  textColor: _kGreenText,
                  bgColor: _kGreenBg,
                ),
                const SizedBox(width: 6),
                _StatPill(
                  label: '-${summary.totalDeletions}',
                  textColor: _kRedText,
                  bgColor: _kRedBg,
                ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),

          // File list
          for (final file in summary.files)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openFileDiff(file),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _displayPath(file.path),
                        style: AppFonts.code(
                          fontSize: 11,
                          color: const Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${file.additions}',
                      style: AppFonts.code(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kGreenText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '-${file.deletions}',
                      style: AppFonts.code(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kRedText,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: AppTheme.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static void _openFileDiff(FileDiffStat file) {
    // Construct a synthetic ToolActivity so we can reuse ToolDetailScreen.
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

  /// Show only the filename from a full path for brevity.
  static String _displayPath(String path) {
    final idx = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(idx + 1) : path;
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;

  const _StatPill({
    required this.label,
    required this.textColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppFonts.code(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
