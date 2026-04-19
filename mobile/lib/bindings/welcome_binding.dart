import 'package:get/get.dart';

import '../data/models/auth_request.dart';
import '../ui/welcome/welcome_viewmodel.dart';

class WelcomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WelcomeViewModel>(
      () => WelcomeViewModel(pairingLinkParser: Get.find<PairingLinkParser>()),
    );
  }
}
