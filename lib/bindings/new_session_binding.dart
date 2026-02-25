import 'package:get/get.dart';

import '../ui/new_session/new_session_viewmodel.dart';

class NewSessionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NewSessionViewModel>(() => NewSessionViewModel());
  }
}
