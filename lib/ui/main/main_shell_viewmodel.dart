import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../data/services/ws/models/ws_models.dart';
import '../../data/services/ws/ws_types.dart';
import '../../domain/paired_machine.dart';
import '../../routing/routes.dart';

class MainShellViewModel extends GetxController {
  final PairedMachineRepository _machineRepo =
      Get.find<PairedMachineRepository>();
  final WsSessionRepository _wsRepo = Get.find<WsSessionRepository>();
  final EventRepository _eventRepo = Get.find<EventRepository>();

  final tabIndex = 0.obs;
  final machines = <PairedMachine>[].obs;
  final activeSessionIds = <String>{}.obs;

  StreamSubscription<Set<String>>? _sessionSub;
  StreamSubscription<WsMachineStatus>? _machineStatusSub;

  @override
  void onInit() {
    super.onInit();
    _loadMachines();
    _subscribeToActiveSessions();
    _subscribeToMachineStatus();
  }

  @override
  void onClose() {
    _sessionSub?.cancel();
    _machineStatusSub?.cancel();
    super.onClose();
  }

  void switchTab(int index) {
    tabIndex.value = index;
  }

  int get pendingApprovalCount => _eventRepo.pendingApprovals.length;

  bool isMachineConnected(String machineId) {
    return activeSessionIds.contains(machineId);
  }

  String machineDisplayName(String machineId) {
    for (final machine in machines) {
      if (machine.machineId == machineId) {
        return machine.hostname ?? machineId;
      }
    }
    return machineId;
  }

  Future<void> refreshMachines() async {
    final list = await _machineRepo.listMachines();
    machines.value = list;
  }

  void navigateToNewSession() {
    Get.toNamed(Routes.newSession);
  }

  void navigateToChat(
    String sessionId,
    String machineId,
    String cwd,
    String title,
  ) {
    Get.toNamed(
      Routes.chat,
      arguments: {
        'sessionId': sessionId,
        'machineId': machineId,
        'cwd': cwd,
        'sessionTitle': title,
      },
    );
  }

  // --- Private ---

  Future<void> _loadMachines() async {
    final list = await _machineRepo.listMachines();
    machines.value = list;

    if (list.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(Routes.welcome);
      });
      return;
    }

    for (final machine in list) {
      if (!_wsRepo.hasSession(machine.machineId)) {
        await _connectMachine(machine);
      }
    }
  }

  Future<void> _connectMachine(PairedMachine machine) async {
    try {
      await _wsRepo.ensureConnected(relayHttpUrl: machine.relayHttpUrl);
      await _wsRepo.startSession(machine: machine);
      // Resync missed events after reconnect
      await _eventRepo.resync(machine.machineId);
      await _eventRepo.backfillMissingTitles(machine.machineId);
      await _eventRepo.fetchPendingApprovals(machine.machineId);
    } catch (e) {
      debugPrint('[MainShell] connect ${machine.machineId} failed: $e');
    }
  }

  Future<void> connectMachine(PairedMachine machine) async {
    await _connectMachine(machine);
  }

  void _subscribeToMachineStatus() {
    _machineStatusSub = _wsRepo.machineStatus.listen((status) {
      if (status.type == WsMessageType.machineOnline.value) {
        final machine = machines.firstWhereOrNull(
          (m) => m.machineId == status.machineId,
        );
        if (machine != null && !_wsRepo.hasSession(machine.machineId)) {
          _connectMachine(machine);
        }
      }
    });
  }

  void _subscribeToActiveSessions() {
    activeSessionIds
      ..clear()
      ..addAll(_wsRepo.activeSessionIds);
    _sessionSub = _wsRepo.activeSessions.listen((ids) {
      activeSessionIds
        ..clear()
        ..addAll(ids);
    });
  }
}
