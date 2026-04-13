import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import '../common/ui_effect_listener.dart';
import 'stt_settings_viewmodel.dart';

class SttSettingsPage extends GetView<SttSettingsViewModel> {
  const SttSettingsPage({super.key});

  static const _fieldFill = Color(0xFFF0EAE5);

  @override
  Widget build(BuildContext context) {
    return UiEffectListener(
      effects: controller.uiEffect,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      label: 'ENDPOINT URL',
                      field: _buildFieldShell(
                        controller: controller.endpointController,
                        hint: 'https://api.example.com/v1',
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                      ),
                      helper:
                          'OpenAI-compatible /v1/audio/transcriptions endpoint',
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      label: 'API KEY',
                      field: _buildFieldShell(
                        controller: controller.apiKeyController,
                        hint: 'sk-...',
                        obscure: true,
                        monoText: true,
                        textInputAction: TextInputAction.next,
                        trailing: const Icon(
                          LucideIcons.eyeOff,
                          size: 18,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      helperBadge: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.lock,
                            size: 13,
                            color: AppTheme.successText,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Stored securely in device Keychain',
                            style: AppTypography.sans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.successText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      label: 'MODEL NAME',
                      field: _buildFieldShell(
                        controller: controller.modelController,
                        hint: 'whisper-1',
                        textInputAction: TextInputAction.done,
                      ),
                      helper: 'The STT model identifier used for transcription',
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: AppTheme.borderStrong,
                    ),
                    const SizedBox(height: 24),
                    Obx(_buildTestSection),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildPrimaryButton(
                label: 'Save',
                onTap: controller.saveConfig,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.borderStrong)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(
                    LucideIcons.chevronLeft,
                    size: 20,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Speech to Text',
                style: AppTypography.sans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String label,
    required Widget field,
    String? helper,
    Widget? helperBadge,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.mono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        field,
        if (helper != null) ...[
          const SizedBox(height: 8),
          Text(
            helper,
            style: AppTypography.sans(
              fontSize: 12,
              color: AppTheme.textMetadata,
            ),
          ),
        ],
        if (helperBadge != null) ...[const SizedBox(height: 8), helperBadge],
      ],
    );
  }

  Widget _buildFieldShell({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    bool monoText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _fieldFill,
        border: Border.all(color: AppTheme.chipBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              textCapitalization: TextCapitalization.none,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              scrollPadding: const EdgeInsets.only(bottom: 120),
              style: (monoText ? AppTypography.mono : AppTypography.sans)(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: (monoText ? AppTypography.mono : AppTypography.sans)(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _buildTestSection() {
    final hasConfig = controller.canTest.value;
    final testing = controller.isTesting.value;
    final recording = controller.isRecording.value;
    final result = controller.testResult.value;
    final error = controller.testError.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEST',
          style: AppTypography.mono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasConfig
              ? 'Record a short clip to verify your configuration.'
              : 'Enter your API key above to enable testing',
          style: AppTypography.sans(fontSize: 12, color: AppTheme.textMetadata),
        ),
        const SizedBox(height: 12),
        if (!hasConfig)
          _buildLockedState()
        else if (testing)
          _buildTestingState()
        else if (recording)
          _buildSecondaryAction(
            label: 'Stop Recording',
            icon: LucideIcons.square,
            iconColor: AppTheme.errorText,
            textColor: AppTheme.errorText,
            borderColor: AppTheme.errorText,
            fill: AppTheme.errorBg,
            onTap: controller.stopTestRecording,
          )
        else
          _buildSecondaryAction(
            label: 'Record Test Clip',
            icon: LucideIcons.mic,
            onTap: controller.startTestRecording,
          ),
        if (result != null) ...[
          const SizedBox(height: 12),
          _buildResultPanel(
            fill: AppTheme.successBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.text.isEmpty ? '(empty transcription)' : result.text,
                  style: AppTypography.sans(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.duration.inMilliseconds}ms',
                  style: AppTypography.mono(
                    fontSize: 12,
                    color: AppTheme.textMetadata,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          _buildResultPanel(
            fill: AppTheme.errorBg,
            child: Text(
              error,
              style: AppTypography.sans(
                fontSize: 13,
                color: AppTheme.errorText,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLockedState() {
    return Container(
      width: double.infinity,
      height: 80,
      color: _fieldFill,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.lock, size: 20, color: AppTheme.textMuted),
          const SizedBox(height: 8),
          Text(
            'Add API key to enable',
            style: AppTypography.sans(
              fontSize: 12,
              color: AppTheme.textMetadata,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestingState() {
    return Container(
      width: double.infinity,
      height: 80,
      color: AppTheme.surfaceMuted,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Transcribing...',
            style: AppTypography.sans(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppTheme.textTertiary,
    Color textColor = AppTheme.textPrimary,
    Color borderColor = AppTheme.borderStrong,
    Color fill = AppTheme.surface,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.sans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPanel({required Color fill, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: fill,
      child: child,
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required Future<void> Function() onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 48,
        color: AppTheme.primary,
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.sans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.surface,
          ),
        ),
      ),
    );
  }
}
