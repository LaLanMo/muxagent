import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../domain/approval.dart';
import '../../domain/cost_info.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/model_info.dart';
import '../../domain/mode_option.dart';
import '../../domain/session.dart';
import '../../domain/session_config_change.dart';
import '../../domain/session_config_snapshot.dart';
import '../../domain/usage_info.dart';
import '../local/session_database.dart';
import '../services/local/session_config_snapshot_codec.dart';
import '../services/ws/event_envelope_parser.dart';
import '../services/ws/models/ws_models.dart';
import '../services/ws/rpc_result_mapper.dart';
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
  final Map<String, int> _configRevisionBySession = {};
  final Map<String, Future<void>> _configRefreshBySession = {};
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

  static bool _hasConfigSnapshotData(SessionConfigSnapshot snapshot) {
    return snapshot.modeConfigId != null ||
        snapshot.currentMode != null ||
        snapshot.availableModes.isNotEmpty ||
        snapshot.modelConfigId != null ||
        snapshot.currentModel != null ||
        snapshot.availableModels.isNotEmpty;
  }

  static ModeOption? _resolveModeOption({
    required String? modeId,
    required List<ModeOption> availableModes,
    ModeOption? fallback,
  }) {
    final normalized = (modeId ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final option in availableModes) {
      if (option.id == normalized) {
        return option;
      }
    }
    if (fallback != null && fallback.id == normalized) {
      return fallback;
    }
    return ModeOption.fromId(normalized);
  }

  static List<ModeOption> _modeOptionsFromValues(
    String runtimeId,
    List<SessionConfigValue> values,
  ) {
    return ModeOption.orderedForRuntime(
      runtimeId,
      values.map(
        (value) => ModeOption.fromConfigValue(
          value: value.value,
          name: value.name,
          description: value.description,
        ),
      ),
    );
  }

  static List<ModelInfo> _modelOptionsFromValues(
    List<SessionConfigValue> values,
  ) {
    return values
        .map(
          (value) => ModelInfo.fromConfigValue(
            value: value.value,
            name: value.name,
            description: value.description,
          ),
        )
        .toList();
  }

  int _configRevision(String sessionId) =>
      _configRevisionBySession[sessionId] ?? 0;

  void _bumpConfigRevision(String sessionId) {
    _configRevisionBySession[sessionId] = _configRevision(sessionId) + 1;
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
      if (!_hasConfigSnapshotData(incoming.configSnapshot)) {
        incoming.configSnapshot = existing.configSnapshot;
      }
      incoming.model ??= incoming.configSnapshot.currentModel ?? existing.model;
      incoming.model ??= existing.model;
      incoming.cost ??= existing.cost;
      incoming.runtime = _preferNonEmpty(incoming.runtime, existing.runtime);
      incoming.cwd = _preferNonEmpty(incoming.cwd, existing.cwd);
      incoming.mode = _preferMode(
        incoming.configSnapshot.currentMode?.id,
        _preferMode(incoming.mode, existing.mode),
      );
      incoming.isRead = existing.isRead;
    }

    incoming.machineId = _preferNonEmpty(
      eventMachineId,
      _preferNonEmpty(incoming.machineId, existing?.machineId ?? ''),
    );

    return incoming;
  }

  SessionConfigSnapshot sessionConfigSnapshotFor(String sessionId) {
    return sessions[sessionId]?.configSnapshot ?? const SessionConfigSnapshot();
  }

  int sessionConfigRevisionFor(String sessionId) => _configRevision(sessionId);

  Future<void> _persistSessionConfigSnapshot(
    AgentSession session, {
    bool includeUpdatedAt = true,
    bool includeRuntime = false,
    bool includeCwd = false,
    bool includeTitle = false,
  }) {
    final fields = <String, dynamic>{
      'mode': session.mode ?? '',
      'model': session.model,
      'config_snapshot_json': jsonEncode(
        serializeSessionConfigSnapshot(session.configSnapshot),
      ),
    };
    if (includeUpdatedAt) {
      fields['updated_at'] = session.updatedAt.toIso8601String();
    }
    if (includeRuntime) {
      fields['runtime'] = session.runtime;
    }
    if (includeCwd) {
      fields['cwd'] = session.cwd;
    }
    if (includeTitle) {
      fields['title'] = session.title;
    }
    return SessionDatabase.updateFields(session.id, fields);
  }

  void _applySessionConfigSnapshotToSession(
    AgentSession session,
    SessionConfigSnapshot snapshot, {
    DateTime? updatedAt,
    bool notify = true,
    bool includeRuntime = false,
    bool includeCwd = false,
    bool includeTitle = false,
  }) {
    session.configSnapshot = snapshot;
    session.mode = snapshot.currentMode?.id;
    session.model = snapshot.currentModel;
    if (updatedAt != null) {
      session.updatedAt = updatedAt;
    }
    _bumpConfigRevision(session.id);
    unawaited(
      _persistSessionConfigSnapshot(
        session,
        includeUpdatedAt: updatedAt != null,
        includeRuntime: includeRuntime,
        includeCwd: includeCwd,
        includeTitle: includeTitle,
      ),
    );
    if (notify) {
      _sessionsChangedController.add(null);
    }
  }

  void _applyModeChangeToSession(
    AgentSession session,
    SessionModeChange change,
    DateTime updatedAt,
  ) {
    final runtime = session.runtime;
    final existingSnapshot = session.configSnapshot;
    final availableModes = change.values.isNotEmpty
        ? _modeOptionsFromValues(runtime, change.values)
        : existingSnapshot.availableModes;
    final currentMode = _resolveModeOption(
      modeId: change.currentModeId,
      availableModes: availableModes,
      fallback: existingSnapshot.currentMode,
    );
    final nextSnapshot = existingSnapshot.copyWith(
      modeConfigId: change.configId,
      currentMode: currentMode,
      clearCurrentMode: currentMode == null,
      availableModes: availableModes,
    );
    _applySessionConfigSnapshotToSession(
      session,
      nextSnapshot,
      updatedAt: updatedAt,
    );
  }

  void _applyModelChangeToSession(
    AgentSession session,
    SessionConfigChange change,
    DateTime updatedAt,
  ) {
    final existingSnapshot = session.configSnapshot;
    final availableModels = change.values.isNotEmpty
        ? _modelOptionsFromValues(change.values)
        : existingSnapshot.availableModels;
    final nextSnapshot = existingSnapshot.copyWith(
      modelConfigId: change.configId,
      currentModel: change.currentValue,
      clearCurrentModel: change.currentValue.isEmpty,
      availableModels: availableModels,
    );
    _applySessionConfigSnapshotToSession(
      session,
      nextSnapshot,
      updatedAt: updatedAt,
    );
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
      final head = await _wsRepo.fetchReplayHead(machineId: machineId);
      final responseEpoch = head.streamEpoch;
      if (responseEpoch <= 0) {
        debugPrint(
          '[ReplayCursor] bootstrap machine=$machineId skipped due to invalid replay epoch',
        );
        return;
      }

      final observedSeq = _bootstrapObservedSeqByMachine[machineId] ?? 0;
      final targetSeq = observedSeq > head.replayedThroughSeq
          ? observedSeq
          : head.replayedThroughSeq;
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
        '[ReplayCursor] bootstrap machine=$machineId '
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

          if (existing == null) {
            unawaited(SessionDatabase.insertSession(incoming));
          } else {
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
            unawaited(SessionDatabase.updateFields(sessionId, dbFields));
          }

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
        final modeChange = event.modeChange;
        if (existing != null && modeChange != null) {
          _applyModeChangeToSession(existing, modeChange, event.at);
        }
      case EventType.modelChanged:
        final existing = sessions[sessionId];
        final configChange = event.configChange;
        if (existing != null && configChange != null) {
          _applyModelChangeToSession(existing, configChange, event.at);
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
    var highestSeqApplied = lastSeq;
    var highestSeqAccountedFor = lastSeq;
    var fenceDrained = false;
    _resyncFenceByMachine[machineId] = fence;

    void drainFence(int replayedThroughSeq) {
      if (replayedThroughSeq > highestSeqAccountedFor) {
        highestSeqAccountedFor = replayedThroughSeq;
      }
      if (fenceDrained) {
        return;
      }
      fenceDrained = true;
      _drainResyncFence(
        machineId,
        fence,
        replayedThroughSeq: highestSeqAccountedFor,
      );
    }

    try {
      debugPrint(
        '[Resync] machine=$machineId start lastSeq=$lastSeq streamEpoch=$streamEpoch',
      );
      if (cursor == null) {
        final head = await _wsRepo.fetchReplayHead(machineId: machineId);
        final observedSeq = _bootstrapObservedSeqByMachine[machineId] ?? 0;
        final targetSeq = observedSeq > head.replayedThroughSeq
            ? observedSeq
            : head.replayedThroughSeq;
        highestSeqAccountedFor = targetSeq;
        _setReplayCursor(
          machineId,
          ReplayCursor(streamEpoch: head.streamEpoch, lastSeq: targetSeq),
        );
        drainFence(targetSeq);
        debugPrint(
          '[Resync] machine=$machineId outcome=noCursor '
          'streamEpoch=${head.streamEpoch} replayedThroughSeq=${head.replayedThroughSeq}',
        );
        return ResyncResult(
          outcome: ResyncOutcome.noCursor,
          lastSeqUsed: 0,
          highestSeqApplied: 0,
          streamEpoch: head.streamEpoch,
        );
      }
      int? responseEpoch;
      final response = await _wsRepo.consumeResyncPages(
        machineId: machineId,
        lastSeq: lastSeq,
        streamEpoch: streamEpoch,
        onPage: (page) {
          if (page.streamEpoch <= 0) {
            throw const FormatException('Invalid replay epoch');
          }
          if (responseEpoch != null && responseEpoch != page.streamEpoch) {
            throw Exception('inconsistent replay epoch during resync');
          }
          responseEpoch = page.streamEpoch;
          highestSeqApplied = _applyReplayPage(
            machineId,
            streamEpoch: page.streamEpoch,
            events: page.events,
            highestSeqApplied: highestSeqApplied,
            onSeqAccounted: (seq) {
              if (seq > highestSeqAccountedFor) {
                highestSeqAccountedFor = seq;
              }
            },
          );
        },
      );

      final responseEpochValue = response.streamEpoch;
      if (responseEpochValue <= 0) {
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

      debugPrint(
        '[Resync] machine=$machineId response '
        'status=${response.status} streamEpoch=$responseEpochValue '
        'replayedThroughSeq=${response.replayedThroughSeq}',
      );

      switch (response.status) {
        case ReplayResyncStatus.reset:
          _setReplayCursor(
            machineId,
            ReplayCursor(streamEpoch: responseEpochValue, lastSeq: 0),
          );
          drainFence(response.replayedThroughSeq);
          debugPrint(
            '[Resync] machine=$machineId outcome=reset '
            'lastSeq=$lastSeq streamEpoch=$responseEpochValue',
          );
          return ResyncResult(
            outcome: ResyncOutcome.reset,
            lastSeqUsed: lastSeq,
            highestSeqApplied: lastSeq,
            streamEpoch: responseEpochValue,
          );
        case ReplayResyncStatus.gap:
          drainFence(response.replayedThroughSeq);
          debugPrint(
            '[Resync] machine=$machineId outcome=incomplete '
            'lastSeq=$lastSeq streamEpoch=$responseEpochValue '
            'replayedThroughSeq=${response.replayedThroughSeq}',
          );
          return ResyncResult(
            outcome: ResyncOutcome.incomplete,
            lastSeqUsed: lastSeq,
            highestSeqApplied: lastSeq,
            streamEpoch: responseEpochValue,
          );
        case ReplayResyncStatus.ok:
          if (response.replayedThroughSeq > highestSeqApplied) {
            highestSeqApplied = response.replayedThroughSeq;
            _setReplayCursor(
              machineId,
              ReplayCursor(
                streamEpoch: responseEpochValue,
                lastSeq: response.replayedThroughSeq,
              ),
            );
          }
          drainFence(highestSeqApplied);
          debugPrint(
            '[Resync] machine=$machineId outcome=complete '
            'lastSeq=$lastSeq streamEpoch=$responseEpochValue '
            'highestSeqApplied=$highestSeqApplied',
          );
          return ResyncResult(
            outcome: ResyncOutcome.complete,
            lastSeqUsed: lastSeq,
            highestSeqApplied: highestSeqApplied,
            streamEpoch: responseEpochValue,
          );
      }
    } catch (e) {
      debugPrint(
        '[Resync] machine=$machineId outcome=failed lastSeq=$lastSeq '
        'streamEpoch=$streamEpoch error=$e',
      );
      drainFence(highestSeqAccountedFor);
      return ResyncResult(
        outcome: ResyncOutcome.failed,
        lastSeqUsed: lastSeq,
        highestSeqApplied: highestSeqApplied,
        streamEpoch: streamEpoch,
        error: e,
      );
    } finally {
      if (!fenceDrained) {
        drainFence(highestSeqAccountedFor);
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

  int _applyReplayPage(
    String machineId, {
    required int streamEpoch,
    required Iterable<WsEvent> events,
    required int highestSeqApplied,
    required void Function(int seq) onSeqAccounted,
  }) {
    var nextHighest = highestSeqApplied;
    final existing = _replayCursorByMachine[machineId];
    if (existing == null || existing.streamEpoch != streamEpoch) {
      _setReplayCursor(
        machineId,
        ReplayCursor(streamEpoch: streamEpoch, lastSeq: highestSeqApplied),
      );
    }

    for (final wsEvent in events) {
      final event = _parseWsEvent(wsEvent);
      if (event == null || event.type == null) {
        continue;
      }
      _processEvent(event);
      if (event.seq > nextHighest) {
        nextHighest = event.seq;
        onSeqAccounted(nextHighest);
      }
      if (event.seq > 0) {
        _setReplayCursor(
          machineId,
          ReplayCursor(streamEpoch: streamEpoch, lastSeq: event.seq),
        );
      }
    }

    return nextHighest;
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

  /// Refresh daemon-known metadata for sessions already associated with
  /// [machineId]. This is an explicit session lookup only.
  Future<RepairStepResult> syncKnownSessions(String machineId) async {
    try {
      final baselineRevisions = <String, int>{
        for (final sessionId in sessions.keys)
          sessionId: _configRevision(sessionId),
      };
      final knownSessionIds = [
        for (final session in sessions.values)
          if (session.machineId == machineId) session.id,
      ];
      if (knownSessionIds.isEmpty) {
        return const RepairStepResult.success();
      }
      return _resolveAndMergeSessions(
        machineId,
        knownSessionIds,
        baselineRevisions: baselineRevisions,
      );
    } catch (e) {
      debugPrint('[EventRepo] syncKnownSessions failed: $e');
      return RepairStepResult.failure(e);
    }
  }

  Future<RepairStepResult> _resolveAndMergeSessions(
    String machineId,
    Iterable<String> sessionIds, {
    String? runtime,
    Map<String, int>? baselineRevisions,
    bool mergeStatus = true,
    bool mergeConfigSnapshot = true,
    bool mergeCwd = true,
    bool insertMissing = true,
  }) async {
    final targetIds = [
      for (final sessionId in sessionIds)
        if (sessionId.trim().isNotEmpty) sessionId.trim(),
    ];
    if (targetIds.isEmpty) {
      return const RepairStepResult.success();
    }
    final resolvedSessions = await _wsRepo.resolveSessions(
      machineId: machineId,
      sessionIds: targetIds,
      runtime: runtime,
    );
    return _mergeResolvedSessions(
      machineId,
      resolvedSessions,
      baselineRevisions ?? const {},
      runtimeFallback: runtime,
      mergeStatus: mergeStatus,
      mergeConfigSnapshot: mergeConfigSnapshot,
      mergeCwd: mergeCwd,
      insertMissing: insertMissing,
    );
  }

  Future<RepairStepResult> _mergeResolvedSessions(
    String machineId,
    List<ResolvedSessionSnapshot> resolvedSessions,
    Map<String, int> baselineRevisions, {
    String? runtimeFallback,
    bool mergeStatus = true,
    bool mergeConfigSnapshot = true,
    bool mergeCwd = true,
    bool insertMissing = true,
  }) async {
    var changed = false;
    for (final item in resolvedSessions) {
      final runtime = item.runtime.trim().isNotEmpty
          ? item.runtime.trim()
          : (runtimeFallback ?? '').trim();
      final existing = sessions[item.sessionId];
      if (existing == null && (!insertMissing || runtime.isEmpty)) {
        continue;
      }

      final updatedAt = item.updatedAt ?? DateTime.now();
      final nextSnapshot = item.configSnapshot;
      final hasSnapshot =
          mergeConfigSnapshot &&
          nextSnapshot != null &&
          _hasConfigSnapshotData(nextSnapshot);

      if (existing == null) {
        final session = AgentSession(
          id: item.sessionId,
          title: item.title,
          status: mergeStatus ? item.status : SessionStatus.idle,
          machineId: machineId,
          runtime: runtime,
          cwd: mergeCwd ? item.cwd : '',
          configSnapshot: hasSnapshot
              ? nextSnapshot
              : const SessionConfigSnapshot(),
          createdAt: updatedAt,
          updatedAt: updatedAt,
        );
        session.mode = session.configSnapshot.currentMode?.id;
        session.model = session.configSnapshot.currentModel;
        sessions[session.id] = session;
        if (hasSnapshot) {
          _bumpConfigRevision(session.id);
        }
        await SessionDatabase.insertSession(session);
        changed = true;
        continue;
      }

      final baseline = baselineRevisions[existing.id];
      if (mergeConfigSnapshot &&
          baseline != null &&
          _configRevision(existing.id) != baseline) {
        continue;
      }

      var dirty = false;
      if (existing.machineId != machineId) {
        existing.machineId = machineId;
        dirty = true;
      }
      if (item.title.isNotEmpty && existing.title != item.title) {
        existing.title = item.title;
        dirty = true;
      }
      if (runtime.isNotEmpty && existing.runtime != runtime) {
        existing.runtime = runtime;
        dirty = true;
      }
      if (mergeCwd && item.cwd.isNotEmpty && existing.cwd != item.cwd) {
        existing.cwd = item.cwd;
        dirty = true;
      }
      if (mergeStatus && existing.status != item.status) {
        existing.status = item.status;
        dirty = true;
      }
      if (updatedAt.isAfter(existing.updatedAt)) {
        existing.updatedAt = updatedAt;
        dirty = true;
      }

      String? configSnapshotJson;
      if (hasSnapshot) {
        final currentJson = jsonEncode(
          serializeSessionConfigSnapshot(existing.configSnapshot),
        );
        final nextJson = jsonEncode(
          serializeSessionConfigSnapshot(nextSnapshot),
        );
        if (currentJson != nextJson) {
          existing.configSnapshot = nextSnapshot;
          existing.mode = nextSnapshot.currentMode?.id ?? existing.mode;
          existing.model = nextSnapshot.currentModel ?? existing.model;
          configSnapshotJson = nextJson;
          _bumpConfigRevision(existing.id);
          dirty = true;
        }
      }

      if (!dirty) {
        continue;
      }

      final dbFields = <String, Object?>{
        'machine_id': existing.machineId,
        'runtime': existing.runtime,
        'cwd': existing.cwd,
        'updated_at': existing.updatedAt.toIso8601String(),
      };
      if (mergeStatus) {
        dbFields['status'] = existing.status.value;
      }
      if (existing.title.isNotEmpty) {
        dbFields['title'] = existing.title;
      }
      if (mergeConfigSnapshot) {
        dbFields['model'] = existing.model;
        if (existing.mode != null) {
          dbFields['mode'] = existing.mode;
        }
        if (configSnapshotJson != null) {
          dbFields['config_snapshot_json'] = configSnapshotJson;
        }
      }
      await SessionDatabase.updateFields(existing.id, dbFields);
      changed = true;
    }

    if (changed) {
      _sessionsChangedController.add(null);
    }
    return RepairStepResult.success(changed: changed);
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

  /// Resolve missing session titles via daemon-side `session.resolve`, then
  /// reuse the shared resolve-session merge path with title-only semantics.
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
      return _resolveAndMergeSessions(
        machineId,
        targetIds,
        runtime: runtime,
        mergeStatus: false,
        mergeConfigSnapshot: false,
        mergeCwd: false,
        insertMissing: false,
      );
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
    if (session.mode == null || session.mode!.isEmpty) {
      session.mode = session.configSnapshot.currentMode?.id;
    }
    if (session.model == null || session.model!.isEmpty) {
      session.model = session.configSnapshot.currentModel;
    }
    sessions[session.id] = session;
    if (_hasConfigSnapshotData(session.configSnapshot)) {
      _bumpConfigRevision(session.id);
    }
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
    if (existing.mode == nextMode &&
        existing.configSnapshot.currentMode?.id == nextMode) {
      return;
    }

    final availableModes = existing.configSnapshot.availableModes;
    final nextSnapshot = existing.configSnapshot.copyWith(
      currentMode: _resolveModeOption(
        modeId: nextMode,
        availableModes: availableModes,
        fallback: existing.configSnapshot.currentMode,
      ),
      clearCurrentMode: nextMode == null,
      availableModes: availableModes,
    );
    _applySessionConfigSnapshotToSession(
      existing,
      nextSnapshot,
      updatedAt: DateTime.now(),
    );
  }

  /// Persist a session model acknowledged by the daemon, even if the async
  /// config-change event arrives later or not at all.
  void setSessionModel(String sessionId, String? model) {
    final existing = sessions[sessionId];
    if (existing == null) return;

    final normalized = (model ?? '').trim();
    final nextModel = normalized.isEmpty ? null : normalized;
    if (existing.model == nextModel &&
        existing.configSnapshot.currentModel == nextModel) {
      return;
    }

    final nextSnapshot = existing.configSnapshot.copyWith(
      currentModel: nextModel,
      clearCurrentModel: nextModel == null,
      availableModels: existing.configSnapshot.availableModels,
    );
    _applySessionConfigSnapshotToSession(
      existing,
      nextSnapshot,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> applySessionConfigSnapshot(
    String sessionId,
    SessionConfigSnapshot snapshot, {
    DateTime? updatedAt,
  }) async {
    final existing = sessions[sessionId];
    if (existing == null) {
      return;
    }
    _applySessionConfigSnapshotToSession(
      existing,
      snapshot,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Future<bool> applySessionConfigSnapshotIfUnchanged(
    String sessionId, {
    required int baselineRevision,
    required SessionConfigSnapshot snapshot,
    DateTime? updatedAt,
  }) async {
    final existing = sessions[sessionId];
    if (existing == null) {
      return false;
    }
    if (_configRevision(sessionId) != baselineRevision) {
      return false;
    }
    _applySessionConfigSnapshotToSession(
      existing,
      snapshot,
      updatedAt: updatedAt ?? DateTime.now(),
    );
    return true;
  }

  Future<void> refreshSessionConfig({
    required String machineId,
    required String sessionId,
    String? runtime,
  }) {
    final pending = _configRefreshBySession[sessionId];
    if (pending != null) {
      return pending;
    }

    final future = _runRefreshSessionConfig(
      machineId: machineId,
      sessionId: sessionId,
      runtime: runtime,
    );
    _configRefreshBySession[sessionId] = future;
    future.whenComplete(() {
      if (identical(_configRefreshBySession[sessionId], future)) {
        _configRefreshBySession.remove(sessionId);
      }
    });
    return future;
  }

  Future<void> _runRefreshSessionConfig({
    required String machineId,
    required String sessionId,
    String? runtime,
  }) async {
    final existing = sessions[sessionId];
    if (existing == null) {
      return;
    }
    if (!_wsRepo.hasSession(machineId)) {
      debugPrint(
        '[EventRepository] skip refreshSessionConfig for session=$sessionId '
        'machine=$machineId: no active session',
      );
      return;
    }

    final baselineRevision = _configRevision(sessionId);
    final resolvedSessions = await _wsRepo.resolveSessions(
      machineId: machineId,
      sessionIds: [sessionId],
      runtime: runtime,
    );
    ResolvedSessionSnapshot? resolved;
    for (final item in resolvedSessions) {
      if (item.sessionId == sessionId) {
        resolved = item;
        break;
      }
    }
    if (resolved == null) {
      return;
    }
    final nextRuntime = resolved.runtime.isNotEmpty
        ? resolved.runtime
        : existing.runtime;
    final nextCwd = resolved.cwd.isNotEmpty ? resolved.cwd : existing.cwd;
    final persistRuntime =
        nextRuntime.isNotEmpty && existing.runtime != nextRuntime;
    final persistCwd = nextCwd.isNotEmpty && existing.cwd != nextCwd;
    if (_configRevision(sessionId) != baselineRevision) {
      if (persistRuntime || persistCwd) {
        await persistSessionRuntimeAndCwd(
          sessionId,
          runtime: nextRuntime,
          cwd: nextCwd,
        );
      }
      return;
    }
    if (resolved.configSnapshot == null) {
      if (persistRuntime || persistCwd) {
        await persistSessionRuntimeAndCwd(
          sessionId,
          runtime: nextRuntime,
          cwd: nextCwd,
        );
      }
      return;
    }
    if (persistRuntime) {
      existing.runtime = nextRuntime;
    }
    if (persistCwd) {
      existing.cwd = nextCwd;
    }

    _applySessionConfigSnapshotToSession(
      existing,
      resolved.configSnapshot!,
      updatedAt: resolved.updatedAt ?? DateTime.now(),
      includeRuntime: persistRuntime,
      includeCwd: persistCwd,
    );
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
