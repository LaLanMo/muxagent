import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../config/theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/message.dart';
import 'code_block.dart';

class ChatMessageBubble extends StatelessWidget {
  final List<MessagePart> parts;
  final bool isUser;
  final bool isStreaming;

  const ChatMessageBubble({
    super.key,
    required this.parts,
    required this.isUser,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return _buildUserBubble();
    }
    // Agent: render text parts only (images not expected from agent)
    final text = parts
        .where((p) => p.type == PartType.text && p.text != null)
        .map((p) => p.text!)
        .join();
    if (text.isEmpty) return const SizedBox.shrink();
    return _buildAgentText(text);
  }

  Widget _buildUserBubble() {
    final imageParts =
        parts.where((p) => p.type == PartType.media && p.media != null).toList();
    final text = parts
        .where((p) => p.type == PartType.text && p.text != null)
        .map((p) => p.text!)
        .join();

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (imageParts.isNotEmpty) ...[
              _buildImageRow(imageParts),
              if (text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (text.isNotEmpty)
              SelectableText(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageRow(List<MessagePart> imageParts) {
    if (imageParts.length == 1) {
      return _buildImageWidget(imageParts.first.media!);
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: imageParts
          .map((p) => SizedBox(
                width: 120,
                height: 120,
                child: _buildImageWidget(p.media!),
              ))
          .toList(),
    );
  }

  Widget _buildImageWidget(MediaPart media) {
    if (media.base64 != null && media.base64!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          base64Decode(media.base64!),
          fit: BoxFit.cover,
        ),
      );
    }
    // Fallback placeholder for loaded sessions
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: AppTheme.textTertiary, size: 24),
      ),
    );
  }

  Widget _buildAgentText(String text) {
    final markdown = GptMarkdown(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme.textPrimary,
        height: 1.5,
      ),
      codeBuilder: (context, name, code, closed) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: CodeBlock(text: code),
      ),
    );
    // Skip SelectionArea while streaming — Flutter's SelectableRegion crashes
    // with a RangeError when selectables change mid-notification dispatch.
    return SizedBox(
      width: double.infinity,
      child: isStreaming ? markdown : SelectionArea(child: markdown),
    );
  }
}
