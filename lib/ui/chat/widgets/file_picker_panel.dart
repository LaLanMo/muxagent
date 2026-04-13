import 'package:flutter/material.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/fonts.dart';
import '../../../config/theme.dart';
import '../../../domain/fs_entry.dart';

class FilePickerPanel extends StatelessWidget {
  final List<FsEntry> entries;
  final bool isSearchMode;
  final bool isLoading;
  final ValueChanged<FsEntry> onTap;
  final ValueChanged<FsEntry>? onDrillDown;

  const FilePickerPanel({
    super.key,
    required this.entries,
    required this.isSearchMode,
    required this.isLoading,
    required this.onTap,
    this.onDrillDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.borderStrong)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 16,
            color: Colors.black.withValues(alpha: 0.1),
          ),
        ],
      ),
      child: isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            )
          : entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No files found',
                  style: AppTypography.sans(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _FileEntryTile(
                  entry: entry,
                  isSearchMode: isSearchMode,
                  onTap: () => onTap(entry),
                  onDrillDown:
                      entry.isDir && !isSearchMode && onDrillDown != null
                      ? () => onDrillDown!(entry)
                      : null,
                );
              },
            ),
    );
  }
}

class _FileEntryTile extends StatelessWidget {
  final FsEntry entry;
  final bool isSearchMode;
  final VoidCallback onTap;
  final VoidCallback? onDrillDown;

  const _FileEntryTile({
    required this.entry,
    required this.isSearchMode,
    required this.onTap,
    this.onDrillDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(
              entry.isDir ? LucideIcons.folder : LucideIcons.file,
              size: 16,
              color: entry.isDir ? AppTheme.accent : AppTheme.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSearchMode ? entry.path : entry.name,
                style: AppFonts.code(
                  fontSize: 13,
                  fontWeight: entry.isDir ? FontWeight.w500 : FontWeight.w400,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onDrillDown != null)
              GestureDetector(
                onTap: onDrillDown,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
