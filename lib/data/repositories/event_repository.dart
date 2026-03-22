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
import '../services/ws/event_envelope_parser.dart';
import '../services/ws/models/ws_models.dart';
import '../services/ws/ws_types.dart';
import 'replay_cursor_repository.dart';
import 'session_chat_cache_repository.dart';
import 'ws_session_repository.dart';

enum ResyncOutcome { complete, incomplete, failed, noCursor, reset }

class ResyncResult {
  final ResyncOutcome outcome;
  final int lastSeqUsed;
  final int highestSeqApplied;
  final int? streamEpoch;
  final Object? error;

  const ResyncResult({
    required this.outcome,
    required this.lastSeqUsed,
    required this.highestSeqApplied,
    this.streamEpoch,
    this.error,
  });
}

class RepairStepResult {
  final bool ok;
  final bool changed;
  final Object? error;

  const RepairStepResult.success({this.changed = false})
    : ok = true,
      error = null;

  const RepairStepResult.failure(this.error, {this.changed = false})
    : ok = false;
}

class _ResyncFenceState {
  final bufferedEvents = <AgentEvent>[];
}

bool eventAffectsTranscript(EventType? type) {
  switch (type) {
    case EventType.messageDelta:
    case EventType.reasoning:
    case EventType.toolStarted:
    case EventType.toolUpdated:
    case EventType.toolCompleted:
    case EventType.toolFailed:
    case EventType.approvalRequested:
    case EventType.approvalReplied:
    case EventType.planUpdated:
    case EventType.runFailed:
      return true;
    case EventType.sessionStatus:
    case EventType.usageUpdate:
    case EventType.runFinished:
    case EventType.modeChanged:
    case EventType.modelChanged:
    case EventType.historyComplete:
    case null:
      return false;
  }
}

class EventRepository {
  final WsSessionRepository _wsRepo;
  final ReplayCursorRepository _replayCursors;
  final SessionChatCacheRepository? _chatCacheRepo;
  final Duration _replayCursorPersistDebounce;
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

  /// Last persisted replay cursor per machine (for resync after reconnect).
  final Map<String, ReplayCursor> _replayCursorByMachine = {};
  final Map<String, Future<void>> _replayCursorBootstrapByMachine = {};
  final Map<String, int> _bootstrapObservedSeqByMachine = {};
  final Map<String, _ResyncFenceState> _resyncFenceByMachine = {};
  final Map<String, int> _transcriptSeqBySession = {};
  Timer? _replayCursorPersistTimer;
  bool _replayCursorDirty = false;

  EventRepository({
    required WsSessionRepository wsRepo,
    ReplayCursorRepository? replayCursors,
    SessionChatCacheRepository? chatCacheRepo,
    Duration replayCursorPersistDebounce = const Duration(milliseconds: 250),
  }) : _wsRepo = wsRepo,
       _replayCursors = replayCursors ?? ReplayCursorRepository(),
       _chatCacheRepo = chatCacheRepo,
       _replayCursorPersistDebounce = replayCursorPersistDebounce {
    _sub = _wsRepo.events.listen(_onWsEvent);
  }

  Stream<AgentEvent> get events => _eventController.stream;

  /// Emits only when session metadata changes (status, runFinished, runFailed, register).
  Stream<void> get sessionsChanged => _sessionsChangedController.stream;

  int lastSeqFor(String machineId) =>
      _replayCursorByMachine[machineId]?.lastSeq ?? 0;

  int transcriptWatermarkFor(String sessionId) =>
      _transcriptSeqBySession[sessionId] ?? 0;

  static String _preferNonEmpty(String primary, String fallback) {
    return primary.isNotEmpty ? primary : fallback;
  }

