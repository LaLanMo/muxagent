import 'dart:async';

import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../domain/session.dart';

class SessionGroup {
  final String label;
  final List<AgentSession> sessions;
  SessionGroup({required this.label, required this.sessions});
}

class HistoryTabViewModel extends GetxController {
  final EventRepository _eventRepo;

  HistoryTabViewModel({required EventRepository eventRepo})
    : _eventRepo = eventRepo;

  final sessionGroups = <SessionGroup>[].obs;
  final selectedMachineFilter = Rxn<String>();

  StreamSubscription<void>? _sessionsSub;

  @override
  void onInit() {
    super.onInit();
    _syncSessions();
    _sessionsSub = _eventRepo.sessionsChanged.listen((_) {
      _syncSessions();
    });
  }

  @override
  void onClose() {
    _sessionsSub?.cancel();
    super.onClose();
  }

  void setMachineFilter(String? machineId) {
    selectedMachineFilter.value = machineId;
    _syncSessions();
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
