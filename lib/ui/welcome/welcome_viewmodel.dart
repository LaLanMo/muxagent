import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/auth_request.dart';
import '../../routing/routes.dart';
import '../../utils/app_toast.dart';

const welcomeInstallScriptUrl =
    'https://raw.githubusercontent.com/LaLanMo/muxagent-cli/main/install.sh';
const welcomeInstallCommand = 'curl -fsSL $welcomeInstallScriptUrl | sh';

class WelcomeViewModel extends GetxController {
  final urlController = TextEditingController();
  final urlError = RxnString();

  void dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void onClose() {
    urlController.dispose();
    super.onClose();
  }

  void onScanPressed() {
    dismissKeyboard();
    Get.toNamed(Routes.scan);
  }

  void onManualConnect() {
    dismissKeyboard();
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

  void onGithubPressed() {
    dismissKeyboard();
    launchUrl(
      Uri.parse('https://github.com/LaLanMo/muxagent-cli'),
      mode: LaunchMode.externalApplication,
    );
  }

  void onCopyCommand() {
    dismissKeyboard();
    Clipboard.setData(const ClipboardData(text: welcomeInstallCommand));
    AppToast.show('Installation command copied');
  }
}
