import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/session.dart';
import '../local/session_database.dart';
import '../services/ws/models/ws_models.dart';
import 'ws_session_repository.dart';

class EventRepository {
  final WsSessionRepository _wsRepo;
  late final StreamSubscription<WsEvent> _sub;
  final _eventController = StreamController<AgentEvent>.broadcast();
  final _sessionsChangedController = StreamController<void>.broadcast();

  /// Lightweight session metadata for list display.
  final Map<String, AgentSession> sessions = {};

  /// Pending approval requests, keyed by requestId.
  final pendingApprovals = <String, ApprovalRequest>{}.obs;

  /// Last seen event sequence number per machine (for resync after reconnect).
  final Map<String, int> _lastSeqByMachine = {};

  EventRepository({required WsSessionRepository wsRepo}) : _wsRepo = wsRepo {
    _sub = _wsRepo.events.listen(_onWsEvent);
  }

  Stream<AgentEvent> get events => _eventController.stream;

  /// Emits only when session metadata changes (status, runFinished, runFailed, register).
  Stream<void> get sessionsChanged => _sessionsChangedController.stream;

  int lastSeqFor(String machineId) => _lastSeqByMachine[machineId] ?? 0;

  /// Load all sessions from SQLite into memory. Call once at startup.
  Future<void> init() async {
    final rows = await SessionDatabase.loadAll();
    for (final s in rows) {
      sessions[s.id] = s;
    }
  }

  void _onWsEvent(WsEvent wsEvent) {
    final payload = wsEvent.payload;
    final machineId =
        payload['machineId'] as String? ??
        payload['machine_id'] as String? ??
        '';

    final event = AgentEvent.fromJson(payload, machineId);
    if (event.type == null) return;

    // Track sequence number per machine for resync
    if (machineId.isNotEmpty && event.seq > (_lastSeqByMachine[machineId] ?? 0)) {
      _lastSeqByMachine[machineId] = event.seq;
    }

    _processEvent(event);
  }

  void _processEvent(AgentEvent event) {
    // Update lightweight session metadata
    _updateSessionMeta(event);

    // Track pending approvals
    _updateApprovals(event);

    _eventController.add(event);
  }

  void _updateApprovals(AgentEvent event) {
    switch (event.type) {
      case EventType.approvalRequested:
        if (event.approval != null) {
          pendingApprovals[event.approval!.id] = event.approval!;
        }
      case EventType.approvalReplied:
        if (event.approval != null) {
          pendingApprovals.remove(event.approval!.id);
        }
      default:
        break;
    }
  }

