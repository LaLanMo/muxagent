import 'dart:async';

import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/session.dart';
import '../services/ws/models/ws_models.dart';
import 'ws_session_repository.dart';

class EventRepository {
  final WsSessionRepository _wsRepo;
  late final StreamSubscription<WsEvent> _sub;
  final _eventController = StreamController<AgentEvent>.broadcast();

  /// Lightweight session metadata for list display.
  final Map<String, AgentSession> sessions = {};

  EventRepository({required WsSessionRepository wsRepo}) : _wsRepo = wsRepo {
    _sub = _wsRepo.events.listen(_onWsEvent);
  }

  Stream<AgentEvent> get events => _eventController.stream;

  void _onWsEvent(WsEvent wsEvent) {
    final payload = wsEvent.payload;
    final machineId = payload['machineId'] as String? ??
        payload['machine_id'] as String? ??
        '';

    final event = AgentEvent.fromJson(payload, machineId);
    if (event.type == null) return;

    // Update lightweight session metadata
    _updateSessionMeta(event);

    _eventController.add(event);
  }

  void _updateSessionMeta(AgentEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    switch (event.type) {
      case EventType.sessionStatus:
        if (event.session != null) {
          sessions[sessionId] = event.session!;
        }
      case EventType.runFinished:
      case EventType.runFailed:
        final existing = sessions[sessionId];
        if (existing != null) {
          existing.status = SessionStatus.done;
          existing.updatedAt = event.at;
        }
      case EventType.messageDelta:
      case EventType.messageFinal:
      case EventType.toolStarted:
      case EventType.toolUpdated:
      case EventType.toolCompleted:
      case EventType.toolFailed:
        // Touch updatedAt
        final existing = sessions[sessionId];
        if (existing != null) {
          existing.updatedAt = event.at;
        }
      default:
        break;
    }
  }

  /// Register a session created via RPC (before any events arrive).
  void registerSession(AgentSession session) {
    sessions[session.id] = session;
  }

  void dispose() {
    _sub.cancel();
    _eventController.close();
  }
}
