import 'package:get/get.dart';

import '../data/repositories/stt_repository.dart';
import '../ui/stt_settings/stt_settings_viewmodel.dart';
import '../usecases/transcribe_audio.dart';

class SttSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SttSettingsViewModel>(() => SttSettingsViewModel(
          repo: Get.find<SttRepository>(),
          transcribe: Get.find<TranscribeAudioUseCase>(),
        ));
  }
}