  void _updateSessionMeta(AgentEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    switch (event.type) {
      case EventType.sessionStatus:
        if (event.session != null) {
          final existing = sessions[sessionId];
          final incoming = event.session!;
          final mergedMetadata = <String, dynamic>{};
          if (existing?.metadata != null) {
            mergedMetadata.addAll(existing!.metadata!);
          }
          if (incoming.metadata != null) {
            mergedMetadata.addAll(incoming.metadata!);
          }
          if (event.machineId.isNotEmpty) {
            mergedMetadata['machineId'] = event.machineId;
          }
          incoming.metadata = mergedMetadata.isEmpty ? null : mergedMetadata;
          sessions[sessionId] = incoming;

          // Persist title, status, model changes
          final dbFields = <String, dynamic>{
            'updated_at': incoming.updatedAt.toIso8601String(),
          };
          if (incoming.title.isNotEmpty) {
            dbFields['title'] = incoming.title;
          }
          dbFields['status'] = incoming.status.value;
          if (incoming.model != null) {
            dbFields['model'] = incoming.model;
          }
          SessionDatabase.updateFields(sessionId, dbFields);

          _sessionsChangedController.add(null);
        }
      case EventType.runFinished:
      case EventType.runFailed:
        final existing = sessions[sessionId];
        if (existing != null) {
          existing.updatedAt = event.at;
          existing.status = event.type == EventType.runFinished
              ? SessionStatus.done
              : SessionStatus.error;

          // Persist status + cost
          final dbFields = <String, dynamic>{
            'updated_at': event.at.toIso8601String(),
            'status': existing.status.value,
          };
          if (existing.cost != null) {
            dbFields['cost_input_tokens'] = existing.cost!.inputTokens;
            dbFields['cost_output_tokens'] = existing.cost!.outputTokens;
            dbFields['cost_cache_read'] = existing.cost!.cacheRead;
            dbFields['cost_cache_write'] = existing.cost!.cacheWrite;
            dbFields['cost_total_usd'] = existing.cost!.totalUsd;
          }
          SessionDatabase.updateFields(sessionId, dbFields);

          _sessionsChangedController.add(null);

          if (event.type == EventType.runFinished &&
              existing.title.isEmpty &&
              event.machineId.isNotEmpty) {
            unawaited(
              backfillMissingTitles(event.machineId, sessionIds: [sessionId]),
            );
          }
        }
      case EventType.approvalRequested:
        final existing = sessions[sessionId];
        if (existing != null) {
          existing.status = SessionStatus.waitingApproval;
          existing.updatedAt = event.at;
          SessionDatabase.updateFields(sessionId, {
            'status': SessionStatus.waitingApproval.value,
            'updated_at': event.at.toIso8601String(),
          });
          _sessionsChangedController.add(null);
        }
      case EventType.approvalReplied:
        final existing = sessions[sessionId];
        if (existing != null) {
          existing.status = SessionStatus.running;
          existing.updatedAt = event.at;
          SessionDatabase.updateFields(sessionId, {
            'status': SessionStatus.running.value,
            'updated_at': event.at.toIso8601String(),
          });
          _sessionsChangedController.add(null);
        }
      case EventType.modeChanged:
        final existing = sessions[sessionId];
        if (existing != null && event.data != null) {
          final modeId = event.data!['currentModeId'] as String?;
          if (modeId != null) {
            final metadata = <String, dynamic>{...?existing.metadata};
            metadata['mode'] = modeId;
            existing.metadata = metadata;
            existing.updatedAt = event.at;
            SessionDatabase.updateFields(sessionId, {'mode': modeId});
            _sessionsChangedController.add(null);
          }
        }
      case EventType.messageDelta:
      case EventType.messageFinal:
      case EventType.toolStarted:
      case EventType.toolUpdated:
      case EventType.toolCompleted:
      case EventType.toolFailed:
        // Touch updatedAt in memory only — no SQLite write for streaming events
        final existing = sessions[sessionId];
        if (existing != null) {
          existing.updatedAt = event.at;
        }
      default:
        break;
    }
  }

  /// Resync missed events after reconnect. Call after session re-init.
  Future<void> resync(String machineId) async {
    final lastSeq = _lastSeqByMachine[machineId] ?? 0;
    if (lastSeq == 0) return; // No events seen yet, nothing to resync

    try {
      final result = await _wsRepo.callRpc(
        machineId: machineId,
        method: 'events.resync',
        params: {'lastSeq': lastSeq},
      );

      final events = result['events'] as List<dynamic>? ?? [];
      for (final eventJson in events) {
        if (eventJson is Map<String, dynamic>) {
          final event = AgentEvent.fromJson(eventJson, machineId);
          if (event.type == null) continue;
          if (event.seq > (_lastSeqByMachine[machineId] ?? 0)) {
            _lastSeqByMachine[machineId] = event.seq;
          }
          _processEvent(event);
        }
      }

      final complete = result['complete'] as bool? ?? true;
      if (!complete) {
        // Gap too large — event buffer overflowed.
        // Affected sessions should be fully reloaded via session.load.
        debugPrint(
          '[EventRepo] resync incomplete — some events may have been lost',
        );
      }
    } catch (e) {
      debugPrint('[EventRepo] resync failed: $e');
    }
  }

