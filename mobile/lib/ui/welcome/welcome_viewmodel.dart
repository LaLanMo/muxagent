import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/auth_request.dart';
import '../../routing/routes.dart';
import '../../utils/app_toast.dart';

const welcomeInstallScriptUrl =
    'https://raw.githubusercontent.com/LaLanMo/muxagent/main/install.sh';
const welcomeInstallCommand = 'curl -fsSL $welcomeInstallScriptUrl | sh';

class WelcomeViewModel extends GetxController {
  WelcomeViewModel({required PairingLinkParser pairingLinkParser})
    : _pairingLinkParser = pairingLinkParser;

  final PairingLinkParser _pairingLinkParser;
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
      urlError.value = _errorMessageFor(PairingLinkParseFailure.emptyInput);
      return;
    }

    final result = _pairingLinkParser.parseText(url);
    if (!result.isSuccess) {
      urlError.value = _errorMessageFor(result.failure!);
      return;
    }

    urlError.value = null;
    urlController.clear();
    Get.toNamed(Routes.auth, arguments: result.authRequest);
  }

  void clearUrlError() {
    urlError.value = null;
  }

  void onGithubPressed() {
    dismissKeyboard();
    launchUrl(
      Uri.parse('https://github.com/LaLanMo/muxagent'),
      mode: LaunchMode.externalApplication,
    );
  }

  void onCopyCommand() {
    dismissKeyboard();
    Clipboard.setData(const ClipboardData(text: welcomeInstallCommand));
    AppToast.show('Installation command copied');
  }

  String _errorMessageFor(PairingLinkParseFailure failure) {
    switch (failure) {
      case PairingLinkParseFailure.emptyInput:
        return 'Please enter a URL';
      case PairingLinkParseFailure.invalidScheme:
      case PairingLinkParseFailure.invalidTarget:
        return 'Invalid URL format. Must start with muxagent://auth';
      case PairingLinkParseFailure.missingId:
      case PairingLinkParseFailure.missingRelay:
        return 'Invalid URL: missing id or relay parameter';
      case PairingLinkParseFailure.malformedUri:
        return 'Invalid URL format';
    }
  }
}
