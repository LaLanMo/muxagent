import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/fonts.dart';
import '../../../config/theme.dart';
import '../../../domain/tool_activity.dart';
import '../../../routing/routes.dart';
import '../../common/status_indicator.dart';

class ToolCallCard extends StatelessWidget {
  final ToolActivity tool;

  const ToolCallCard({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.toolDetail, arguments: tool),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.codeBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: tool name + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    tool.name,
                    style: AppFonts.codeLabel(color: AppTheme.activeGreen),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusIndicator.toolStatus(tool.status),
              ],
            ),

            // Title
            if (tool.title != null && tool.title!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                tool.title!,
                style: AppFonts.codeSmall(color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Command preview from input
            if (_commandPreview != null) ...[
              const SizedBox(height: 6),
              Text(
                _commandPreview!,
                style: AppFonts.codeSmall(color: AppTheme.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Output preview
            if (tool.output != null && tool.output!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _truncatedOutput(tool.output!, 2),
                style: AppFonts.codeSmall(color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? get _commandPreview {
    final input = tool.input;
    if (input == null) return null;
    final command = input['command'];
    if (command is String && command.isNotEmpty) return command;
    return null;
  }

  String _truncatedOutput(String output, int maxLines) {
    final lines = output.split('\n');
    if (lines.length <= maxLines) return output;
    return lines.take(maxLines).join('\n');
  }
}
