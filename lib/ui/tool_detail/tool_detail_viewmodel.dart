import 'package:get/get.dart';

import '../../domain/tool_activity.dart';
import '../chat/chat_viewmodel.dart';

class ToolDetailViewModel extends GetxController {
  late final ToolActivity tool;
  late final List<ToolActivity> childTools;

  /// Reactive version number — bumped whenever the chat viewmodel refreshes
  /// messages (which also mutates tool fields in-place).
  final version = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>;
    tool = args['tool'] as ToolActivity;
    childTools = (args['childTools'] as List<ToolActivity>?) ?? const [];

    // Listen to the chat viewmodel's message list; each refresh may have
    // mutated our tool's status/output/error in-place.
    final chatVm = Get.find<ChatViewModel>();
    ever(chatVm.messages, (_) => version.value++);
  }
}