  /// Reconcile stale running/waitingApproval sessions after reconnect.
  /// Uses session.resolve to check which sessions the daemon still knows about.
  /// Sessions returned → idle (exists but not running).
  /// Sessions NOT returned → done (unknown to this daemon instance).
  Future<void> reconcileSessionStatus(String machineId) async {
    // Collect all running/waitingApproval sessions for this machine
    final stale = sessions.values.where((s) {
      final mid = s.metadata?['machineId'] as String? ?? '';
      return mid == machineId &&
          (s.status == SessionStatus.running ||
           s.status == SessionStatus.waitingApproval);
    }).toList();

    if (stale.isEmpty) return;

    try {
      final result = await _wsRepo.callRpc(
        machineId: machineId,
        method: 'session.resolve',
        params: {'sessionIds': stale.map((s) => s.id).toList()},
      );

      final list = result['sessions'] as List<dynamic>? ?? [];
      final resolvedIds = <String>{};
      for (final item in list) {
        if (item is Map) {
          final id = (item['sessionId'] as String?) ?? '';
          if (id.isNotEmpty) resolvedIds.add(id);
        }
      }

      var changed = false;
      for (final session in stale) {
        // Active sessions briefly marked idle will self-correct
        // when runFinished/runFailed events arrive.
        final newStatus = resolvedIds.contains(session.id)
            ? SessionStatus.idle   // daemon knows it, but it's at rest
            : SessionStatus.done;  // daemon doesn't know it (previous lifetime)

        if (session.status != newStatus) {
          session.status = newStatus;
          session.updatedAt = DateTime.now();
          await SessionDatabase.updateFields(session.id, {
            'status': newStatus.value,
            'updated_at': session.updatedAt.toIso8601String(),
          });
          // Clear stale approvals for this session
          pendingApprovals.removeWhere(
            (_, a) => a.sessionId == session.id,
          );
          changed = true;
        }
      }

      if (changed) {
        _sessionsChangedController.add(null);
      }
    } catch (e) {
      debugPrint('[EventRepo] reconcileSessionStatus failed: $e');
    }
  }

  /// Fetch pending approvals from daemon via RPC (fallback for ring buffer overflow).
  Future<void> fetchPendingApprovals(String machineId) async {
    try {
      final result = await _wsRepo.callRpc(
        machineId: machineId,
        method: 'approvals.pending',
        params: {},
      );
      final list = result['approvals'] as List<dynamic>? ?? [];
      for (final json in list) {
        final approval = ApprovalRequest.fromJson(json as Map<String, dynamic>);
        pendingApprovals[approval.id] = approval;
        // Also update session status
        final session = sessions[approval.sessionId];
        if (session != null &&
            session.status != SessionStatus.waitingApproval) {
          session.status = SessionStatus.waitingApproval;
          SessionDatabase.updateFields(approval.sessionId, {
            'status': 'waiting_approval',
          });
        }
      }
      if (list.isNotEmpty) {
        _sessionsChangedController.add(null);
      }
    } catch (e) {
      debugPrint('[EventRepo] fetchPendingApprovals failed: $e');
    }
  }

