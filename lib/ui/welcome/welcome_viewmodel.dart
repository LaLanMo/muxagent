import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/auth_request.dart';
import '../../routing/routes.dart';

class WelcomeViewModel extends GetxController {
  final urlController = TextEditingController();
  final urlError = RxnString();

  @override
  void onClose() {
    urlController.dispose();
    super.onClose();
  }

  void onScanPressed() {
    Get.toNamed(Routes.scan);
  }

  void onManualConnect() {
    final url = urlController.text.trim();
    if (url.isEmpty) {
      urlError.value = 'Please enter a URL';
      return;
    }

    if (!url.toLowerCase().startsWith('muxagent://auth')) {
      urlError.value = 'Invalid URL format. Must start with muxagent://auth';
      return;
    }

    final authRequest = AuthRequest.fromQrUrl(url);
    if (!authRequest.isValid) {
      urlError.value = 'Invalid URL: missing id or relay parameter';
      return;
    }

    urlError.value = null;
    urlController.clear();
    Get.toNamed(Routes.auth, arguments: authRequest);
  }

  void clearUrlError() {
    urlError.value = null;
  }
}
