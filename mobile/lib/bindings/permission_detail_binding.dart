import 'package:get/get.dart';

import '../data/repositories/ws_session_repository.dart';
import '../ui/permission_detail/permission_detail_viewmodel.dart';

class PermissionDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PermissionDetailViewModel>(
      () => PermissionDetailViewModel(
        wsRepo: Get.find<WsSessionRepository>(),
      ),
    );
  }
}
