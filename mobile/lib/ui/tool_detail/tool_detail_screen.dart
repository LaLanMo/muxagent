import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/fonts.dart';
import '../../config/theme.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/tool_activity.dart';
import '../../i18n/tx.dart';
import '../../ui/chat/widgets/edit_diff_view.dart';
import 'tool_detail_viewmodel.dart';

class ToolDetailScreen extends GetView<ToolDetailViewModel> {
  const ToolDetailScreen({super.key});

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.version.value;
      final tool = controller.tool;
      final isSubagent = controller.childTools.isNotEmpty;

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Column(
          children: [
            _buildHeader(tool, isSubagent),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildBody(tool, isSubagent),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBody(ToolActivity tool, bool isSubagent) {
    final sections = <Widget>[];

    void pushSection(String label, Widget child) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 20));
      }
      sections.add(_buildSectionLabel(label));
      sections.add(const SizedBox(height: 8));
      sections.add(child);
    }

    if (tool.input != null) {
      pushSection(Tx.toolInput.tr, _buildInputSection(tool));
    }

    if (_hasOutput(tool)) {
      pushSection(Tx.toolOutput.tr, _buildOutputSection(tool));
    }

    if (!isSubagent && tool.locations != null && tool.locations!.isNotEmpty) {
      pushSection(Tx.toolLocations.tr, _buildLocationsSection(tool.locations!));
    }

    if (!isSubagent && tool.diffs != null && tool.diffs!.isNotEmpty) {
      pushSection(Tx.toolDiffs.tr, _buildDiffsSection(tool.diffs!));
    }

    if (isSubagent && controller.childTools.isNotEmpty) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 20));
      }
      sections.add(_buildChildToolsSection(controller.childTools));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _buildHeader(ToolActivity tool, bool isSubagent) {
    final primary = isSubagent ? Tx.toolTask.tr : _toolPrimaryTitle(tool);
    final secondary = isSubagent
        ? _subagentSubtitle(tool)
        : _toolKindSubtitle(tool.effectiveKind);

    return Container(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.borderStrong)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: Get.back,
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      LucideIcons.chevronLeft,
                      size: 20,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary,
                      style: isSubagent
                          ? AppTypography.sans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              height: 1,
                            )
                          : AppTypography.mono(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                              height: 1,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      style: AppTypography.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textTertiary,
                        height: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection(ToolActivity tool) {
    return _CodeShell(
      header: Text(
        _inputHeaderLabel(tool),
        style: AppTypography.mono(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppTheme.textMetadata,
        ),
      ),
      body: _inputBody(tool),
      bodyFontSize: 13,
    );
  }

  Widget _buildOutputSection(ToolActivity tool) {
    final body = _outputBody(tool);
    final isErrorBody =
        tool.output?.trim().isNotEmpty != true &&
        tool.error?.trim().isNotEmpty == true;
    final (statusColor, statusLabel) = switch (tool.status) {
      ToolStatus.failed => (AppTheme.errorText, Tx.statusFailed.tr),
      ToolStatus.pending => (AppTheme.textTertiary, Tx.statusPending.tr),
      ToolStatus.inProgress => (const Color(0xFF4CB782), Tx.statusRunning.tr),
      ToolStatus.completed => (const Color(0xFF4CB782), Tx.statusSuccess.tr),
    };

    return _CodeShell(
      header: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusLabel,
            style: AppTypography.mono(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: statusColor,
            ),
          ),
        ],
      ),
      body: body,
      bodyFontSize: 12,
      bodyColor: isErrorBody ? AppTheme.errorBg : AppTheme.codeBg,
      bodyTextColor: isErrorBody ? AppTheme.textPrimary : AppTheme.codeText,
    );
  }

  Widget _buildLocationsSection(List<ToolLocation> locations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: locations.map((loc) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 14,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatPath(
                    loc.line != null ? '${loc.path}:${loc.line}' : loc.path,
                  ),
                  style: AppTypography.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDiffsSection(List<ToolDiff> diffs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: diffs.map((diff) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatPath(diff.path),
                style: AppTypography.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 6),
              EditDiffView(
                oldString: diff.oldText ?? '',
                newString: diff.newText,
                contextLines: 3,
                maxCollapsedLines: 999,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChildToolsSection(List<ToolActivity> children) {
    final count = children.length;
    const summaryColor = Color(0xFF7C3AED);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.layers, size: 16, color: summaryColor),
            const SizedBox(width: 8),
            Text(
              Tx.toolCallsCompleted(count),
              style: AppTypography.sans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: AppTheme.borderStrong, height: 1),
        const SizedBox(height: 20),
        _buildSectionLabel(Tx.toolToolCalls.tr),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children.map((child) => _buildChildToolRow(child)).toList(),
        ),
      ],
    );
  }

  Widget _buildChildToolRow(ToolActivity child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            _iconForKind(child.effectiveKind),
            size: 14,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _toolRowText(child),
              style: AppTypography.mono(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.mono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: AppTheme.textTertiary,
      ),
    );
  }

  String _toolPrimaryTitle(ToolActivity tool) {
    final name = tool.name.trim();
    if (name.isNotEmpty) {
      return name;
    }
    final title = tool.title?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return Tx.toolGenericTool.tr;
  }

  String _subagentSubtitle(ToolActivity tool) {
    final title = tool.title?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    final preview = _toolPreview(tool);
    if (preview.isNotEmpty) {
      return preview;
    }
    return Tx.toolSubagentTrace.tr;
  }

  String _toolKindSubtitle(ToolKind kind) {
    switch (kind) {
      case ToolKind.execute:
        return Tx.toolToolExecution.tr;
      case ToolKind.read:
        return Tx.toolFileRead.tr;
      case ToolKind.edit:
        return Tx.toolFileEdit.tr;
      case ToolKind.search:
        return Tx.toolSearch.tr;
      case ToolKind.fetch:
        return Tx.toolFetch.tr;
      case ToolKind.delete:
        return Tx.toolDelete.tr;
      case ToolKind.move:
        return Tx.toolMove.tr;
      case ToolKind.think:
        return Tx.toolReasoning.tr;
      case ToolKind.switchMode:
        return Tx.toolModeChange.tr;
      case ToolKind.other:
        return Tx.toolToolDetail.tr;
    }
  }

  String _inputHeaderLabel(ToolActivity tool) {
    final input = tool.input;
    if (input?.command != null) {
      return Tx.toolCommand.tr;
    }
    if (input?.filePath != null || input?.edit?.filePath != null) {
      return Tx.toolPath.tr;
    }
    if (input?.pattern != null) {
      return Tx.toolPattern.tr;
    }
    if (input?.url != null) {
      return Tx.toolUrl.tr;
    }
    if (input?.mode != null) {
      return Tx.toolMode.tr;
    }
    return Tx.toolGenericInput.tr;
  }

  String _inputBody(ToolActivity tool) {
    final input = tool.input!;
    if (input.command?.display?.trim().isNotEmpty == true) {
      return input.command!.display!.trim();
    }

    if (input.filePath?.trim().isNotEmpty == true) {
      return _formatPath(input.filePath!.trim());
    }

    if (input.edit?.filePath?.trim().isNotEmpty == true) {
      return _formatPath(input.edit!.filePath!.trim());
    }

    if (input.sourcePath?.trim().isNotEmpty == true ||
        input.targetPath?.trim().isNotEmpty == true) {
      final source = input.sourcePath?.trim();
      final target = input.targetPath?.trim();
      if (source != null &&
          source.isNotEmpty &&
          target != null &&
          target.isNotEmpty) {
        return '${_formatPath(source)} -> ${_formatPath(target)}';
      }
      return _formatPath((source ?? target)!.trim());
    }

    if (input.pattern?.trim().isNotEmpty == true) {
      return input.pattern!.trim();
    }

    if (input.url?.trim().isNotEmpty == true) {
      return input.url!.trim();
    }

    if (input.mode?.trim().isNotEmpty == true) {
      return input.mode!.trim();
    }

    if (input.description?.trim().isNotEmpty == true) {
      return input.description!.trim();
    }

    final rawInputJson = input.rawInputJson;
    if (rawInputJson != null && rawInputJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawInputJson);
        if (decoded is Map<String, dynamic>) {
          final command = decoded['command'];
          if (command is String && command.trim().isNotEmpty) {
            return command.trim();
          }
          final filePath = decoded['filePath'];
          if (filePath is String && filePath.trim().isNotEmpty) {
            return _formatPath(filePath.trim());
          }
        }
        return _jsonEncoder.convert(decoded);
      } catch (_) {
        return rawInputJson;
      }
    }

    return _jsonEncoder.convert({
      if (input.description != null) 'description': input.description,
      if (input.command != null)
        'command': {
          if (input.command!.argv.isNotEmpty) 'argv': input.command!.argv,
          if (input.command!.display != null) 'display': input.command!.display,
        },
      if (input.filePath != null) 'filePath': input.filePath,
      if (input.sourcePath != null) 'sourcePath': input.sourcePath,
      if (input.targetPath != null) 'targetPath': input.targetPath,
      if (input.pattern != null) 'pattern': input.pattern,
      if (input.url != null) 'url': input.url,
      if (input.mode != null) 'mode': input.mode,
      if (input.edit != null)
        'edit': {
          if (input.edit!.filePath != null) 'filePath': input.edit!.filePath,
          if (input.edit!.oldString != null) 'oldString': input.edit!.oldString,
          if (input.edit!.newString != null) 'newString': input.edit!.newString,
        },
    });
  }

  String _toolRowText(ToolActivity tool) {
    if (tool.title?.trim().isNotEmpty == true) {
      return tool.title!.trim();
    }
    final preview = _toolPreview(tool);
    if (preview.isNotEmpty) {
      return preview;
    }
    return _toolPrimaryTitle(tool);
  }

  bool _hasOutput(ToolActivity tool) {
    final output = tool.output?.trim();
    if (output != null && output.isNotEmpty) {
      return true;
    }
    final error = tool.error?.trim();
    return error != null && error.isNotEmpty;
  }

  String _outputBody(ToolActivity tool) {
    final output = tool.output?.trim();
    if (output != null && output.isNotEmpty) {
      return output;
    }
    return tool.error!.trim();
  }

  String _toolPreview(ToolActivity tool) {
    final input = tool.input;
    if (input == null) {
      return _toolPrimaryTitle(tool);
    }

    final raw = switch (tool.effectiveKind) {
      ToolKind.execute => input.description ?? input.command?.display,
      ToolKind.read => input.filePath,
      ToolKind.edit =>
        tool.diffs?.firstOrNull?.path ?? input.edit?.filePath ?? input.filePath,
      ToolKind.search => input.pattern ?? input.filePath,
      ToolKind.fetch => input.url,
      ToolKind.delete => input.filePath,
      ToolKind.move => input.sourcePath ?? input.targetPath,
      ToolKind.think => input.description,
      ToolKind.switchMode => input.mode,
      ToolKind.other =>
        input.description ??
            input.command?.display ??
            input.filePath ??
            input.sourcePath ??
            input.targetPath ??
            input.pattern ??
            input.url ??
            input.mode,
    };

    final normalized = (raw ?? '').trim();
    if (normalized.isEmpty) {
      return _toolPrimaryTitle(tool);
    }
    return _formatPath(normalized);
  }

  String _formatPath(String value) {
    final normalized = value
        .replaceFirst(RegExp(r'^/(Users|home)/[^/]+'), '~')
        .trim();
    final segments = normalized.split('/');
    if (segments.length > 5) {
      return '\u2026/${segments.sublist(segments.length - 3).join('/')}';
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
}

class _CodeShell extends StatelessWidget {
  final Widget header;
  final String body;
  final double bodyFontSize;
  final Color bodyColor;
  final Color bodyTextColor;

  const _CodeShell({
    required this.header,
    required this.body,
    required this.bodyFontSize,
    this.bodyColor = AppTheme.codeBg,
    this.bodyTextColor = AppTheme.codeText,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: AppTheme.codeHeaderBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: header,
          ),
          Container(
            width: double.infinity,
            color: bodyColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                body,
                style: AppFonts.code(
                  fontSize: bodyFontSize,
                  fontWeight: FontWeight.w400,
                  color: bodyTextColor,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
