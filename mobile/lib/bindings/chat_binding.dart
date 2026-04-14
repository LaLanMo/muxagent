import 'package:get/get.dart';

import '../data/repositories/event_repository.dart';
import '../data/repositories/reconnect_recovery_coordinator.dart';
import '../data/repositories/session_chat_cache_repository.dart';
import '../data/repositories/ws_session_repository.dart';
import '../ui/chat/chat_viewmodel.dart';
import '../usecases/transcribe_audio.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.find<SessionChatCacheRepository>();
    Get.lazyPut<ChatViewModel>(
      () => ChatViewModel(
        eventRepo: Get.find<EventRepository>(),
        recovery: Get.find<ReconnectRecoveryCoordinator>(),
        chatCacheRepo: Get.find<SessionChatCacheRepository>(),
        wsRepo: Get.find<WsSessionRepository>(),
        transcribe: Get.find<TranscribeAudioUseCase>(),
      ),
    );
  }
}
