import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../common/ui_effect_listener.dart';
import 'stt_settings_viewmodel.dart';

class SttSettingsPage extends GetView<SttSettingsViewModel> {
  const SttSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return UiEffectListener(
      effects: controller.uiEffect,
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle
                    Text(
                      'Full transcription endpoint URL',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Endpoint
                    _buildLabel('Endpoint'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: controller.endpointController,
                      hint: 'https://api.openai.com/v1/audio/transcriptions',
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),

                    // API Key
                    _buildLabel('API Key'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: controller.apiKeyController,
                      hint: 'sk-...',
                      obscure: true,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.lock,
                          size: 11,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stored securely in device keychain',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Model
                    _buildLabel('Model'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: controller.modelController,
                      hint: 'whisper-1',
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: controller.saveConfig,
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Test section
                    _buildLabel('Test'),
                    const SizedBox(height: 6),
                    Text(
                      'Record a short clip to verify your configuration.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Obx(() => _buildTestButton()),
                    const SizedBox(height: 12),
                    Obx(() => _buildTestResult()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Get.back(),
              child: const Icon(
                LucideIcons.chevronLeft,
                size: 22,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Speech to Text',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: false,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: AppTheme.textTertiary,
        ),
      ),
    );
  }

  Widget _buildTestButton() {
    if (controller.isTesting.value) {
      return Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Transcribing...',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      );
    }

    if (controller.isRecording.value) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: controller.stopTestRecording,
          icon: Icon(LucideIcons.square, size: 16, color: Colors.red.shade600),
          label: Text(
            'Stop Recording',
            style: TextStyle(color: Colors.red.shade600),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: controller.startTestRecording,
        icon: const Icon(LucideIcons.mic, size: 16),
        label: const Text('Record Test Clip'),
      ),
    );
  }

  Widget _buildTestResult() {
    final result = controller.testResult.value;
    final error = controller.testError.value;

    if (result != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.successBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.text.isEmpty ? '(empty transcription)' : result.text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${result.duration.inMilliseconds}ms',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.errorBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          error,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.errorText,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