  /// Resolve missing session titles via daemon-side session/list.
  /// When [runtime] is provided, only sessions matching that runtime are
  /// included in the RPC call. Sessions from a different runtime would not
  /// be resolvable by the current daemon anyway.
  Future<void> backfillMissingTitles(
    String machineId, {
    List<String>? sessionIds,
    String? runtime,
  }) async {
    try {
      final targetIds =
          sessionIds ??
          sessions.values
              .where((s) {
                final sameMachine =
                    (s.metadata?['machineId'] as String? ?? '') == machineId;
                if (!sameMachine || s.title.isNotEmpty) return false;
                // Skip sessions from a different runtime — the daemon can't
                // resolve them.
                if (runtime != null && runtime.isNotEmpty) {
                  final sr = s.metadata?['runtime'] as String? ?? '';
                  if (sr.isNotEmpty && sr != runtime) return false;
                }
                return true;
              })
              .map((s) => s.id)
              .toList();
      if (targetIds.isEmpty) {
        return;
      }

      final result = await _wsRepo.callRpc(
        machineId: machineId,
        method: 'session.resolve',
        params: {'sessionIds': targetIds},
      );
      final list = result['sessions'] as List<dynamic>? ?? [];
      var changed = false;

      for (final item in list) {
        if (item is! Map) continue;
        final json = Map<String, dynamic>.from(item);

        final sessionId = json['sessionId'] as String? ?? '';
        if (sessionId.isEmpty) continue;

        final title = json['title'] as String? ?? '';
        final sessionCwd = json['cwd'] as String? ?? '';
        final updatedAt = _parseRpcTime(json['updatedAt']) ?? DateTime.now();
        final existing = sessions[sessionId];

        if (existing == null) {
          final session = AgentSession(
            id: sessionId,
            title: title,
            status: SessionStatus.idle,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            metadata: {'machineId': machineId, 'cwd': sessionCwd},
          );
          sessions[sessionId] = session;
          await SessionDatabase.insertSession(session);
          changed = true;
          continue;
        }

        var dirty = false;
        if (title.isNotEmpty && existing.title != title) {
          existing.title = title;
          dirty = true;
        }
        if (updatedAt.isAfter(existing.updatedAt)) {
          existing.updatedAt = updatedAt;
          dirty = true;
        }

        final metadata = <String, dynamic>{...?existing.metadata};
        if (metadata['machineId'] != machineId) {
          metadata['machineId'] = machineId;
          dirty = true;
        }
        if (sessionCwd.isNotEmpty && metadata['cwd'] != sessionCwd) {
          metadata['cwd'] = sessionCwd;
          dirty = true;
        }
        existing.metadata = metadata;

        if (!dirty) continue;

        final persistedCwd = existing.metadata?['cwd'] as String? ?? '';
        final dbFields = <String, dynamic>{
          'machine_id': machineId,
          'cwd': persistedCwd,
          'updated_at': existing.updatedAt.toIso8601String(),
        };
        if (existing.title.isNotEmpty) {
          dbFields['title'] = existing.title;
        }
        await SessionDatabase.updateFields(sessionId, dbFields);
        changed = true;
      }

      if (changed) {
        _sessionsChangedController.add(null);
      }
    } catch (e) {
      debugPrint('[EventRepo] backfillMissingTitles failed: $e');
    }
  }

  /// Reply to a pending approval. Shared by ChatVM and ActiveTabVM.
  Future<void> replyApproval({
    required String machineId,
    required String sessionId,
    required String requestId,
    required String optionId,
  }) async {
    await _wsRepo.callRpc(
      machineId: machineId,
      method: 'approval.reply',
      params: {
        'sessionId': sessionId,
        'requestId': requestId,
        'optionId': optionId,
      },
    );
  }

  /// Register a session created via RPC (before any events arrive).
  void registerSession(AgentSession session) {
    sessions[session.id] = session;
    SessionDatabase.insertSession(session);
    _sessionsChangedController.add(null);
  }

  AgentSession? sessionById(String sessionId) => sessions[sessionId];

  /// Update a session's status from the UI (e.g. optimistic "running" on send).
  void setSessionStatus(String sessionId, SessionStatus status) {
    final existing = sessions[sessionId];
    if (existing != null && existing.status != status) {
      existing.status = status;
      SessionDatabase.updateFields(sessionId, {'status': status.value});
      _sessionsChangedController.add(null);
    }
  }

  void dispose() {
    _sub.cancel();
    _eventController.close();
    _sessionsChangedController.close();
  }

  DateTime? _parseRpcTime(Object? value) {
    final raw = value as String?;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}
