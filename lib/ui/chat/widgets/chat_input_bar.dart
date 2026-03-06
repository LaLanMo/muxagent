import 'dart:math';
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
                  child: isRecording
                      ? const _RecordingWaveform()
                      : Container(
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
      height: 74,
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
          color: AppTheme.inputFill,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(LucideIcons.mic, color: AppTheme.textSecondary, size: 18),
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
        decoration: const BoxDecoration(
          color: AppTheme.recordRed,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
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

/// Animated waveform shown in place of the text field while recording.
class _RecordingWaveform extends StatefulWidget {
  const _RecordingWaveform();

  @override
  State<_RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<_RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  static const _barCount = 14;
  static const _minH = 6.0;
  static const _maxH = 24.0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pulsing red recording dot
              Opacity(
                opacity: 0.4 + 0.6 * ((sin(_anim.value * 2 * pi) + 1) / 2),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.recordRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Animated waveform bars
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_barCount, (i) {
                    final phase = i * 0.45;
                    final t =
                        (sin(_anim.value * 2 * pi + phase) + 1) / 2;
                    final h = _minH + (_maxH - _minH) * t;
                    return Padding(
                      padding: EdgeInsets.only(left: i > 0 ? 6 : 0),
                      child: Container(
                        width: 3,
                        height: h,
                        decoration: BoxDecoration(
                          color: AppTheme.waveformGreen,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
