import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../domain/paired_machine.dart';
import '../../domain/session.dart';
import '../../i18n/tx.dart';

class SessionGroup {
  final String label;
  final List<AgentSession> sessions;
  SessionGroup({required this.label, required this.sessions});
}

class HistoryTabViewModel extends GetxController {
  final EventRepository _eventRepo;
  final PairedMachineRepository _machineRepo;

  HistoryTabViewModel({
    required EventRepository eventRepo,
    required PairedMachineRepository machineRepo,
  }) : _eventRepo = eventRepo,
       _machineRepo = machineRepo;

  final sessionGroups = <SessionGroup>[].obs;
  final selectedMachineFilter = Rxn<String>();
  ValueListenable<List<PairedMachine>> get machinesListenable =>
      _machineRepo.machinesListenable;

  StreamSubscription<void>? _sessionsSub;
  VoidCallback? _machinesListener;

  @override
  void onInit() {
    super.onInit();
    _syncSessions();
    _machinesListener = _handleMachineCatalogChanged;
    _machineRepo.machinesListenable.addListener(_machinesListener!);
    _sessionsSub = _eventRepo.sessionsChanged.listen((_) {
      _syncSessions();
    });
    unawaited(_machineRepo.refresh());
  }

  @override
  void onClose() {
    _sessionsSub?.cancel();
    if (_machinesListener != null) {
      _machineRepo.machinesListenable.removeListener(_machinesListener!);
    }
    super.onClose();
  }

  void setMachineFilter(String? machineId) {
    selectedMachineFilter.value = machineId;
    _syncSessions();
  }

  String machineDisplayName(String machineId) {
    for (final machine in _machineRepo.machines) {
      if (machine.machineId == machineId) {
        return machine.hostname ?? machineId;
      }
    }
    return machineId;
  }

  void _syncSessions() {
    var filtered = _eventRepo.sessions.values.toList();

    final machineFilter = selectedMachineFilter.value;
    if (machineFilter != null) {
      filtered = filtered.where((s) => s.machineId == machineFilter).toList();
    }

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Group by date
    final groups = <String, List<AgentSession>>{};
    final now = DateTime.now();
    for (final session in filtered) {
      final label = Tx.historyGroupLabel(session.createdAt, now);
      groups.putIfAbsent(label, () => []).add(session);
    }

    sessionGroups.value = groups.entries
        .map((e) => SessionGroup(label: e.key, sessions: e.value))
        .toList();
  }

  void _handleMachineCatalogChanged() {
    final selected = selectedMachineFilter.value;
    if (selected != null &&
        !_machineRepo.machines.any(
          (machine) => machine.machineId == selected,
        )) {
      selectedMachineFilter.value = null;
    }
    _syncSessions();
  }
}
