import 'package:get/get.dart';

import '../ui/welcome/welcome_viewmodel.dart';

class WelcomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WelcomeViewModel>(() => WelcomeViewModel());
  }
}
