import 'package:get/get.dart';

import '../ui/session_settings/session_settings_viewmodel.dart';

class SessionSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SessionSettingsViewModel>(() => SessionSettingsViewModel());
  }
}
