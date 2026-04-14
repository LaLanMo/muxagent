import 'package:get/get.dart';

import '../../data/models/auth_request.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/api/base_api_client.dart';
import '../../data/services/api/relay_service.dart';
import '../../routing/routes.dart';

enum AuthState { checking, pending, approving, approved, expired, error }

class AuthViewModel extends GetxController {
  final AuthRepository _authRepository;

  AuthViewModel({required AuthRepository authRepository})
    : _authRepository = authRepository;

  late final AuthRequest authRequest;

  final state = AuthState.checking.obs;
  final errorMessage = RxnString();
  final machineHostname = RxnString();

  @override
  void onInit() {
    super.onInit();
    authRequest = Get.arguments as AuthRequest;
    _checkAndApprove();
  }

  Future<void> _checkAndApprove() async {
    try {
      // First check if the request is still valid
      state.value = AuthState.checking;
      final status = await _authRepository.checkStatus(authRequest);

      if (status.isExpired) {
        state.value = AuthState.expired;
        return;
      }

      if (status.isApproved) {
        state.value = AuthState.approved;
        return;
      }

      // Request is pending - show approval UI
      _setFingerprints(status);
      state.value = AuthState.pending;
    } on ApiException catch (e) {
      state.value = AuthState.error;
      errorMessage.value = e.message;
    } catch (e) {
      state.value = AuthState.error;
      errorMessage.value = 'Failed to check auth status: $e';
    }
  }

  Future<void> approve() async {
    try {
      state.value = AuthState.approving;
      await _authRepository.approve(authRequest);
      state.value = AuthState.approved;
    } on ApiException catch (e) {
      state.value = AuthState.error;
      errorMessage.value = e.message;
    } catch (e) {
      state.value = AuthState.error;
      errorMessage.value = 'Failed to approve: $e';
    }
  }

  void _setFingerprints(AuthStatusResponse status) {
    machineHostname.value = status.machineHostname;
  }

  void cancel() {
    Get.until((route) => route.isFirst);
  }

  void done() {
    Get.offAllNamed(Routes.home);
  }

  void retry() {
    _checkAndApprove();
  }
}