  static String? _preferMode(String? primary, String? fallback) {
    if (primary != null && primary.isNotEmpty) return primary;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  AgentSession _mergeSessionSnapshot(
    AgentSession? existing,
    AgentSession incoming,
    String eventMachineId,
  ) {
    if (existing != null) {
      if (incoming.title.isEmpty) {
        incoming.title = existing.title;
      }
      incoming.model ??= existing.model;
      incoming.cost ??= existing.cost;
      incoming.runtime = _preferNonEmpty(incoming.runtime, existing.runtime);
      incoming.cwd = _preferNonEmpty(incoming.cwd, existing.cwd);
      incoming.mode = _preferMode(incoming.mode, existing.mode);
      incoming.isRead = existing.isRead;
    }

    incoming.machineId = _preferNonEmpty(
      eventMachineId,
      _preferNonEmpty(incoming.machineId, existing?.machineId ?? ''),
    );

    return incoming;
  }

  /// Load all sessions from SQLite into memory. Call once at startup.
  Future<void> init() async {
    final rows = await SessionDatabase.loadAll();
    for (final s in rows) {
      sessions[s.id] = s;
    }
    _replayCursorByMachine
      ..clear()
      ..addAll(await _replayCursors.loadAll());
  }

  void _onWsEvent(WsEvent wsEvent) {
    if (wsEvent.type != WsMessageType.event.value) {
      return;
    }

    final event = _parseWsEvent(wsEvent);
    if (event == null || event.type == null) return;

    final fence = _resyncFenceByMachine[event.machineId];
    if (fence != null) {
      fence.bufferedEvents.add(event);
      return;
    }

    _trackLiveReplayCursor(event);

    _processEvent(event);
  }

  void _trackLiveReplayCursor(AgentEvent event) {
    if (event.machineId.isEmpty || event.seq <= 0) {
      return;
    }
    final existing = _replayCursorByMachine[event.machineId];
    if (existing == null) {
      final observedSeq = _bootstrapObservedSeqByMachine[event.machineId] ?? 0;
      if (event.seq > observedSeq) {
        _bootstrapObservedSeqByMachine[event.machineId] = event.seq;
      }
      _ensureReplayCursorBootstrapped(event.machineId);
      return;
    }
    if (event.seq <= existing.lastSeq) {
      return;
    }
    _setReplayCursor(
      event.machineId,
      ReplayCursor(streamEpoch: existing.streamEpoch, lastSeq: event.seq),
      persist: false,
    );
  }

  void _ensureReplayCursorBootstrapped(String machineId) {
    if (_replayCursorBootstrapByMachine.containsKey(machineId)) {
      return;
    }
    final future = _bootstrapReplayCursor(machineId);
    _replayCursorBootstrapByMachine[machineId] = future;
    future.whenComplete(() {
      if (identical(_replayCursorBootstrapByMachine[machineId], future)) {
        _replayCursorBootstrapByMachine.remove(machineId);
      }
    });
  }

  Future<void> _bootstrapReplayCursor(String machineId) async {
    try {
      final response = await _wsRepo.resyncEvents(
        machineId: machineId,
        lastSeq: 0,
      );
      final responseEpoch = response.streamEpoch;
      if (responseEpoch <= 0) {
        debugPrint(
          '[ReplayCursor] bootstrap machine=$machineId skipped due to invalid replay epoch',
        );
        return;
      }

      final observedSeq = _bootstrapObservedSeqByMachine[machineId] ?? 0;
      final targetSeq = observedSeq > response.replayedThroughSeq
          ? observedSeq
          : response.replayedThroughSeq;
      final existing = _replayCursorByMachine[machineId];
      if (existing != null) {
        if (existing.streamEpoch != responseEpoch ||
            existing.lastSeq >= targetSeq) {
          return;
        }
      }

      _setReplayCursor(
        machineId,
        ReplayCursor(streamEpoch: responseEpoch, lastSeq: targetSeq),
      );
      debugPrint(
        '[ReplayCursor] bootstrap machine=$machineId status=${response.status} '
        'streamEpoch=$responseEpoch targetSeq=$targetSeq',
      );
    } catch (e) {
      debugPrint('[ReplayCursor] bootstrap machine=$machineId failed: $e');
    } finally {
      _bootstrapObservedSeqByMachine.remove(machineId);
    }
  }

  void _setReplayCursor(
    String machineId,
    ReplayCursor cursor, {
    bool persist = true,
  }) {
    final existing = _replayCursorByMachine[machineId];
    if (existing != null &&
        existing.streamEpoch == cursor.streamEpoch &&
        existing.lastSeq == cursor.lastSeq) {
      return;
    }
    _replayCursorByMachine[machineId] = cursor;
    if (persist) {
      _scheduleReplayCursorPersist();
    }
  }

  void _scheduleReplayCursorPersist() {
    _replayCursorDirty = true;
    _replayCursorPersistTimer?.cancel();
    _replayCursorPersistTimer = Timer(_replayCursorPersistDebounce, () {
      unawaited(_persistReplayCursors());
    });
  }

  Future<void> _persistReplayCursors() async {
    if (!_replayCursorDirty) return;
    _replayCursorDirty = false;
    await _replayCursors.saveAll(_replayCursorByMachine);
  }

  void _processEvent(AgentEvent event) {
    _markTranscriptCacheStale(event);
    _trackTranscriptWatermark(event);

    // Update lightweight session metadata
    _updateSessionMeta(event);

    // Track pending approvals
    _updateApprovals(event);

    _eventController.add(event);
  }

  void _markTranscriptCacheStale(AgentEvent event) {
    final sessionId = event.sessionId;
    if (_chatCacheRepo == null || sessionId == null || sessionId.isEmpty) {
      return;
    }

    if (eventAffectsTranscript(event.type)) {
      unawaited(_chatCacheRepo.markSessionCacheStale(sessionId));
    }
  }

  void _trackTranscriptWatermark(AgentEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    if (!eventAffectsTranscript(event.type) || event.seq <= 0) {
      return;
    }
    final current = _transcriptSeqBySession[sessionId] ?? 0;
    if (event.seq > current) {
      _transcriptSeqBySession[sessionId] = event.seq;
    }
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
          final incoming = _mergeSessionSnapshot(
            existing,
            event.session!,
            event.machineId,
          );
          sessions[sessionId] = incoming;

          // Persist title, status, model changes
          final dbFields = <String, dynamic>{
            'updated_at': incoming.updatedAt.toIso8601String(),
            'machine_id': incoming.machineId,
            'runtime': incoming.runtime,
            'cwd': incoming.cwd,
          };
          if (incoming.title.isNotEmpty) {
            dbFields['title'] = incoming.title;
          }
          dbFields['status'] = incoming.status.value;
          if (incoming.model != null) {
            dbFields['model'] = incoming.model;
          }
          if (incoming.mode != null) {
            dbFields['mode'] = incoming.mode;
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
            final runtime = existing.runtime;
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
            existing.mode = modeId;
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
  ///
  /// The daemon decides whether a cursor is valid for the current replay stream.
  Future<ResyncResult> resync(String machineId) async {
    final cursor = _replayCursorByMachine[machineId];
    final lastSeq = cursor?.lastSeq ?? 0;
    final streamEpoch = cursor?.streamEpoch;
    final fence = _ResyncFenceState();
    _resyncFenceByMachine[machineId] = fence;

    try {
      debugPrint(
        '[Resync] machine=$machineId start lastSeq=$lastSeq streamEpoch=$streamEpoch',
      );
      final response = await _wsRepo.resyncEvents(
        machineId: machineId,
        lastSeq: lastSeq,
        streamEpoch: streamEpoch,
      );

      final responseEpoch = response.streamEpoch;
      if (responseEpoch <= 0) {
        debugPrint(
          '[Resync] machine=$machineId outcome=failed-invalid-epoch '
          'lastSeq=$lastSeq streamEpoch=$streamEpoch',
        );
        return ResyncResult(
          outcome: ResyncOutcome.failed,
          lastSeqUsed: lastSeq,
          highestSeqApplied: lastSeq,
          streamEpoch: streamEpoch,
          error: const FormatException('Invalid replay epoch'),
        );
      }

      if (cursor == null) {
        _setReplayCursor(
          machineId,
          ReplayCursor(streamEpoch: responseEpoch, lastSeq: 0),
        );
      }

      debugPrint(
        '[Resync] machine=$machineId response events=${response.events.length} '
        'status=${response.status} streamEpoch=$responseEpoch '
        'replayedThroughSeq=${response.replayedThroughSeq}',
      );

      switch (response.status) {
        case ReplayResyncStatus.reset:
          _setReplayCursor(
            machineId,
            ReplayCursor(streamEpoch: responseEpoch, lastSeq: 0),
          );
          _drainResyncFence(
            machineId,
            fence,
            replayedThroughSeq: response.replayedThroughSeq,
          );
          debugPrint(
            '[Resync] machine=$machineId outcome=${cursor == null ? 'noCursor' : 'reset'} '
            'lastSeq=$lastSeq streamEpoch=$responseEpoch',
          );
          return ResyncResult(
            outcome: cursor == null
                ? ResyncOutcome.noCursor
                : ResyncOutcome.reset,
            lastSeqUsed: lastSeq,
            highestSeqApplied: lastSeq,
            streamEpoch: responseEpoch,
          );
        case ReplayResyncStatus.gap:
          _drainResyncFence(
            machineId,
            fence,
            replayedThroughSeq: response.replayedThroughSeq,
          );
          debugPrint(
            '[Resync] machine=$machineId outcome=incomplete '
            'lastSeq=$lastSeq streamEpoch=$responseEpoch '
            'replayedThroughSeq=${response.replayedThroughSeq}',
          );
          return ResyncResult(
            outcome: ResyncOutcome.incomplete,
            lastSeqUsed: lastSeq,
            highestSeqApplied: lastSeq,
            streamEpoch: responseEpoch,
          );
        case ReplayResyncStatus.ok:
          var highestSeqApplied = lastSeq;
          if (streamEpoch != responseEpoch || cursor == null) {
            _setReplayCursor(
              machineId,
              ReplayCursor(streamEpoch: responseEpoch, lastSeq: lastSeq),
            );
          }
          for (final event in response.events) {
            _processEvent(event);
            if (event.seq > highestSeqApplied) {
              highestSeqApplied = event.seq;
            }
            if (event.seq > 0) {
              _setReplayCursor(
                machineId,
                ReplayCursor(streamEpoch: responseEpoch, lastSeq: event.seq),
              );
            }
          }
          if (response.replayedThroughSeq > highestSeqApplied) {
            highestSeqApplied = response.replayedThroughSeq;
            _setReplayCursor(
              machineId,
              ReplayCursor(
                streamEpoch: responseEpoch,
                lastSeq: response.replayedThroughSeq,
              ),
            );
          }
          _drainResyncFence(
            machineId,
            fence,
            replayedThroughSeq: highestSeqApplied,
          );
          debugPrint(
            '[Resync] machine=$machineId outcome=complete '
            'lastSeq=$lastSeq streamEpoch=$responseEpoch '
            'highestSeqApplied=$highestSeqApplied',
          );
          return ResyncResult(
            outcome: ResyncOutcome.complete,
            lastSeqUsed: lastSeq,
            highestSeqApplied: highestSeqApplied,
            streamEpoch: responseEpoch,
          );
      }
    } catch (e) {
      debugPrint(
        '[Resync] machine=$machineId outcome=failed lastSeq=$lastSeq '
        'streamEpoch=$streamEpoch error=$e',
      );
      return ResyncResult(
        outcome: ResyncOutcome.failed,
        lastSeqUsed: lastSeq,
        highestSeqApplied: lastSeq,
        streamEpoch: streamEpoch,
        error: e,
      );
    } finally {
      final currentFence = _resyncFenceByMachine[machineId];
      if (identical(currentFence, fence)) {
        _resyncFenceByMachine.remove(machineId);
        for (final event in fence.bufferedEvents) {
          _trackLiveReplayCursor(event);
          _processEvent(event);
        }
      }
    }
  }

  void _drainResyncFence(
    String machineId,
    _ResyncFenceState fence, {
    required int replayedThroughSeq,
  }) {
    if (!identical(_resyncFenceByMachine[machineId], fence)) {
      return;
    }
    _resyncFenceByMachine.remove(machineId);
    for (final event in fence.bufferedEvents) {
      if (event.seq > 0 && event.seq <= replayedThroughSeq) {
        continue;
      }
      _trackLiveReplayCursor(event);
      _processEvent(event);
    }
    fence.bufferedEvents.clear();
  }

  AgentEvent? _parseWsEvent(WsEvent wsEvent) {
    try {
      final event = EventEnvelopeParser.parse(wsEvent);
      if (event == null) {
        debugPrint(
          '[EventRepo] unsupported event type: ${EventEnvelopeParser.rawEventType(wsEvent)}',
        );
      }
      return event;
    } catch (e) {
      debugPrint(
        '[EventRepo] failed to parse ${EventEnvelopeParser.rawEventType(wsEvent)}: $e',
      );
      return null;
    }
  }

  /// Reconcile stale running/waitingApproval sessions after reconnect.
  /// Uses session.resolve to consume the daemon's authoritative status snapshot.
  /// Sessions not returned are considered gone from this daemon instance.
  Future<RepairStepResult> reconcileSessionStatus(String machineId) async {
    // Collect all running/waitingApproval sessions for this machine
    final stale = sessions.values.where((s) {
      return s.machineId == machineId &&
          (s.status == SessionStatus.running ||
              s.status == SessionStatus.waitingApproval);
    }).toList();

    if (stale.isEmpty) {
      return const RepairStepResult.success();
    }

    try {
      final resolvedSessions = await _wsRepo.resolveSessions(
        machineId: machineId,
        sessionIds: stale.map((s) => s.id),
      );
      final resolvedStatuses = <String, SessionStatus>{};
      for (final item in resolvedSessions) {
        resolvedStatuses[item.sessionId] = item.status;
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
      return RepairStepResult.success(changed: changed);
    } catch (e) {
      debugPrint('[EventRepo] reconcileSessionStatus failed: $e');
      return RepairStepResult.failure(e);
    }
  }

  /// Fetch pending approvals from daemon via RPC (fallback for ring buffer overflow).
  Future<RepairStepResult> fetchPendingApprovals(String machineId) async {
    try {
      final approvals = await _wsRepo.listPendingApprovals(
        machineId: machineId,
      );
      final fetchedIds = approvals.map((approval) => approval.id).toSet();
      final existingMachineApprovalIds = pendingApprovals.entries
          .where((entry) {
            final session = sessions[entry.value.sessionId];
            return session?.machineId == machineId;
          })
          .map((entry) => entry.key)
          .toSet();
      var changed = false;

      for (final approvalId in existingMachineApprovalIds.difference(
        fetchedIds,
      )) {
        pendingApprovals.remove(approvalId);
        changed = true;
      }

      for (final approval in approvals) {
        final existing = pendingApprovals[approval.id];
        if (existing != approval) {
          changed = true;
        }
        pendingApprovals[approval.id] = approval;
        // Also update session status
        final session = sessions[approval.sessionId];
        if (session != null &&
            session.status != SessionStatus.waitingApproval) {
          session.status = SessionStatus.waitingApproval;
          SessionDatabase.updateFields(approval.sessionId, {
            'status': 'waiting_approval',
          });
          changed = true;
        }
      }
      if (changed) {
        _sessionsChangedController.add(null);
      }
      return RepairStepResult.success(changed: changed);
    } catch (e) {
      debugPrint('[EventRepo] fetchPendingApprovals failed: $e');
      return RepairStepResult.failure(e);
    }
  }

  /// Resolve missing session titles via daemon-side session/list.
  /// When [runtime] is provided, only sessions matching that runtime are
  /// included in the RPC call. Sessions from a different runtime would not
  /// be resolvable by the current daemon anyway.
  Future<RepairStepResult> backfillMissingTitles(
    String machineId, {
    List<String>? sessionIds,
    String? runtime,
  }) async {
    try {
      final targetIds =
          sessionIds ??
          sessions.values
              .where((s) {
                final sameMachine = s.machineId == machineId;
                if (!sameMachine || s.title.isNotEmpty) return false;
                // Skip sessions from a different runtime — the daemon can't
                // resolve them.
                if (runtime != null && runtime.isNotEmpty) {
                  final sr = s.runtime;
                  if (sr.isNotEmpty && sr != runtime) return false;
                }
                return true;
              })
              .map((s) => s.id)
              .toList();
      if (targetIds.isEmpty) {
        return const RepairStepResult.success();
      }

      final resolvedSessions = await _wsRepo.resolveSessions(
        machineId: machineId,
        sessionIds: targetIds,
        runtime: runtime,
      );
      var changed = false;

      for (final item in resolvedSessions) {
        final sessionId = item.sessionId;
        final title = item.title;
        final status = item.status;
        final updatedAt = item.updatedAt ?? DateTime.now();
        final existing = sessions[sessionId];

        if (existing == null) {
          if (runtime != null && runtime.isNotEmpty) {
            final session = AgentSession(
              id: sessionId,
              title: title,
              status: status,
              machineId: machineId,
              runtime: runtime,
              cwd: '',
              createdAt: updatedAt,
              updatedAt: updatedAt,
            );
            sessions[sessionId] = session;
            await SessionDatabase.insertSession(session);
            changed = true;
          }
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

        if (existing.machineId != machineId) {
          existing.machineId = machineId;
          dirty = true;
        }
        if (runtime != null &&
            runtime.isNotEmpty &&
            existing.runtime != runtime) {
          existing.runtime = runtime;
          dirty = true;
        }
        if (!dirty) continue;

        final dbFields = <String, dynamic>{
          'machine_id': machineId,
          'runtime': existing.runtime,
          'cwd': existing.cwd,
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
      return RepairStepResult.success(changed: changed);
    } catch (e) {
      debugPrint('[EventRepo] backfillMissingTitles failed: $e');
      return RepairStepResult.failure(e);
    }
  }

  /// Reply to a pending approval. Shared by ChatVM and ActiveTabVM.
  Future<void> replyApproval({
    required String machineId,
    required String sessionId,
    required String requestId,
    required String optionId,
  }) async {
    await _wsRepo.replyApproval(
      machineId: machineId,
      sessionId: sessionId,
      requestId: requestId,
      optionId: optionId,
    );
  }

  /// Register a session created via RPC (before any events arrive).
  Future<void> registerSession(AgentSession session) async {
    sessions[session.id] = session;
    await SessionDatabase.insertSession(session);
    _sessionsChangedController.add(null);
  }

  AgentSession? sessionById(String sessionId) => sessions[sessionId];

  List<ApprovalRequest> approvalsForSession(String sessionId) {
    return pendingApprovals.values
        .where((approval) => approval.sessionId == sessionId)
        .toList();
  }

  /// Update a session's status from the UI (e.g. optimistic "running" on send).
  void setSessionStatus(String sessionId, SessionStatus status) {
    final existing = sessions[sessionId];
    if (existing != null && existing.status != status) {
      existing.status = status;
      SessionDatabase.updateFields(sessionId, {'status': status.value});
      _sessionsChangedController.add(null);
    }
  }

  /// Persist a session mode acknowledged by the daemon, even if the async
  /// config-change event arrives later or not at all.
  void setSessionMode(String sessionId, String? modeId) {
    final existing = sessions[sessionId];
    if (existing == null) return;

    final normalized = (modeId ?? '').trim();
    final nextMode = normalized.isEmpty ? null : normalized;
    if (existing.mode == nextMode) return;

    existing.mode = nextMode;
    existing.updatedAt = DateTime.now();
    SessionDatabase.updateFields(sessionId, {
      'mode': nextMode ?? '',
      'updated_at': existing.updatedAt.toIso8601String(),
    });
    _sessionsChangedController.add(null);
  }

  /// Persist a session model acknowledged by the daemon, even if the async
  /// config-change event arrives later or not at all.
  void setSessionModel(String sessionId, String? model) {
    final existing = sessions[sessionId];
    if (existing == null) return;

    final normalized = (model ?? '').trim();
    final nextModel = normalized.isEmpty ? null : normalized;
    if (existing.model == nextModel) return;

    existing.model = nextModel;
    existing.updatedAt = DateTime.now();
    SessionDatabase.updateFields(sessionId, {
      'model': nextModel,
      'updated_at': existing.updatedAt.toIso8601String(),
    });
    _sessionsChangedController.add(null);
  }

  Future<void> persistSessionRuntimeAndCwd(
    String sessionId, {
    required String runtime,
    required String cwd,
  }) async {
    final existing = sessions[sessionId];
    if (existing == null) {
      return;
    }

    var changed = false;
    if (runtime.isNotEmpty && existing.runtime != runtime) {
      existing.runtime = runtime;
      changed = true;
    }
    if (cwd.isNotEmpty && existing.cwd != cwd) {
      existing.cwd = cwd;
      changed = true;
    }
    if (!changed) {
      return;
    }

    existing.updatedAt = DateTime.now();
    await SessionDatabase.updateFields(sessionId, {
      'runtime': existing.runtime,
      'cwd': existing.cwd,
      'updated_at': existing.updatedAt.toIso8601String(),
    });
    _sessionsChangedController.add(null);
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
    _replayCursorPersistTimer?.cancel();
    unawaited(_persistReplayCursors());
    _sub.cancel();
    _eventController.close();
    _sessionsChangedController.close();
  }
}
