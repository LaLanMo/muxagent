import 'package:get/get.dart';

import '../ui/session_list/session_list_viewmodel.dart';

class SessionListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SessionListViewModel>(() => SessionListViewModel());
  }
}
