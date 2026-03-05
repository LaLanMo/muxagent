import 'package:get/get.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/paired_machine_repository.dart';
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
    Get.lazyPut<CryptoService>(() => CryptoService(), fenix: true);
    Get.lazyPut<RelayService>(() => RelayService(), fenix: true);
    Get.lazyPut<PairedMachineRepository>(
      () => PairedMachineRepository(),
      fenix: true,
    );
    Get.lazyPut<TokenService>(
      () => TokenService(crypto: Get.find<CryptoService>()),
      fenix: true,
    );
    Get.lazyPut<SessionManager>(
      () => SessionManager(rpcTimeout: const Duration(minutes: 5)),
      fenix: true,
    );
    Get.lazyPut<RelayWsClient>(
      () => RelayWsClient(
        crypto: Get.find<CryptoService>(),
        tokens: Get.find<TokenService>(),
        sessions: Get.find<SessionManager>(),
      ),
      fenix: true,
    );
    Get.lazyPut<WsSessionRepository>(
      () => WsSessionRepository(
        relay: Get.find<RelayWsClient>(),
        sessions: Get.find<SessionManager>(),
      ),
      fenix: true,
    );

    // Repositories
    Get.lazyPut<AuthRepository>(
      () => AuthRepository(
        api: Get.find<RelayService>(),
        crypto: Get.find<CryptoService>(),
        machines: Get.find<PairedMachineRepository>(),
      ),
      fenix: true,
    );
    Get.lazyPut<EventRepository>(
      () => EventRepository(wsRepo: Get.find<WsSessionRepository>()),
      fenix: true,
    );
    Get.lazyPut<PushNotificationService>(
      () => PushNotificationService(
        relay: Get.find<RelayService>(),
        tokens: Get.find<TokenService>(),
        crypto: Get.find<CryptoService>(),
        machines: Get.find<PairedMachineRepository>(),
      ),
      fenix: true,
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
