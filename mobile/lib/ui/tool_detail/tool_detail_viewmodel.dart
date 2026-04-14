import 'package:get/get.dart';

import '../../domain/message.dart';
import '../../domain/tool_activity.dart';

class ToolDetailViewModel extends GetxController {
  final RxList<Message> _messages;

  ToolDetailViewModel({required RxList<Message> messages})
      : _messages = messages;

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

    // Listen to message list changes; each refresh may have
    // mutated our tool's status/output/error in-place.
    ever(_messages, (_) => version.value++);
  }
}
