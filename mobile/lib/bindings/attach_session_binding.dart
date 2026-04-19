import 'package:get/get.dart';

import '../data/repositories/event_repository.dart';
import '../data/repositories/paired_machine_repository.dart';
import '../data/repositories/runtime_preference_repository.dart';
import '../data/repositories/ws_session_repository.dart';
import '../ui/attach_session/attach_session_viewmodel.dart';

class AttachSessionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AttachSessionViewModel>(
      () => AttachSessionViewModel(
        machineRepo: Get.find<PairedMachineRepository>(),
        wsRepo: Get.find<WsSessionRepository>(),
        eventRepo: Get.find<EventRepository>(),
        runtimePrefs: Get.find<RuntimePreferenceRepository>(),
      ),
    );
  }
}
