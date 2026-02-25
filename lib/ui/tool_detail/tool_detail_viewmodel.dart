import 'package:get/get.dart';

import '../../domain/tool_activity.dart';

class ToolDetailViewModel extends GetxController {
  late final ToolActivity tool;

  @override
  void onInit() {
    super.onInit();
    tool = Get.arguments as ToolActivity;
  }
}
