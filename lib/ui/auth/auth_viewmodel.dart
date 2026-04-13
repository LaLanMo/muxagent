import 'package:flutter/foundation.dart';
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

  bool get _isMockRequest => kDebugMode && authRequest.id.startsWith('mock-');

  @override
  void onInit() {
    super.onInit();
    authRequest = Get.arguments as AuthRequest;
    if (_loadMockState()) {
      return;
    }
    _checkAndApprove();
  }

  bool _loadMockState() {
    if (!_isMockRequest) {
      return false;
    }

    machineHostname.value = 'dev-macbook.local:8080';
    errorMessage.value = null;
    switch (authRequest.id) {
      case 'mock-approved':
        state.value = AuthState.approved;
        break;
      case 'mock-expired':
        state.value = AuthState.expired;
        break;
      case 'mock-error':
        state.value = AuthState.error;
        errorMessage.value = 'Mock relay timeout';
        break;
      case 'mock-checking':
        state.value = AuthState.checking;
        break;
      case 'mock-approving':
        state.value = AuthState.approving;
        break;
      case 'mock-pending':
      default:
        state.value = AuthState.pending;
        break;
    }
    return true;
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
    if (_isMockRequest) {
      state.value = AuthState.approved;
      return;
    }
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
    if (_isMockRequest) {
      Get.back();
      return;
    }
    Get.until((route) => route.isFirst);
  }

  void done() {
    if (_isMockRequest) {
      Get.back();
      return;
    }
    Get.offAllNamed(Routes.home);
  }

  void retry() {
    if (_loadMockState()) {
      return;
    }
    _checkAndApprove();
  }
}
