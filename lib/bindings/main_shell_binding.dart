import 'package:get/get.dart';

import '../ui/main/active_tab_viewmodel.dart';
import '../ui/main/history_tab_viewmodel.dart';
import '../ui/main/main_shell_viewmodel.dart';
import '../ui/main/settings_tab_viewmodel.dart';

class MainShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(MainShellViewModel());
    Get.lazyPut(() => ActiveTabViewModel());
    Get.lazyPut(() => HistoryTabViewModel());
    Get.lazyPut(() => SettingsTabViewModel());
  }
}
