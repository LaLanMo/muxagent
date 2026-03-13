import 'package:get/get.dart';

import '../data/repositories/event_repository.dart';
import '../data/repositories/paired_machine_repository.dart';
import '../data/repositories/runtime_preference_repository.dart';
import '../data/repositories/ws_session_repository.dart';
import '../ui/new_session/new_session_viewmodel.dart';
import '../usecases/transcribe_audio.dart';

class NewSessionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NewSessionViewModel>(
      () => NewSessionViewModel(
        machineRepo: Get.find<PairedMachineRepository>(),
        wsRepo: Get.find<WsSessionRepository>(),
        eventRepo: Get.find<EventRepository>(),
        runtimePrefs: Get.find<RuntimePreferenceRepository>(),
        transcribe: Get.find<TranscribeAudioUseCase>(),
      ),
    );
  }
}
