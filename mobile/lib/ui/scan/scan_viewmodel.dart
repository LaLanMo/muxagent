import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/models/auth_request.dart';
import '../../i18n/tx.dart';
import '../../routing/routes.dart';

class ScanViewModel extends GetxController {
  ScanViewModel({required PairingLinkParser pairingLinkParser})
    : _pairingLinkParser = pairingLinkParser;

  final PairingLinkParser _pairingLinkParser;
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
      final result = _pairingLinkParser.parseText(qrValue);
      if (!result.isSuccess) {
        errorMessage.value = Tx.scanInvalidQr.tr;
        isProcessing.value = false;
        return;
      }

      // Navigate to auth approval screen
      Get.offNamed(Routes.auth, arguments: result.authRequest);
    } catch (e) {
      errorMessage.value = Tx.scanParseFailedWith(e);
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
