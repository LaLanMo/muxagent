import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/tool_activity.dart';
import '../../ui/chat/widgets/code_block.dart';
import '../../ui/chat/widgets/edit_diff_view.dart';
import '../../ui/chat/widgets/tool_call_card.dart';
import '../../ui/common/status_indicator.dart';
import 'tool_detail_viewmodel.dart';

class ToolDetailScreen extends GetView<ToolDetailViewModel> {
  const ToolDetailScreen({super.key});

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Touch version to subscribe to chat state updates.
      controller.version.value;
      final tool = controller.tool;

      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Get.back(),
          ),
          title: Text(
            tool.title ?? tool.name,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: StatusIndicator.toolStatus(tool.status),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              if (tool.title != null && tool.title!.isNotEmpty) ...[
                Text(
                  tool.title!,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Locations
              if (tool.locations != null && tool.locations!.isNotEmpty) ...[
                _buildSectionLabel('LOCATIONS'),
                const SizedBox(height: 8),
                _buildLocationsSection(tool.locations!),
                const SizedBox(height: 20),
              ],

              // Input: show diff for edit tools, raw JSON for everything else
              if (tool.input != null) ...[
                _buildSectionLabel('INPUT'),
                const SizedBox(height: 8),
                _buildInputSection(tool),
                const SizedBox(height: 20),
              ],

              // Diffs from ACP content[]
              if (tool.diffs != null && tool.diffs!.isNotEmpty) ...[
                _buildSectionLabel('DIFFS'),
                const SizedBox(height: 8),
                _buildDiffsSection(tool.diffs!),
                const SizedBox(height: 20),
              ],

              // Output
              if (tool.output != null && tool.output!.isNotEmpty) ...[
                _buildSectionLabel('OUTPUT'),
                const SizedBox(height: 8),
                CodeBlock(text: tool.output!),
                const SizedBox(height: 20),
              ],

              // Error
              if (tool.error != null && tool.error!.isNotEmpty) ...[
                _buildSectionLabel('ERROR'),
                const SizedBox(height: 8),
                CodeBlock(
                  text: tool.error!,
                  backgroundColor: const Color(0xFF2A1A10),
                  textColor: AppTheme.warning,
                ),
                const SizedBox(height: 20),
              ],

              // Child tool calls
              if (controller.childTools.isNotEmpty) ...[
                _buildChildToolsSection(controller.childTools),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildInputSection(ToolActivity tool) {
    final isEdit = tool.effectiveKind == ToolKind.edit;
    final input = tool.input!;
    final oldStr = input.edit?.oldString;
    final newStr = input.edit?.newString;

    if (isEdit && oldStr is String && newStr is String) {
      return EditDiffView(
        oldString: oldStr,
        newString: newStr,
        contextLines: 3,
        maxCollapsedLines: 999, // always show all in detail screen
      );
    }

    final rawInputJson = input.rawInputJson;
    if (rawInputJson != null && rawInputJson.isNotEmpty) {
      try {
        return CodeBlock(text: _jsonEncoder.convert(jsonDecode(rawInputJson)));
      } catch (_) {
        return CodeBlock(text: rawInputJson);
      }
    }

    return CodeBlock(
      text: _jsonEncoder.convert({
        if (input.description != null) 'description': input.description,
        if (input.command != null)
          'command': {
            if (input.command!.argv.isNotEmpty) 'argv': input.command!.argv,
            if (input.command!.display != null)
              'display': input.command!.display,
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
            if (input.edit!.oldString != null)
              'oldString': input.edit!.oldString,
            if (input.edit!.newString != null)
              'newString': input.edit!.newString,
          },
      }),
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
              Icon(LucideIcons.mapPin, size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  loc.line != null ? '${loc.path}:${loc.line}' : loc.path,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              diff.path,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            EditDiffView(
              oldString: diff.oldText ?? '',
              newString: diff.newText,
              contextLines: 3,
              maxCollapsedLines: 999,
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildChildToolsSection(List<ToolActivity> children) {
    final count = children.length;
    final noun = count == 1 ? 'tool call' : 'tool calls';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        Row(
          children: [
            const Icon(
              LucideIcons.layers,
              size: 16,
              color: AppTheme.subagentAccent,
            ),
            const SizedBox(width: 8),
            Text(
              '$count $noun completed',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: AppTheme.border, height: 1),
        const SizedBox(height: 16),

        // Section label
        _buildSectionLabel('TOOL CALLS'),
        const SizedBox(height: 12),

        // Child tool cards
        ...children.map(
          (child) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ToolCallCard(tool: child),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
