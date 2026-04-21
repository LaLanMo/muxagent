import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../domain/enums.dart';
import '../../../i18n/tx.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final SessionStatus sessionStatus;
  final bool composerEnabled;
  final bool canCancel;
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
    this.composerEnabled = true,
    this.canCancel = true,
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
      color: AppTheme.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePreviews.isNotEmpty) _buildPreviewStrip(),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.borderStrong)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!_isRunning && composerEnabled)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildControl(
                        icon: LucideIcons.paperclip,
                        background: AppTheme.surfaceMuted,
                        foreground: AppTheme.textTertiary,
                        onTap: onAttach,
                      ),
                    ),
                  Expanded(
                    child: isRecording
                        ? const _RecordingWaveform()
                        : Container(
                            constraints: const BoxConstraints(minHeight: 36),
                            color: AppTheme.surfaceMuted,
                            child: TextField(
                              controller: controller,
                              enabled: !_isRunning && composerEnabled,
                              textAlignVertical: TextAlignVertical.center,
                              autocorrect: false,
                              smartDashesType: SmartDashesType.disabled,
                              smartQuotesType: SmartQuotesType.disabled,
                              keyboardType: TextInputType.multiline,
                              decoration: InputDecoration(
                                hintText: Tx.chatTypeMessage.tr,
                                filled: false,
                                hintStyle: AppTypography.sans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.textMuted,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 14,
                                ),
                                isDense: true,
                              ),
                              style: AppTypography.sans(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.textPrimary,
                              ),
                              textInputAction: TextInputAction.newline,
                              minLines: 1,
                              maxLines: 4,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  _isRunning && canCancel
                      ? _buildCancelButton()
                      : _isRunning
                      ? _buildDisabledSendButton()
                      : isTranscribing
                      ? _buildTranscribingIndicator()
                      : isRecording
                      ? _buildStopRecordingButton()
                      : _buildSendOrMicButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStrip() {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderStrong)),
      ),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.surfaceMuted,
            border: Border.all(color: AppTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(imagePreviews[index], fit: BoxFit.cover),
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
                color: AppTheme.errorText,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Center(
                child: Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMoreButton() {
    return GestureDetector(
      onTap: onAttach,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          border: Border.all(color: AppTheme.borderStrong),
        ),
        child: const Center(
          child: Icon(LucideIcons.plus, color: AppTheme.textTertiary, size: 20),
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

        if (!composerEnabled) {
          return _buildDisabledSendButton();
        }
        if (!hasText && !hasImages && showMic) {
          return _buildMicButton();
        }
        return _buildSendButton();
      },
    );
  }

  Widget _buildDisabledSendButton() {
    return _buildControl(
      icon: LucideIcons.lock,
      background: AppTheme.surfaceMuted,
      foreground: AppTheme.textMuted,
    );
  }

  Widget _buildSendButton() {
    return Semantics(
      button: true,
      label: Tx.chatSendMessage.tr,
      child: _buildControl(
        icon: LucideIcons.arrowUp,
        background: AppTheme.primary,
        foreground: AppTheme.surface,
        onTap: onSend,
      ),
    );
  }

  Widget _buildMicButton() {
    return _buildControl(
      icon: LucideIcons.mic,
      background: AppTheme.surfaceMuted,
      foreground: AppTheme.textTertiary,
      onTap: onMicStart,
    );
  }

  Widget _buildStopRecordingButton() {
    return GestureDetector(
      onTap: onMicStop,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: AppTheme.recordRed),
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
    return _buildControl(
      icon: Icons.stop_rounded,
      background: AppTheme.recordRed,
      foreground: Colors.white,
      onTap: onCancel,
    );
  }

  Widget _buildControl({
    required IconData icon,
    required Color background,
    required Color foreground,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        color: background,
        child: Center(child: Icon(icon, color: foreground, size: 18)),
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
      decoration: BoxDecoration(color: AppTheme.surfaceMuted),
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
                    final t = (sin(_anim.value * 2 * pi + phase) + 1) / 2;
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
