import 'package:get/get.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/paired_machine_repository.dart';
import '../data/repositories/replay_cursor_repository.dart';
import '../data/repositories/reconnect_recovery_coordinator.dart';
import '../data/repositories/runtime_preference_repository.dart';
import '../data/repositories/session_chat_cache_repository.dart';
import '../data/repositories/session_manager.dart';
import '../data/repositories/stt_repository.dart';
import '../data/repositories/ws_session_repository.dart';
import '../data/services/api/relay_service.dart';
import '../data/services/api/stt_service.dart';
import '../data/services/local/crypto_service.dart';
import '../data/services/push/push_notification_service.dart';
import '../data/services/ws/relay_ws_client.dart';
import '../data/services/ws/token_service.dart';
import '../usecases/transcribe_audio.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.put<CryptoService>(CryptoService(), permanent: true);
    Get.put<RelayService>(RelayService(), permanent: true);
    Get.put<PairedMachineRepository>(
      PairedMachineRepository(),
      permanent: true,
    );
    Get.put<RuntimePreferenceRepository>(
      RuntimePreferenceRepository(),
      permanent: true,
    );
    Get.put<SessionChatCacheRepository>(
      SessionChatCacheRepository(),
      permanent: true,
    );
    Get.put<ReplayCursorRepository>(ReplayCursorRepository(), permanent: true);
    Get.put<TokenService>(
      TokenService(crypto: Get.find<CryptoService>()),
      permanent: true,
    );
    Get.put<SessionManager>(
      SessionManager(rpcTimeout: const Duration(minutes: 5)),
      permanent: true,
    );
    Get.put<RelayWsClient>(
      RelayWsClient(
        crypto: Get.find<CryptoService>(),
        tokens: Get.find<TokenService>(),
        sessions: Get.find<SessionManager>(),
      ),
      permanent: true,
    );
    Get.put<WsSessionRepository>(
      WsSessionRepository(
        relay: Get.find<RelayWsClient>(),
        sessions: Get.find<SessionManager>(),
      ),
      permanent: true,
    );

    // Repositories
    Get.put<AuthRepository>(
      AuthRepository(
        api: Get.find<RelayService>(),
        crypto: Get.find<CryptoService>(),
        machines: Get.find<PairedMachineRepository>(),
      ),
      permanent: true,
    );
    Get.put<EventRepository>(
      EventRepository(
        wsRepo: Get.find<WsSessionRepository>(),
        replayCursors: Get.find<ReplayCursorRepository>(),
        chatCacheRepo: Get.find<SessionChatCacheRepository>(),
      ),
      permanent: true,
    );
    Get.put<ReconnectRecoveryCoordinator>(
      ReconnectRecoveryCoordinator(
        machines: Get.find<PairedMachineRepository>(),
        wsRepo: Get.find<WsSessionRepository>(),
        eventRepo: Get.find<EventRepository>(),
        chatCacheRepo: Get.find<SessionChatCacheRepository>(),
      ),
      permanent: true,
    );
    Get.put<PushNotificationService>(
      PushNotificationService(
        relay: Get.find<RelayService>(),
        tokens: Get.find<TokenService>(),
        crypto: Get.find<CryptoService>(),
        machines: Get.find<PairedMachineRepository>(),
      ),
      permanent: true,
    );

    // Speech-to-text
    Get.lazyPut<SttService>(() => SttService(), fenix: true);
    Get.lazyPut<SttRepository>(
      () => SttRepository(service: Get.find<SttService>()),
      fenix: true,
    );
    Get.lazyPut<TranscribeAudioUseCase>(
      () => TranscribeAudioUseCase(repo: Get.find<SttRepository>()),
      fenix: true,
    );
  }
}
