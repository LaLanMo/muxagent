import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../domain/enums.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final SessionStatus sessionStatus;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.sessionStatus,
    required this.onSend,
    required this.onCancel,
  });

  bool get _isRunning => sessionStatus == SessionStatus.running;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(
          top: BorderSide(color: AppTheme.border),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.inputFill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: controller,
                  enabled: !_isRunning,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFC8CBD0),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    isDense: true,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                  ),
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _isRunning ? _buildCancelButton() : _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: onSend,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(LucideIcons.arrowUp, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: onCancel,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.stop_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
