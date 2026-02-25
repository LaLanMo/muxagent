import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !_isRunning,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                ),
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => onSend(),
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
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
        onPressed: onSend,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildCancelButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 20),
        onPressed: onCancel,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
