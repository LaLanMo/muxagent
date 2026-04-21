import 'package:get/get.dart';

import '../data/repositories/language_preference_repository.dart';
import '../ui/language/language_viewmodel.dart';

class LanguageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LanguageViewModel>(
      () => LanguageViewModel(
        repository: Get.find<LanguagePreferenceRepository>(),
      ),
    );
  }
}
