import 'package:get/get.dart';

import '../data/repositories/event_repository.dart';
import '../data/repositories/paired_machine_repository.dart';
import '../data/repositories/reconnect_recovery_coordinator.dart';
import '../data/repositories/ws_session_repository.dart';
import '../data/services/local/crypto_service.dart';
import '../ui/main/active_tab_viewmodel.dart';
import '../ui/main/history_tab_viewmodel.dart';
import '../ui/main/main_shell_viewmodel.dart';
import '../ui/main/settings_tab_viewmodel.dart';

class MainShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(
      MainShellViewModel(
        machineRepo: Get.find<PairedMachineRepository>(),
        recovery: Get.find<ReconnectRecoveryCoordinator>(),
        wsRepo: Get.find<WsSessionRepository>(),
        eventRepo: Get.find<EventRepository>(),
      ),
    );
    Get.lazyPut(
      () => ActiveTabViewModel(eventRepo: Get.find<EventRepository>()),
    );
    Get.lazyPut(
      () => HistoryTabViewModel(
        eventRepo: Get.find<EventRepository>(),
        machineRepo: Get.find<PairedMachineRepository>(),
      ),
    );
    Get.lazyPut(() {
      final shell = Get.find<MainShellViewModel>();
      return SettingsTabViewModel(
        crypto: Get.find<CryptoService>(),
        machineRepo: Get.find<PairedMachineRepository>(),
        wsRepo: Get.find<WsSessionRepository>(),
        connectMachine: shell.connectMachine,
        pairingLinkParser: Get.find(),
      );
    });
  }
}
