import 'package:get/get.dart';

import '../ui/chat/chat_viewmodel.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChatViewModel>(() => ChatViewModel());
  }
}
