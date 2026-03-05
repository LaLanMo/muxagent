import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import 'welcome_viewmodel.dart';

class WelcomeScreen extends GetView<WelcomeViewModel> {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Logo Area: vertical, gap 24, center, padding [0, 40]
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon circle: 80x80, cornerRadius 40, fill #1D1D1F
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      alignment: Alignment.center,
                      // Terminal icon: lucide "terminal" 36x36 #FFFFFF
                      child: const Icon(LucideIcons.terminal,
                          size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    // Title: "MuxAgent", Inter 32 bold #1D1D1F, textAlign center
                    Text(
                      'MuxAgent',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Subtitle: Inter 16 normal #6B6F76, lineHeight 1.5, center
                    Text(
                      'Control your coding agents\nfrom anywhere',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Area: vertical, gap 16, padding [0, 40, 60, 40]
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
              child: Column(
                children: [
                  // Primary Button: cornerRadius 8, fill #1D1D1F, height 52, center, gap 8
                  GestureDetector(
                    onTap: controller.onScanPressed,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // QR icon 20x20 #FFFFFF
                          const Icon(LucideIcons.qrCode,
                              size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          // Text: "Scan QR Code", Inter 15 w600 #FFFFFF
                          Text(
                            'Scan QR Code',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Hint text: Inter 13 normal #808690, lineHeight 1.5, center
                  Text(
                    'Run muxagent daemon on your machine\nthen scan the QR code to pair',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: AppTheme.textTertiary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Divider row: gap 12, padding [8, 0]
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        // Line: 1px height, fill #F0F0F0, fill_container width
                        const Expanded(
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF0F0F0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // "or": Inter 13 normal #808690
                        Text(
                          'or',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF0F0F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // URL Input: cornerRadius 8, fill #EDEEF1, height 48, padding [0, 14], gap 8
                  Obx(() => Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.inputFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Link icon 18x18 #808690
                        const Icon(LucideIcons.link,
                            size: 18, color: AppTheme.textTertiary),
                        const SizedBox(width: 8),
                        // Placeholder: "Enter server URL...", Inter 14 normal #C8CBD0
                        Expanded(
                          child: TextField(
                            controller: controller.urlController,
                            onChanged: (_) => controller.clearUrlError(),
                            onSubmitted: (_) => controller.onManualConnect(),
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.url,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: AppTheme.textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: 'Enter server URL...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: AppTheme.textMuted,
                              ),
                              errorText: controller.urlError.value,
                              errorStyle: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.errorText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
