import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../domain/paired_machine.dart';
import '../../domain/session.dart';

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
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final session in filtered) {
      final dt = DateTime(
        session.createdAt.year,
        session.createdAt.month,
        session.createdAt.day,
      );
      String label;
      if (dt == today) {
        label = 'Today';
      } else if (dt == yesterday) {
        label = 'Yesterday';
      } else if (today.difference(dt).inDays <= 7) {
        label = 'Last Week';
      } else if (dt.year == now.year) {
        label = _formatDate(session.createdAt);
      } else {
        label = _formatDateWithYear(session.createdAt);
      }
      groups.putIfAbsent(label, () => []).add(session);
    }

    sessionGroups.value = groups.entries
        .map((e) => SessionGroup(label: e.key, sessions: e.value))
        .toList();
  }

  void _handleMachineCatalogChanged() {
    final selected = selectedMachineFilter.value;
    if (selected != null &&
        !_machineRepo.machines.any((machine) => machine.machineId == selected)) {
      selectedMachineFilter.value = null;
    }
    _syncSessions();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatDateWithYear(DateTime dt) {
    return '${_formatDate(dt)}, ${dt.year}';
  }
}
