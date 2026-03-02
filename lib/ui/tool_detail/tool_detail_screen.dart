import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../ui/chat/widgets/code_block.dart';
import '../../ui/common/status_indicator.dart';
import 'tool_detail_viewmodel.dart';

class ToolDetailScreen extends GetView<ToolDetailViewModel> {
  const ToolDetailScreen({super.key});

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  @override
  Widget build(BuildContext context) {
    final tool = controller.tool;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Get.back(),
        ),
        title: Text(
          tool.name,
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

            // Input
            if (tool.input != null) ...[
              _buildSectionLabel('INPUT'),
              const SizedBox(height: 8),
              CodeBlock(text: _jsonEncoder.convert(tool.input)),
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
          ],
        ),
      ),
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
