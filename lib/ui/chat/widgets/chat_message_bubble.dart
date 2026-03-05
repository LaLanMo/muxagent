import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../config/theme.dart';
import 'code_block.dart';

class ChatMessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isStreaming;

  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return _buildUserBubble();
    }
    return _buildAgentText();
  }

  Widget _buildUserBubble() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildAgentText() {
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
