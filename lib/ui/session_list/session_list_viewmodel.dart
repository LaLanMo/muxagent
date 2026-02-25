import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/paired_machine.dart';
import '../../domain/session.dart';
import '../../routing/routes.dart';

class SessionListViewModel extends GetxController {
  final PairedMachineRepository _machineRepo =
      Get.find<PairedMachineRepository>();
  final WsSessionRepository _wsRepo = Get.find<WsSessionRepository>();
  final EventRepository _eventRepo = Get.find<EventRepository>();

  final machines = <PairedMachine>[].obs;
  final sessions = <AgentSession>[].obs;
  final activeSessionIds = <String>{}.obs;

  StreamSubscription<AgentEvent>? _eventSub;
  StreamSubscription<Set<String>>? _sessionSub;

  @override
  void onInit() {
    super.onInit();
    _loadMachines();
    _syncSessions();
    _subscribeToEvents();
    _subscribeToActiveSessions();
  }

  @override
  void onClose() {
    _eventSub?.cancel();
    _sessionSub?.cancel();
    super.onClose();
  }

  Future<void> _loadMachines() async {
    final list = await _machineRepo.listMachines();
    machines.value = list;

    if (list.isEmpty) {
      Get.offAllNamed(Routes.welcome);
      return;
    }

    // Auto-connect all machines sequentially to avoid race conditions
    // on the shared WebSocket connection.
    for (final machine in list) {
      if (!_wsRepo.hasSession(machine.machineId)) {
        await _connectMachine(machine);
      }
      await _refreshSessionsForMachine(machine);
    }
    _syncSessions();
  }

  void _syncSessions() {
    final map = _eventRepo.sessions;
    sessions.value = map.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void _subscribeToEvents() {
    _eventSub = _eventRepo.events.listen((_) {
      _syncSessions();
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

  Future<void> _connectMachine(PairedMachine machine) async {
    try {
      await _wsRepo.ensureConnected(relayHttpUrl: machine.relayHttpUrl);
      await _wsRepo.startSession(machine: machine);
    } catch (e) {
      debugPrint('[SessionList] connect ${machine.machineId} failed: $e');
    }
  }

  Future<void> _refreshSessionsForMachine(PairedMachine machine) async {
    if (!_wsRepo.hasSession(machine.machineId)) {
      return;
    }
    try {
      final rawSessions = await _wsRepo.listSessions(
        machineId: machine.machineId,
      );
      final parsed = rawSessions
          .map((item) => _parseSessionSummary(item, machine.machineId))
          .whereType<AgentSession>()
          .toList();
      _eventRepo.syncSessionsFromList(
        machineId: machine.machineId,
        sessionList: parsed,
      );
    } catch (e) {
      debugPrint('[SessionList] session.list ${machine.machineId} failed: $e');
    }
  }

  AgentSession? _parseSessionSummary(
    Map<String, dynamic> item,
    String machineId,
  ) {
    final sessionId = item['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }

    final updatedAtRaw = item['updatedAt'] as String?;
    final updatedAt = updatedAtRaw != null
        ? DateTime.tryParse(updatedAtRaw)
        : null;
    final now = DateTime.now();
    final cwd = item['cwd'] as String? ?? '';

    return AgentSession(
      id: sessionId,
      title: item['title'] as String? ?? '',
      status: SessionStatus.idle,
      createdAt: updatedAt ?? now,
      updatedAt: updatedAt ?? now,
      metadata: {'machineId': machineId, 'cwd': cwd},
    );
  }

  Future<void> connectMachine(PairedMachine machine) async {
    await _connectMachine(machine);
    await _refreshSessionsForMachine(machine);
    _syncSessions();
  }

  bool isMachineConnected(String machineId) {
    return activeSessionIds.contains(machineId);
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

  void navigateToNewSession() {
    Get.toNamed(Routes.newSession);
  }

  void navigateToSettings() {
    Get.toNamed(Routes.settings);
  }
}
