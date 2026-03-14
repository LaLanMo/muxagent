import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../domain/approval.dart';
import '../../domain/cost_info.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/session.dart';
import '../../domain/usage_info.dart';
import '../local/session_database.dart';
import '../services/ws/approval_event_mapper.dart';
import '../services/ws/message_event_mapper.dart';
import '../services/ws/plan_event_mapper.dart';
import '../services/ws/run_event_mapper.dart';
import '../services/ws/session_config_event_mapper.dart';
import '../services/ws/tool_event_mapper.dart';
import '../services/ws/usage_event_mapper.dart';
import '../services/ws/models/ws_models.dart';
import '../services/ws/ws_types.dart';
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

  /// In-memory live usage per session (updated by usage.update events).
  final Map<String, UsageInfo> _liveUsage = {};

  /// Get live usage info for a session (for UI display).
  UsageInfo? liveUsageFor(String sessionId) => _liveUsage[sessionId];

  /// Sessions currently being viewed in ChatVM (don't mark unread while viewing).
  final Set<String> _viewingSessions = {};

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
    if (wsEvent.type != WsMessageType.event.value) {
      return;
    }

    final payload = wsEvent.payload;
    final machineId =
        payload['machineId'] as String? ??
        payload['machine_id'] as String? ??
        '';
    final eventType = EventType.fromValue(payload['type'] as String?);
    if (eventType == null) return;

    final event = switch (eventType) {
      EventType.approvalRequested || EventType.approvalReplied =>
        ApprovalEventMapper.parseEvent(payload, machineId),
      EventType.toolStarted ||
      EventType.toolUpdated ||
      EventType.toolCompleted ||
      EventType.toolFailed => ToolEventMapper.parseEvent(payload, machineId),
      EventType.messageDelta ||
      EventType.reasoning => MessageEventMapper.parseEvent(payload, machineId),
      EventType.planUpdated => PlanEventMapper.parseEvent(payload, machineId),
      EventType.runFinished => RunEventMapper.parseRunFinished(
        payload,
        machineId,
      ),
      EventType.usageUpdate => UsageEventMapper.parseEvent(payload, machineId),
      EventType.modeChanged || EventType.modelChanged =>
        SessionConfigEventMapper.parseEvent(payload, machineId),
      _ => AgentEvent.fromJson(payload, machineId),
    };
    if (event.type == null) return;

    // Track sequence number per machine for resync
    if (machineId.isNotEmpty &&
        event.seq > (_lastSeqByMachine[machineId] ?? 0)) {
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
          incoming.isRead = existing?.isRead ?? incoming.isRead;
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
      case EventType.usageUpdate:
        if (event.usageUpdate != null) {
          final usage = _liveUsage.putIfAbsent(sessionId, () => UsageInfo());
          final update = event.usageUpdate!;
          usage.contextUsed = update.contextUsed;
          usage.contextSize = update.contextSize;
          if (update.costAmount != null) {
            usage.costAmount = update.costAmount!;
            usage.costCurrency = update.costCurrency ?? 'USD';
          }
          // Update in-memory session
          final existing = sessions[sessionId];
          if (existing != null) {
            existing.cost = CostInfo(
              costAmount: usage.costAmount,
              costCurrency: usage.costCurrency,
              totalTokens: usage.totalTokens,
            );
          }
          _sessionsChangedController.add(null);
        }
      case EventType.runFinished:
      case EventType.runFailed:
        final existing = sessions[sessionId];
        if (existing != null) {
          existing.updatedAt = event.at;
          existing.status = event.type == EventType.runFinished
              ? SessionStatus.idle
              : SessionStatus.error;

          // Mark unread if user is not currently viewing this session
          if (!_viewingSessions.contains(sessionId) && existing.isRead) {
            existing.isRead = false;
          }

          // Extract token usage from the explicit run.finished payload.
          final totalTokens = event.runFinished?.totalTokens ?? 0;
          if (totalTokens > 0) {
            final usage = _liveUsage.putIfAbsent(sessionId, () => UsageInfo());
            usage.totalTokens = totalTokens;
            usage.inputTokens = event.runFinished?.inputTokens ?? 0;
            usage.outputTokens = event.runFinished?.outputTokens ?? 0;
            usage.cachedReadTokens = event.runFinished?.cachedReadTokens ?? 0;
            usage.cachedWriteTokens = event.runFinished?.cachedWriteTokens ?? 0;
          }

          // Persist status + cost
          final dbFields = <String, dynamic>{
            'updated_at': event.at.toIso8601String(),
            'status': existing.status.value,
            'is_read': existing.isRead ? 1 : 0,
          };
          final usage = _liveUsage[sessionId];
          if (usage != null &&
              (usage.costAmount > 0 || usage.totalTokens > 0)) {
            dbFields['cost_amount'] = usage.costAmount;
            dbFields['cost_currency'] = usage.costCurrency;
            dbFields['total_tokens'] = usage.totalTokens;
            existing.cost = CostInfo(
              costAmount: usage.costAmount,
              costCurrency: usage.costCurrency,
              totalTokens: usage.totalTokens,
            );
          }
          SessionDatabase.updateFields(sessionId, dbFields);

          _sessionsChangedController.add(null);

          if (event.type == EventType.runFinished &&
              existing.title.isEmpty &&
              event.machineId.isNotEmpty) {
            final runtime = existing.metadata?['runtime'] as String? ?? '';
            unawaited(
              backfillMissingTitles(
                event.machineId,
                sessionIds: [sessionId],
                runtime: runtime,
              ),
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
        if (existing != null) {
          final modeId = event.modeChange?.currentModeId;
          if (modeId != null) {
            final metadata = <String, dynamic>{...?existing.metadata};
            metadata['mode'] = modeId;
            existing.metadata = metadata;
            existing.updatedAt = event.at;
            SessionDatabase.updateFields(sessionId, {'mode': modeId});
            _sessionsChangedController.add(null);
          }
        }
      case EventType.modelChanged:
        final existing = sessions[sessionId];
        if (existing != null) {
          final currentValue = event.configChange?.currentValue;
          if (currentValue != null) {
            existing.model = currentValue;
            existing.updatedAt = event.at;
            SessionDatabase.updateFields(sessionId, {'model': currentValue});
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
          final eventType = EventType.fromValue(eventJson['type'] as String?);
          if (eventType == null) continue;
          final event = switch (eventType) {
            EventType.approvalRequested || EventType.approvalReplied =>
              ApprovalEventMapper.parseEvent(eventJson, machineId),
            EventType.toolStarted ||
            EventType.toolUpdated ||
            EventType.toolCompleted ||
            EventType.toolFailed => ToolEventMapper.parseEvent(
              eventJson,
              machineId,
            ),
            EventType.messageDelta || EventType.reasoning =>
              MessageEventMapper.parseEvent(eventJson, machineId),
            EventType.runFinished => RunEventMapper.parseRunFinished(
              eventJson,
              machineId,
            ),
            EventType.modeChanged || EventType.modelChanged =>
              SessionConfigEventMapper.parseEvent(eventJson, machineId),
            _ => AgentEvent.fromJson(eventJson, machineId),
          };
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
  /// Uses session.resolve to consume the daemon's authoritative status snapshot.
  /// Sessions not returned are considered gone from this daemon instance.
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
      final resolvedStatuses = <String, SessionStatus>{};
      for (final item in list) {
        if (item is Map) {
          final id = (item['sessionId'] as String?) ?? '';
          if (id.isEmpty) continue;
          resolvedStatuses[id] = SessionStatus.fromValue(
            item['status'] as String? ?? 'idle',
          );
        }
      }

      var changed = false;
      for (final session in stale) {
        final newStatus = resolvedStatuses[session.id] ?? SessionStatus.done;

        if (session.status != newStatus) {
          session.status = newStatus;
          session.updatedAt = DateTime.now();
          if (newStatus == SessionStatus.done &&
              session.isRead &&
              !_viewingSessions.contains(session.id)) {
            session.isRead = false;
          }
          await SessionDatabase.updateFields(session.id, {
            'status': newStatus.value,
            'updated_at': session.updatedAt.toIso8601String(),
            'is_read': session.isRead ? 1 : 0,
          });
          // Clear stale approvals for this session
          pendingApprovals.removeWhere((_, a) => a.sessionId == session.id);
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
        final approval = ApprovalEventMapper.parseApproval(
          json as Map<String, dynamic>,
        );
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
        params: {
          'sessionIds': targetIds,
          if (runtime != null && runtime.isNotEmpty) 'runtime': runtime,
        },
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
        final status = SessionStatus.fromValue(
          json['status'] as String? ?? 'idle',
        );
        final updatedAt = _parseRpcTime(json['updatedAt']) ?? DateTime.now();
        final existing = sessions[sessionId];

        if (existing == null) {
          final session = AgentSession(
            id: sessionId,
            title: title,
            status: status,
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
  Future<void> registerSession(AgentSession session) async {
    sessions[session.id] = session;
    await SessionDatabase.insertSession(session);
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

  /// Mark a session as read. Called when user opens a chat.
  void markAsRead(String sessionId) {
    final session = sessions[sessionId];
    if (session != null && !session.isRead) {
      session.isRead = true;
      SessionDatabase.updateFields(sessionId, {'is_read': 1});
      _sessionsChangedController.add(null);
    }
  }

  /// Track that user is currently viewing this session.
  void markViewing(String sessionId) {
    _viewingSessions.add(sessionId);
  }

  /// Track that user left this session's chat.
  void markNotViewing(String sessionId) {
    _viewingSessions.remove(sessionId);
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
