import 'package:get/get.dart';

import '../chat/chat_viewmodel.dart';

class SessionSettingsViewModel extends GetxController {
  late final ChatViewModel _chatVm;

  @override
  void onInit() {
    super.onInit();
    _chatVm = Get.find<ChatViewModel>();
  }

  String? get currentModel => _chatVm.currentModel.value;
  String get modelConfigId => _chatVm.modelConfigId.value;
  List get availableModels => _chatVm.availableModels;

  void changeModel(String value) => _chatVm.changeModel(value);
}
