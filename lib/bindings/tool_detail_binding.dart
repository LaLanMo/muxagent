import 'package:get/get.dart';

import '../ui/tool_detail/tool_detail_viewmodel.dart';

class ToolDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ToolDetailViewModel>(() => ToolDetailViewModel());
  }
}
