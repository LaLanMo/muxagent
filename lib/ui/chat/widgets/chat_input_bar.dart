import 'dart:typed_data';

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
  final VoidCallback onAttach;
  final List<Uint8List> imagePreviews;
  final void Function(int index) onRemoveImage;
  final bool showMic;
  final bool isRecording;
  final bool isTranscribing;
  final VoidCallback? onMicStart;
  final VoidCallback? onMicStop;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.sessionStatus,
    required this.onSend,
    required this.onCancel,
    required this.onAttach,
    required this.imagePreviews,
    required this.onRemoveImage,
    this.showMic = false,
    this.isRecording = false,
    this.isTranscribing = false,
    this.onMicStart,
    this.onMicStop,
  });

  bool get _isRunning => sessionStatus == SessionStatus.running;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.border),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePreviews.isNotEmpty) ...[
              _buildPreviewStrip(),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!_isRunning)
                  GestureDetector(
                    onTap: onAttach,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        LucideIcons.image,
                        size: 22,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
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
                          color: AppTheme.textMuted,
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
                _isRunning
                    ? _buildCancelButton()
                    : isTranscribing
                        ? _buildTranscribingIndicator()
                        : isRecording
                            ? _buildStopRecordingButton()
                            : _buildSendOrMicButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStrip() {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imagePreviews.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == imagePreviews.length) {
            return _buildAddMoreButton();
          }
          return _buildPreviewThumbnail(index);
        },
      ),
    );
  }

  Widget _buildPreviewThumbnail(int index) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              imagePreviews[index],
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => onRemoveImage(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.close, color: Colors.white, size: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMoreButton() {
    return GestureDetector(
      onTap: onAttach,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Icon(LucideIcons.plus, color: AppTheme.textSecondary, size: 22),
        ),
      ),
    );
  }

  Widget _buildSendOrMicButton() {
    // Use ValueListenableBuilder to react to text changes for mic/send swap
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final hasImages = imagePreviews.isNotEmpty;

        if (!hasText && !hasImages && showMic) {
          return _buildMicButton();
        }
        return _buildSendButton();
      },
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

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: onMicStart,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(LucideIcons.mic, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildStopRecordingButton() {
    return GestureDetector(
      onTap: onMicStop,
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

  Widget _buildTranscribingIndicator() {
    return const SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.textSecondary,
          ),
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
