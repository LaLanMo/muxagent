import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/models/auth_request.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/services/pairing_deep_link_coordinator.dart';
import '../../routing/routes.dart';

class StartupViewModel extends GetxController {
  StartupViewModel({
    required PairedMachineRepository machineRepo,
    required PairingDeepLinkCoordinator pairingDeepLinkCoordinator,
  }) : _machineRepo = machineRepo,
       _pairingDeepLinkCoordinator = pairingDeepLinkCoordinator;

  final PairedMachineRepository _machineRepo;
  final PairingDeepLinkCoordinator _pairingDeepLinkCoordinator;

  VoidCallback? _welcomeRedirectBlockListener;
  bool _machinesLoaded = false;
  bool _resolved = false;

  @override
  void onInit() {
    super.onInit();
    _welcomeRedirectBlockListener = _maybeResolveInitialRoute;
    _pairingDeepLinkCoordinator.welcomeRedirectBlockedListenable.addListener(
      _welcomeRedirectBlockListener!,
    );
    unawaited(_loadMachines());
  }

  @override
  void onClose() {
    if (_welcomeRedirectBlockListener != null) {
      _pairingDeepLinkCoordinator.welcomeRedirectBlockedListenable.removeListener(
        _welcomeRedirectBlockListener!,
      );
    }
    super.onClose();
  }

  Future<void> _loadMachines() async {
    await _machineRepo.refresh();
    _machinesLoaded = true;
    _maybeResolveInitialRoute();
  }

  void _maybeResolveInitialRoute() {
    if (_resolved || !_machinesLoaded) {
      return;
    }
    if (Get.currentRoute.isNotEmpty && Get.currentRoute != Routes.startup) {
      _resolved = true;
      return;
    }

    final startupRequest = _takeStartupAuthRequest();
    if (startupRequest != null) {
      _scheduleNavigation(Routes.auth, arguments: startupRequest);
      return;
    }

    if (_pairingDeepLinkCoordinator.hasPendingPairingNavigation) {
      return;
    }

    if (_machineRepo.machines.isNotEmpty) {
      _scheduleNavigation(Routes.home);
      return;
    }

    if (_pairingDeepLinkCoordinator.isBlockingWelcomeRedirect) {
      return;
    }

    _scheduleNavigation(Routes.welcome);
  }

  AuthRequest? _takeStartupAuthRequest() {
    if (!_pairingDeepLinkCoordinator.prepareStartupRoute()) {
      return null;
    }
    return _pairingDeepLinkCoordinator.consumeStartupRouteRequest();
  }

  void _scheduleNavigation(String route, {Object? arguments}) {
    if (_resolved) {
      return;
    }
    _resolved = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute.isNotEmpty && Get.currentRoute != Routes.startup) {
        return;
      }
      Get.offAllNamed(route, arguments: arguments);
    });
  }
}
