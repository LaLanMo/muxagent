import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/models/auth_request.dart';
import '../../routing/routes.dart';

class ScanViewModel extends GetxController {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  final isProcessing = false.obs;
  final errorMessage = RxnString();

  @override
  void onClose() {
    scannerController.dispose();
    super.onClose();
  }

  void onDetect(BarcodeCapture capture) {
    if (isProcessing.value) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final value = barcode.rawValue;

    if (value == null || !value.startsWith('muxagent://auth')) {
      return;
    }

    isProcessing.value = true;
    _processQrCode(value);
  }

  void _processQrCode(String qrValue) {
    try {
      final authRequest = AuthRequest.fromQrUrl(qrValue);

      if (!authRequest.isValid) {
        errorMessage.value = 'Invalid QR code format';
        isProcessing.value = false;
        return;
      }

      // Navigate to auth approval screen
      Get.offNamed(Routes.auth, arguments: authRequest);
    } catch (e) {
      errorMessage.value = 'Failed to parse QR code: $e';
      isProcessing.value = false;
    }
  }

  void clearError() {
    errorMessage.value = null;
  }

  void toggleFlash() {
    scannerController.toggleTorch();
  }

  void switchCamera() {
    scannerController.switchCamera();
  }
}
