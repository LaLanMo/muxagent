import 'package:get/get.dart';

import '../data/repositories/auth_repository.dart';
import '../ui/auth/auth_viewmodel.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthViewModel>(
      () => AuthViewModel(authRepository: Get.find<AuthRepository>()),
    );
  }
}
