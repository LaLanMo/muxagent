import 'package:get/get.dart';

import '../data/repositories/event_repository.dart';
import '../data/repositories/ws_session_repository.dart';
import '../ui/chat/chat_viewmodel.dart';
import '../usecases/transcribe_audio.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChatViewModel>(() => ChatViewModel(
          eventRepo: Get.find<EventRepository>(),
          wsRepo: Get.find<WsSessionRepository>(),
          transcribe: Get.find<TranscribeAudioUseCase>(),
        ));
  }
}
