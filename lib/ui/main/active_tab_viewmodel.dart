import 'dart:async';

import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../domain/enums.dart';
import '../../domain/session.dart';

class ActiveTabViewModel extends GetxController {
  final EventRepository _eventRepo;

  ActiveTabViewModel({required EventRepository eventRepo})
      : _eventRepo = eventRepo;

  final activeSessions = <AgentSession>[].obs;

  StreamSubscription<void>? _sessionsSub;

  static const _activeStatuses = {
    SessionStatus.running,
    SessionStatus.waitingApproval,
  };

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

  void _syncSessions() {
    activeSessions.value = _eventRepo.sessions.values
        .where((s) => _activeStatuses.contains(s.status))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> replyApproval({
    required String machineId,
    required String sessionId,
    required String requestId,
    required String optionId,
  }) async {
    await _eventRepo.replyApproval(
      machineId: machineId,
      sessionId: sessionId,
      requestId: requestId,
      optionId: optionId,
    );
  }
}
