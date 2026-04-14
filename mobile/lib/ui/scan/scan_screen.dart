import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../config/theme.dart';
import 'scan_viewmodel.dart';

class ScanScreen extends GetView<ScanViewModel> {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        title: Text(
          'Scan QR Code',
          style: AppTypography.sans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: controller.toggleFlash,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: controller.switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller.scannerController,
            onDetect: controller.onDetect,
          ),
          // Scanning frame overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Point camera at the QR code displayed on your CLI',
                textAlign: TextAlign.center,
                style: AppTypography.sans(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: const [
                    Shadow(blurRadius: 4, color: Colors.black),
                  ],
                ),
              ),
            ),
          ),
          // Error message
          Obx(() {
            final error = controller.errorMessage.value;
            if (error == null) return const SizedBox.shrink();

            return Positioned(
              bottom: 160,
              left: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        error,
                        style: AppTypography.sans(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: controller.clearError,
                    ),
                  ],
                ),
              ),
            );
          }),
          // Processing indicator
          Obx(() {
            if (!controller.isProcessing.value) return const SizedBox.shrink();

            return Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            );
          }),
        ],
      ),
    );
  }
}
