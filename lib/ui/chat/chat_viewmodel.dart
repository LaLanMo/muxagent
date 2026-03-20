import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/reconnect_recovery_coordinator.dart';
import '../../data/repositories/session_chat_cache_dto.dart';
import '../../data/repositories/session_chat_cache_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../data/services/ws/session_config_mapper.dart';
import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/fs_entry.dart';
import '../../domain/model_info.dart';
import '../../domain/mode_option.dart';
import '../../domain/message.dart';
import '../../domain/plan_entry.dart';
import '../../domain/prompt_content_block.dart';
import '../../domain/session_config_snapshot.dart';
import '../../domain/usage_info.dart';
import '../../usecases/transcribe_audio.dart';
import '../../utils/app_toast.dart';
import 'chat_state.dart';
import 'widgets/mention_text_controller.dart';

enum ChatUiMode {
  initialLoading,
  normal,
  rebuildingReadonly,
  viewOnly,
  unsupported,
}

class ChatViewModel extends GetxController with WidgetsBindingObserver {
  final EventRepository _eventRepo;
  final ReconnectRecoveryCoordinator _recovery;
  final SessionChatCacheRepository _chatCacheRepo;
  final WsSessionRepository _wsRepo;
  final TranscribeAudioUseCase _transcribe;

  ChatViewModel({
    required EventRepository eventRepo,
    required ReconnectRecoveryCoordinator recovery,
    required SessionChatCacheRepository chatCacheRepo,
    required WsSessionRepository wsRepo,
    required TranscribeAudioUseCase transcribe,
  }) : _eventRepo = eventRepo,
       _recovery = recovery,
       _chatCacheRepo = chatCacheRepo,
       _wsRepo = wsRepo,
       _transcribe = transcribe;

  @visibleForTesting
  static bool shouldTriggerReconnectFallback({
    required ReconnectRecoveryResult result,
    required bool hasSeenDisconnect,
    required ConnState connState,
    required bool hasSession,
  }) {
    return hasSeenDisconnect &&
        result.transcript == TranscriptRecoveryState.fallbackNeeded &&
        connState == ConnState.connected &&
        hasSession &&
        result.sessionReady;
  }

  @visibleForTesting
  static bool shouldRepairCachedSession({
    required SessionChatCacheEntry? entry,
    required bool hasRenderableVisibleState,
    required int machineLastSeq,
  }) {
    if (entry == null) {
      return !hasRenderableVisibleState;
    }
    if (!entry.isRenderable) {
      return true;
    }
    if (entry.cacheState == SessionChatCacheState.stale) {
      return true;
    }
    return machineLastSeq > entry.lastAppliedSeq;
  }

  @visibleForTesting
  static ChatUiMode initialUiModeForCachedSession({
    required SessionChatCacheEntry entry,
    required bool canRepair,
    required bool needsRepair,
  }) {
    if (!needsRepair && entry.cacheState == SessionChatCacheState.ready) {
      return ChatUiMode.normal;
    }
    return canRepair ? ChatUiMode.rebuildingReadonly : ChatUiMode.viewOnly;
  }

  @visibleForTesting
  static bool shouldReplaceOptimisticUserMessage({
    required bool hasOptimisticUserMessage,
    required MessagePartEvent? part,
  }) {
    return hasOptimisticUserMessage && part?.role == MessageRole.user;
  }

  @visibleForTesting
  static bool shouldEnableComposer({
    required ChatUiMode uiMode,
    required ConnState connState,
    required bool isRecoveringAfterReconnect,
  }) {
    return uiMode == ChatUiMode.normal &&
        connState == ConnState.connected &&
        !isRecoveringAfterReconnect;
  }

  late final String machineId;
  late final String sessionId;
  late final String routeCwd;
  late final ChatState chatState;
  final effectiveCwd = ''.obs;
  final uiMode = ChatUiMode.initialLoading.obs;

  final messages = <Message>[].obs;
  final approvals = <String, ApprovalRequest>{}.obs;
  final planEntries = <PlanEntry>[].obs;
  final sessionStatus = SessionStatus.idle.obs;
  final currentMode = Rxn<ModeOption>();
  final availableModes = <ModeOption>[].obs;
  final runtimeId = ''.obs;
  final connState = ConnState.connected.obs;
  final sessionTitle = ''.obs;
  final isLoading = true.obs;
  final showScrollToBottomButton = false.obs;
  final pendingImages = <XFile>[].obs;
  final pendingPreviews = <Uint8List>[].obs;
  final pendingMimeTypes = <String>[].obs;
  final inputController = MentionTextEditingController();
  final scrollController = ScrollController();
  final isVoiceRecording = false.obs;
  final isTranscribing = false.obs;
  final showModeDropdown = false.obs;
  final showFilePicker = false.obs;
  final currentModel = Rxn<String>();
  final availableModels = <ModelInfo>[].obs;
  final modelConfigId = ''.obs;
  final filePickerEntries = <FsEntry>[].obs;
  final filePickerLoading = false.obs;
  final isFileSearchMode = false.obs;
  final usageVersion = 0.obs;
  final isRecoveringAfterReconnect = false.obs;
  String get cwd => effectiveCwd.value;
  bool get canPrompt => shouldEnableComposer(
    uiMode: uiMode.value,
    connState: connState.value,
    isRecoveringAfterReconnect: isRecoveringAfterReconnect.value,
  );
  bool get canMutateSession => uiMode.value == ChatUiMode.normal;
  bool get canReplyApprovals =>
      uiMode.value != ChatUiMode.initialLoading &&
      uiMode.value != ChatUiMode.rebuildingReadonly &&
      uiMode.value != ChatUiMode.unsupported;
  bool get canCancelRun =>
      uiMode.value != ChatUiMode.initialLoading &&
      uiMode.value != ChatUiMode.rebuildingReadonly &&
      uiMode.value != ChatUiMode.unsupported;
  bool get inputReadOnly => !canPrompt;

  /// Live usage info for this session (cost, tokens, context window).
  UsageInfo? get usageInfo => _eventRepo.liveUsageFor(sessionId);

  bool get hasModeOptions =>
      availableModes.isNotEmpty || currentMode.value != null;

  String _browsePath = '';
  int _atPosition = -1;
  String _lastMentionQuery = '';
  Timer? _searchDebounce;

  AudioRecorder? _voiceRecorder;
  final hasSttConfig = false.obs;
  bool _userIsScrolling = false;
  bool _isAnimatingToBottom = false;
  bool _hasOptimisticUserMsg = false;
  Completer<bool>? _historyCompleter;
  Timer? _historyTimeout;
  bool _hasSeenDisconnect = false;
  bool _foregroundRecoveryInFlight = false;
  int _recoveryEpoch = 0;
  bool _subscriptionsAttached = false;
  Timer? _cacheWriteDebounce;
  bool _cacheFlushInFlight = false;
  bool _cacheFlushQueued = false;
  bool _queuedPromoteReady = false;
  bool _queuedForceFlush = false;
  Completer<void>? _cacheFlushCompleter;
  bool _isRebuilding = false;
  ChatState? _rebuildChatState;
  final _rebuildBacklog = <AgentEvent>[];
  SessionChatCacheEntry? _lastCacheEntry;
  int _visibleLastAppliedSeq = 0;
  int _rebuildLastAppliedSeq = 0;
  String? _initialPrompt;
  bool _didAttemptInitialPrompt = false;

  StreamSubscription<AgentEvent>? _eventSub;
  StreamSubscription<void>? _sessionMetaSub;
  StreamSubscription<ReconnectRecoveryResult>? _recoverySub;
  Worker? _connStateWorker;
  Timer? _foregroundReconnectTimer;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    final args = Get.arguments as Map<String, dynamic>;
    machineId = args['machineId'] as String;
    sessionId = args['sessionId'] as String;
    routeCwd = args['cwd'] as String? ?? '';
    sessionTitle.value = args['sessionTitle'] as String? ?? '';
    if (sessionTitle.value.isEmpty) {
      sessionTitle.value = _eventRepo.sessionById(sessionId)?.title ?? '';
    }
    chatState = ChatState(sessionId: sessionId);

    // Initialize status from shared session metadata (not hardcoded idle)
    final existing = _eventRepo.sessionById(sessionId);
    if (existing != null) {
      sessionStatus.value = existing.status;
      currentMode.value = _resolveMode(existing.mode);
      runtimeId.value = existing.runtime;
      if (routeCwd.isEmpty && existing.cwd.isNotEmpty) {
        effectiveCwd.value = existing.cwd;
      }
    }
    final routeRuntime = (args['runtime'] as String?)?.trim() ?? '';
    if (routeRuntime.isNotEmpty) {
      runtimeId.value = routeRuntime;
    }
    if (routeCwd.isNotEmpty) {
      effectiveCwd.value = routeCwd;
    }

    _eventRepo.markViewing(sessionId);
    _eventRepo.markAsRead(sessionId);
    connState.value = _wsRepo.connectionState.value;

    scrollController.addListener(_onScrollChanged);
    inputController.addListener(_detectMention);
    _checkSttConfig();

    _syncSessionSnapshotFromRepository();

    _initialPrompt = args['initialPrompt'] as String?;
    final isNewSession = args['isNewSession'] as bool? ?? false;

    if (isNewSession) {
      final configSnapshot = args['configSnapshot'] as SessionConfigSnapshot?;
      if (configSnapshot != null) {
        _applyConfigSnapshot(configSnapshot, schedulePersist: false);
      }
      _attachSubscriptions();
      uiMode.value = ChatUiMode.normal;
      isLoading.value = false;
      _scheduleScrollStateSync();
      _maybeSendInitialPrompt();
    } else {
      unawaited(_openExistingSession());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushSnapshotForBackground());
    }
  }

  void _attachSubscriptions() {
    if (_subscriptionsAttached) {
      return;
    }
    _subscriptionsAttached = true;
    _subscribeEvents();
    _subscribeSessionSnapshot();
    _subscribeRecoveryNotifications();
    _subscribeConnectionState();
  }

  void _subscribeEvents() {
    _eventSub = _eventRepo.events
        .where((e) => e.sessionId == sessionId)
        .listen(_handleEvent);
  }

  void _subscribeSessionSnapshot() {
    _sessionMetaSub = _eventRepo.sessionsChanged.listen((_) {
      if (isClosed) return;
      if (_isRebuilding) return;
      _syncSessionSnapshotFromRepository();
    });
  }

  void _subscribeRecoveryNotifications() {
    _recoverySub = _recovery.recoveries
        .where((result) => result.machineId == machineId)
        .listen((result) {
          unawaited(_handleRecoveryNotification(result));
        });
  }

  void _subscribeConnectionState() {
    _connStateWorker = ever<ConnState>(_wsRepo.connectionState, (state) {
      final previous = connState.value;
      connState.value = state;
      if (state == ConnState.disconnected) {
        _hasSeenDisconnect = true;
        _startForegroundReconnectRetry();
        return;
      }
      if (state == ConnState.reconnecting) {
        _hasSeenDisconnect = true;
        return;
      }
      _stopForegroundReconnectRetry();
      if (previous != ConnState.connected) {
        _syncSessionSnapshotFromRepository();
      }
    });
    if (connState.value == ConnState.disconnected) {
      _hasSeenDisconnect = true;
      _startForegroundReconnectRetry();
    }
  }

  Future<void> _openExistingSession() async {
    final hydrated = _chatCacheRepo.hydratedCacheForSession(sessionId);
    if (hydrated != null) {
      _applyHydratedCache(hydrated);
      _lastCacheEntry = hydrated.entry;
      final initialNeedsRepair = _needsRepair(
        hydrated.entry,
        hasRenderableVisibleState: true,
      );
      uiMode.value = initialUiModeForCachedSession(
        entry: hydrated.entry,
        canRepair: _canRepairSession(),
        needsRepair: initialNeedsRepair,
      );
      isLoading.value = false;
      _scheduleScrollStateSync();
    }

    _attachSubscriptions();
    _syncSessionSnapshotFromRepository();
    final refreshed = await _chatCacheRepo.reloadHydratedSession(sessionId);
    if (refreshed != null) {
      _lastCacheEntry = refreshed.entry;
    } else {
      _lastCacheEntry = await _chatCacheRepo.reloadSession(sessionId);
    }

    final needsRepair = _needsRepair(
      _lastCacheEntry,
      hasRenderableVisibleState: hydrated != null,
    );
    if (!needsRepair) {
      uiMode.value = ChatUiMode.normal;
      _scrollToBottom();
      _maybeSendInitialPrompt();
      return;
    }

    if (!_canRepairSession()) {
      uiMode.value = hydrated != null
          ? ChatUiMode.viewOnly
          : ChatUiMode.unsupported;
      isLoading.value = false;
      return;
    }

    await _performSessionLoad(preserveVisible: hydrated != null);
    _maybeSendInitialPrompt();
  }

  void _applyHydratedCache(SessionChatCacheHydrated hydrated) {
    chatState.replaceWith(hydrated.chatState);
    _visibleLastAppliedSeq = hydrated.entry.lastAppliedSeq;
    _applyConfigSnapshot(hydrated.configSnapshot, schedulePersist: false);
    if (hydrated.entry.title.isNotEmpty) {
      sessionTitle.value = hydrated.entry.title;
    }
    messages.value = chatState.orderedMessages;
    approvals.value = Map.from(chatState.approvals);
    planEntries.value = List<PlanEntry>.from(chatState.planEntries);
  }

  bool _needsRepair(
    SessionChatCacheEntry? entry, {
    required bool hasRenderableVisibleState,
  }) {
    return shouldRepairCachedSession(
      entry: entry,
      hasRenderableVisibleState: hasRenderableVisibleState,
      machineLastSeq: _eventRepo.lastSeqFor(machineId),
    );
  }

  bool _canRepairSession() {
    final runtime = runtimeId.value.trim();
    final cwdValue = effectiveCwd.value.trim();
    return runtime.isNotEmpty && cwdValue.isNotEmpty;
  }

  void _maybeSendInitialPrompt() {
    if (_didAttemptInitialPrompt) {
      return;
    }
    _didAttemptInitialPrompt = true;
    final prompt = _initialPrompt?.trim() ?? '';
    if (prompt.isEmpty) {
      return;
    }
    if (!canPrompt) {
      return;
    }
    unawaited(sendMessage(prompt));
  }

  void _syncSessionSnapshotFromRepository() {
    final session = _eventRepo.sessionById(sessionId);
    if (session != null) {
      sessionStatus.value = session.status;
      if (session.title.isNotEmpty) {
        sessionTitle.value = session.title;
      }
      if (session.runtime.isNotEmpty) {
        runtimeId.value = session.runtime;
      }
      if (session.cwd.isNotEmpty) {
        effectiveCwd.value = session.cwd;
      }
      if (session.model != null && session.model!.isNotEmpty) {
        currentModel.value = session.model;
      }
      final mode = _resolveMode(session.mode);
      if (mode != null) {
        currentMode.value = mode;
      }
    }

    for (final approval in _eventRepo.approvalsForSession(sessionId)) {
      final existing = chatState.approvals[approval.id];
      if (existing == null) {
        chatState.approvals[approval.id] = approval;
        continue;
      }
      chatState.approvals[approval.id] = ApprovalRequest(
        id: existing.id,
        sessionId: existing.sessionId,
        toolCallId: existing.toolCallId ?? approval.toolCallId,
        runtime: existing.runtime ?? approval.runtime,
        title: existing.title.isNotEmpty ? existing.title : approval.title,
        kind: existing.kind ?? approval.kind,
        bodyText: existing.bodyText ?? approval.bodyText,
        command: existing.command ?? approval.command,
        cwd: existing.cwd ?? approval.cwd,
        reason: existing.reason ?? approval.reason,
        planMarkdown: existing.planMarkdown ?? approval.planMarkdown,
        allowedPrompts: existing.allowedPrompts.isNotEmpty
            ? existing.allowedPrompts
            : approval.allowedPrompts,
        options: existing.options.isNotEmpty
            ? existing.options
            : approval.options,
        createdAt: existing.createdAt,
        resolved: existing.resolved,
      );
    }
    approvals.value = Map.from(chatState.approvals);
  }

  void _startForegroundReconnectRetry() {
    if (_foregroundReconnectTimer != null) return;

    unawaited(_attemptForegroundRecovery());
    _foregroundReconnectTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (isClosed || connState.value == ConnState.connected) {
        _stopForegroundReconnectRetry();
        return;
      }
      unawaited(_attemptForegroundRecovery());
    });
  }

  void _stopForegroundReconnectRetry() {
    _foregroundReconnectTimer?.cancel();
    _foregroundReconnectTimer = null;
  }

  Future<void> _attemptForegroundRecovery() async {
    if (isClosed || !_hasSeenDisconnect || _foregroundRecoveryInFlight) return;
    _foregroundRecoveryInFlight = true;
    try {
      await _recovery.recoverMachine(machineId);
    } finally {
      _foregroundRecoveryInFlight = false;
    }
  }

  // A complete machine recovery only needs repo-derived UI refresh. Any
  // fallback-needed transcript recovery escalates to active-session replay via
  // session.load so the open transcript is rebuilt from daemon history.
  Future<void> _handleRecoveryNotification(
    ReconnectRecoveryResult result,
  ) async {
    if (isClosed) return;

    debugPrint(
      '[ChatRecovery] session=$sessionId machine=$machineId '
      'transcript=${result.transcript} metadata=${result.metadata} '
      'hasSeenDisconnect=$_hasSeenDisconnect '
      'conn=${connState.value} '
      'hasSession=${_wsRepo.hasSession(machineId)} '
      'sessionReady=${result.sessionReady}',
    );
    _syncSessionSnapshotFromRepository();
    if (!_hasSeenDisconnect) return;

    if (result.transcript == TranscriptRecoveryState.complete) {
      _hasSeenDisconnect = false;
      return;
    }
    if (!shouldTriggerReconnectFallback(
      result: result,
      hasSeenDisconnect: _hasSeenDisconnect,
      connState: connState.value,
      hasSession: _wsRepo.hasSession(machineId),
    )) {
      return;
    }

    debugPrint(
      '[ChatRecovery] session=$sessionId machine=$machineId '
      'triggering=session.load-fallback',
    );
    final refreshed = await _chatCacheRepo.reloadSession(sessionId);
    _lastCacheEntry = refreshed;
    if (!_canRepairSession()) {
      if (refreshed != null && refreshed.isRenderable) {
        uiMode.value = ChatUiMode.viewOnly;
      }
      return;
    }
    await _performSessionLoad(
      preserveVisible:
          _hasVisibleTranscript || (refreshed?.isRenderable ?? false),
    );
    if (!isClosed) {
      _hasSeenDisconnect = false;
    }
  }

  void _applyConfigSnapshot(
    SessionConfigSnapshot snapshot, {
    bool schedulePersist = true,
  }) {
    modelConfigId.value = snapshot.modelConfigId ?? '';
    currentModel.value = snapshot.currentModel;
    availableModels.value = snapshot.availableModels;
    availableModes.value = snapshot.availableModes;
    currentMode.value = snapshot.currentMode;
    if (schedulePersist) {
      _scheduleSnapshotWrite();
    }
  }

  Future<void> _performSessionLoad({required bool preserveVisible}) async {
    _historyCompleter = Completer<bool>();
    final loadToken = ++_recoveryEpoch;
    final loadRuntime = runtimeId.value.trim();
    final loadCwd = effectiveCwd.value.trim();
    final previousUiMode = uiMode.value;

    isRecoveringAfterReconnect.value = preserveVisible;
    if (preserveVisible) {
      _isRebuilding = true;
      _rebuildChatState = ChatState(sessionId: sessionId);
      _rebuildLastAppliedSeq = 0;
      _rebuildBacklog.clear();
      uiMode.value = ChatUiMode.rebuildingReadonly;
      isLoading.value = false;
    } else {
      _isRebuilding = false;
      _rebuildChatState = null;
      _rebuildLastAppliedSeq = 0;
      _rebuildBacklog.clear();
      _resetTranscriptState();
      uiMode.value = ChatUiMode.initialLoading;
      isLoading.value = true;
    }

    try {
      if (loadCwd.isEmpty) throw Exception('missing cwd for session.load');
      if (loadRuntime.isEmpty) {
        throw Exception('missing runtime for session.load');
      }
      final session = _eventRepo.sessionById(sessionId);
      final mode = session?.mode ?? '';
      final model = session?.model ?? '';

      final response = await _wsRepo.loadSession(
        machineId: machineId,
        sessionId: sessionId,
        cwd: loadCwd,
        runtime: loadRuntime,
        permissionMode: mode.isNotEmpty && mode != 'default' ? mode : null,
        model: model,
      );

      final loadedRuntime = response.app.runtime;
      final loadedCwd = response.app.cwd.isNotEmpty
          ? response.app.cwd
          : loadCwd;
      if (loadedRuntime.isNotEmpty) runtimeId.value = loadedRuntime;
      final snapshot = SessionConfigMapper.snapshotFromConfigOptions(
        runtimeId: runtimeId.value,
        configOptions: response.acp.configOptions ?? const [],
        modes: response.acp.modes,
      );
      _applyConfigSnapshot(snapshot, schedulePersist: false);

      _historyTimeout = Timer(const Duration(seconds: 30), () {
        if (!isClosed &&
            _historyCompleter != null &&
            !_historyCompleter!.isCompleted) {
          _historyCompleter!.complete(false);
        }
      });

      final historyCompleted = await _historyCompleter!.future;
      if (!historyCompleted) {
        throw TimeoutException('session.load did not finish replaying history');
      }
      await _eventRepo.persistSessionRuntimeAndCwd(
        sessionId,
        runtime: loadedRuntime.isNotEmpty ? loadedRuntime : loadRuntime,
        cwd: loadedCwd,
      );
      final updatedSession = _eventRepo.sessionById(sessionId);
      if (updatedSession != null && updatedSession.cwd.isNotEmpty) {
        effectiveCwd.value = updatedSession.cwd;
      } else {
        effectiveCwd.value = loadedCwd;
      }

      if (preserveVisible && _rebuildChatState != null) {
        chatState.replaceWith(_rebuildChatState!);
        _visibleLastAppliedSeq = _rebuildLastAppliedSeq;
      }
      _syncVisibleStateFromChatState();
      _syncSessionSnapshotFromRepository();
      await _flushVisibleSnapshot(promoteReady: true, force: true);
      if (!isClosed && loadToken == _recoveryEpoch) {
        uiMode.value = ChatUiMode.normal;
        isLoading.value = false;
      }
    } catch (e) {
      AppToast.show('$e');
      if (preserveVisible) {
        if (!isClosed && loadToken == _recoveryEpoch) {
          uiMode.value = previousUiMode;
        }
      } else if (!isClosed && loadToken == _recoveryEpoch) {
        uiMode.value = ChatUiMode.unsupported;
      }
    } finally {
      _historyTimeout?.cancel();
      _historyTimeout = null;
      _historyCompleter = null;
      _isRebuilding = false;
      _rebuildChatState = null;
      _rebuildLastAppliedSeq = 0;
      _rebuildBacklog.clear();
      isRecoveringAfterReconnect.value = false;
      if (!isClosed) {
        if (uiMode.value != ChatUiMode.initialLoading) {
          isLoading.value = false;
        }
        _syncSessionSnapshotFromRepository();
        _syncVisibleStateFromChatState();
        _scheduleScrollStateSync();
      }
    }
  }

  void _resetTranscriptState() {
    chatState.reset();
    _visibleLastAppliedSeq = 0;
    messages.clear();
    approvals.clear();
    planEntries.clear();
    showScrollToBottomButton.value = false;
    _userIsScrolling = false;
    _isAnimatingToBottom = false;
  }

  bool get _hasVisibleTranscript =>
      chatState.orderedMessages.isNotEmpty ||
      chatState.approvals.isNotEmpty ||
      chatState.planEntries.isNotEmpty;

  bool get _hasPersistableVisibleTranscript =>
      chatState.orderedMessages.any(
        (message) =>
            !(message.role == MessageRole.user &&
                message.id.startsWith('local-')),
      ) ||
      chatState.approvals.isNotEmpty ||
      chatState.planEntries.isNotEmpty;

  void _handleEvent(AgentEvent event) {
    if (_isRebuilding && _rebuildChatState != null) {
      _rebuildBacklog.add(event);
      _rebuildLastAppliedSeq = _maxAppliedSeq(
        _rebuildLastAppliedSeq,
        event.seq,
      );
      _applyEventToState(
        event,
        _rebuildChatState!,
        updateVisibleCollections: false,
      );
      if (event.type == EventType.historyComplete &&
          _historyCompleter != null &&
          !_historyCompleter!.isCompleted) {
        _historyCompleter!.complete(true);
      }
      return;
    }
    _visibleLastAppliedSeq = _maxAppliedSeq(_visibleLastAppliedSeq, event.seq);
    _applyEventToState(event, chatState, updateVisibleCollections: true);
  }

  int _maxAppliedSeq(int current, int next) {
    if (next <= 0) {
      return current;
    }
    return next > current ? next : current;
  }

  void _applyEventToState(
    AgentEvent event,
    ChatState target, {
    required bool updateVisibleCollections,
  }) {
    switch (event.type) {
      case EventType.reasoning:
      case EventType.messageDelta:
        if (event.messagePart != null) {
          if (shouldReplaceOptimisticUserMessage(
            hasOptimisticUserMessage: _hasOptimisticUserMsg,
            part: event.messagePart,
          )) {
            target.adoptLocalOptimisticUserMessage(
              event.messagePart!.messageId,
            );
            _hasOptimisticUserMsg = false;
          }
          target.applyDelta(event.messagePart!);
          if (updateVisibleCollections && !isLoading.value) {
            _refreshMessages();
          }
        }

      case EventType.toolStarted:
      case EventType.toolUpdated:
      case EventType.toolCompleted:
      case EventType.toolFailed:
        if (event.tool != null) {
          target.applyToolEvent(event.tool!);
          if (updateVisibleCollections && !isLoading.value) {
            _refreshMessages();
          }
        }

      case EventType.approvalRequested:
        if (event.approval != null) {
          target.addApproval(event.approval!);
          if (updateVisibleCollections) {
            _refreshApprovals();
            sessionStatus.value = SessionStatus.waitingApproval;
          }
        }

      case EventType.approvalReplied:
        if (event.approval != null) {
          target.resolveApproval(event.approval!.id);
          if (updateVisibleCollections) {
            _refreshApprovals();
          }
        }

      case EventType.sessionStatus:
        if (event.session != null && updateVisibleCollections) {
          sessionStatus.value = event.session!.status;
          if (event.session!.title.isNotEmpty) {
            sessionTitle.value = event.session!.title;
          }
        }

      case EventType.usageUpdate:
        if (updateVisibleCollections) {
          usageVersion.value++;
        }

      case EventType.runFinished:
        _hasOptimisticUserMsg = false;
        if (updateVisibleCollections) {
          sessionStatus.value = SessionStatus.idle;
          usageVersion.value++;
        }

      case EventType.runFailed:
        _hasOptimisticUserMsg = false;
        if (event.error != null && event.error!.message.isNotEmpty) {
          final errorMsg = Message(
            id: 'error-${event.at.millisecondsSinceEpoch}',
            sessionId: sessionId,
            role: MessageRole.agent,
            parts: [
              MessagePart(type: PartType.text, text: event.error!.message),
            ],
            createdAt: event.at,
          );
          target.finalizeMessage(errorMsg);
          if (updateVisibleCollections && !isLoading.value) {
            _refreshMessages();
          }
        }
        if (updateVisibleCollections) {
          sessionStatus.value = SessionStatus.error;
        }

      case EventType.planUpdated:
        final entries = event.planUpdate?.entries;
        if (entries != null) {
          target.updatePlan(entries);
          if (updateVisibleCollections) {
            planEntries.value = entries;
            _scheduleSnapshotWrite();
          }
        }

      case EventType.modeChanged:
        if (updateVisibleCollections) {
          currentMode.value = _resolveMode(event.modeChange?.currentModeId);
          _scheduleSnapshotWrite();
        }

      case EventType.modelChanged:
        if (event.configChange != null && updateVisibleCollections) {
          final configChange = event.configChange!;
          currentModel.value = configChange.currentValue;
          modelConfigId.value = configChange.configId;
          availableModels.value = configChange.values
              .map(
                (value) => ModelInfo(
                  value: value.value,
                  name: value.name,
                  description: value.description,
                ),
              )
              .toList();
          _scheduleSnapshotWrite();
        }

      case EventType.historyComplete:
        if (_historyCompleter != null && !_historyCompleter!.isCompleted) {
          _historyCompleter!.complete(true);
        }

      case null:
        break;
    }
  }

  bool get _isAtBottom {
    if (!scrollController.hasClients) return true;
    return scrollController.position.pixels <= 100;
  }

  void _onScrollChanged() {
    if (_isAnimatingToBottom) return;
    if (showModeDropdown.value) showModeDropdown.value = false;
    _syncScrollState();
  }

  void toggleModeDropdown() {
    if (availableModes.isEmpty) return;
    showModeDropdown.toggle();
  }

  Future<void> changeMode(ModeOption mode) async {
    if (!canMutateSession) return;
    showModeDropdown.value = false;
    if (mode.id == currentMode.value?.id) return;

    final previous = currentMode.value;
    currentMode.value = mode;

    try {
      await _wsRepo.setMode(
        machineId: machineId,
        sessionId: sessionId,
        permissionMode: mode.id,
      );
      _eventRepo.setSessionMode(sessionId, mode.id);
    } catch (e) {
      debugPrint('[ChatVM] changeMode failed: $e');
      currentMode.value = previous;
    }
  }

  ModeOption? _resolveMode(String? modeID) {
    final id = modeID ?? '';
    if (id.isEmpty) return null;
    for (final mode in availableModes) {
      if (mode.id == id) return mode;
    }
    if (!ModeOption.isVisibleForRuntime(runtimeId.value, id)) {
      return availableModes.isNotEmpty ? availableModes.first : null;
    }
    return ModeOption.fromId(id);
  }

  Future<void> changeModel(String value) async {
    if (!canMutateSession) return;
    if (value == currentModel.value) return;
    final configId = modelConfigId.value;
    if (configId.isEmpty) return;

    debugPrint(
      '[ChatVM] changeModel: $currentModel → $value (configId=$configId)',
    );
    final previous = currentModel.value;
    currentModel.value = value;

    try {
      await _wsRepo.setConfigOption(
        machineId: machineId,
        sessionId: sessionId,
        configId: configId,
        value: value,
      );
      _eventRepo.setSessionModel(sessionId, value);
    } catch (e) {
      debugPrint('[ChatVM] changeModel failed: $e');
      currentModel.value = previous;
    }
  }

  void _scrollToBottom() {
    _scrollToBottomInternal(animated: false, force: false);
  }

  void _setFollowBottom(bool userIsScrolling) {
    _userIsScrolling = userIsScrolling;
    showScrollToBottomButton.value = userIsScrolling;
  }

  void _syncScrollState() {
    if (!scrollController.hasClients) return;
    _setFollowBottom(!_isAtBottom);
  }

  void _scheduleScrollStateSync() {
    void sync() {
      if (_isAnimatingToBottom || !scrollController.hasClients) return;
      _syncScrollState();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => sync());
    Future.delayed(const Duration(milliseconds: 80), sync);
  }

  void _scrollToBottomInternal({required bool animated, required bool force}) {
    if (!force && _userIsScrolling) {
      _scheduleScrollStateSync();
      return;
    }

    _setFollowBottom(false);

    if (!scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients) return;
        if (scrollController.position.pixels > 0.5) scrollController.jumpTo(0);
        _syncScrollState();
      });
      return;
    }

    if (scrollController.position.pixels <= 0.5) return;

    if (animated) {
      _isAnimatingToBottom = true;
      scrollController
          .animateTo(
            0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            _isAnimatingToBottom = false;
            _syncScrollState();
          });
    } else {
      scrollController.jumpTo(0);
    }
  }

  void animateToBottom() {
    _scrollToBottomInternal(animated: true, force: true);
  }

  void _refreshMessages() {
    void doRefresh() {
      messages.value = chatState.orderedMessages;
      _scrollToBottom();
      _scheduleScrollStateSync();
      _scheduleSnapshotWrite();
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => doRefresh());
    } else {
      doRefresh();
    }
  }

  void _refreshApprovals() {
    approvals.value = Map.from(chatState.approvals);
    _scrollToBottom();
    _scheduleScrollStateSync();
    _scheduleSnapshotWrite();
  }

  void _syncVisibleStateFromChatState() {
    messages.value = chatState.orderedMessages;
    approvals.value = Map.from(chatState.approvals);
    planEntries.value = List<PlanEntry>.from(chatState.planEntries);
    _scrollToBottom();
    _scheduleScrollStateSync();
  }

  SessionConfigSnapshot _currentConfigSnapshot() {
    return SessionConfigSnapshot(
      modelConfigId: modelConfigId.value,
      currentModel: currentModel.value,
      currentMode: currentMode.value,
      availableModels: availableModels.toList(),
      availableModes: availableModes.toList(),
    );
  }

  void _scheduleSnapshotWrite() {
    _cacheWriteDebounce?.cancel();
    _cacheWriteDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_flushVisibleSnapshot(promoteReady: false));
    });
  }

  Future<void> _flushSnapshotForBackground() async {
    _cacheWriteDebounce?.cancel();
    _cacheWriteDebounce = null;
    await _flushVisibleSnapshot(promoteReady: !_isRebuilding, force: true);
  }

  Future<void> _flushVisibleSnapshot({
    required bool promoteReady,
    bool force = false,
  }) async {
    if (isClosed) {
      return;
    }
    _cacheFlushQueued = true;
    _queuedPromoteReady = _queuedPromoteReady || promoteReady;
    _queuedForceFlush = _queuedForceFlush || force;
    if (_cacheFlushInFlight) {
      await _cacheFlushCompleter?.future;
      return;
    }

    while (_cacheFlushQueued && !isClosed) {
      final queuedPromoteReady = _queuedPromoteReady;
      final queuedForce = _queuedForceFlush;
      _cacheFlushQueued = false;
      _queuedPromoteReady = false;
      _queuedForceFlush = false;

      if (!queuedForce &&
          uiMode.value == ChatUiMode.initialLoading &&
          !_hasPersistableVisibleTranscript &&
          (_lastCacheEntry == null ||
              _lastCacheEntry!.cacheState == SessionChatCacheState.empty)) {
        continue;
      }

      _cacheFlushInFlight = true;
      _cacheFlushCompleter = Completer<void>();
      try {
        final nextState = _cacheStateForFlush(promoteReady: queuedPromoteReady);
        final entry = await _chatCacheRepo.persistSnapshot(
          sessionId: sessionId,
          machineId: machineId,
          title: sessionTitle.value,
          chatState: chatState,
          configSnapshot: _currentConfigSnapshot(),
          cacheState: nextState,
          lastAppliedSeq: _visibleLastAppliedSeq,
        );
        _lastCacheEntry = entry;
      } finally {
        _cacheFlushInFlight = false;
        _cacheFlushCompleter?.complete();
        _cacheFlushCompleter = null;
      }
    }
  }

  SessionChatCacheState _cacheStateForFlush({required bool promoteReady}) {
    if (!_hasPersistableVisibleTranscript) {
      return SessionChatCacheState.empty;
    }
    if (!promoteReady) {
      return SessionChatCacheState.stale;
    }
    return _isRebuilding
        ? SessionChatCacheState.stale
        : SessionChatCacheState.ready;
  }

  Future<void> pickImage() async {
    final remaining = 20 - pendingImages.length;
    if (remaining <= 0) return;
    final images = await ImagePicker().pickMultiImage(
      limit: remaining,
      maxWidth: 2000,
      maxHeight: 2000,
      requestFullMetadata: false,
    );
    for (final img in images) {
      pendingImages.add(img);
      pendingPreviews.add(await img.readAsBytes());
      pendingMimeTypes.add(_mimeType(img.name));
    }
  }

  void removeImage(int index) {
    if (index >= 0 && index < pendingImages.length) {
      pendingImages.removeAt(index);
      pendingPreviews.removeAt(index);
      pendingMimeTypes.removeAt(index);
    }
  }

  Future<void> _checkSttConfig() async {
    hasSttConfig.value = await _transcribe.hasConfig();
  }

  Future<void> startVoiceInput() async {
    // Show stop button immediately for responsive feedback.
    isVoiceRecording.value = true;

    _voiceRecorder = AudioRecorder();
    if (!await _voiceRecorder!.hasPermission()) {
      AppToast.show('Microphone permission denied');
      isVoiceRecording.value = false;
      _voiceRecorder = null;
      return;
    }

    final path =
        '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _voiceRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (e) {
      AppToast.show('Failed to start recording');
      isVoiceRecording.value = false;
      await _voiceRecorder!.dispose();
      _voiceRecorder = null;
      return;
    }

    if (!await _voiceRecorder!.isRecording()) {
      AppToast.show('Microphone unavailable');
      isVoiceRecording.value = false;
      await _voiceRecorder!.dispose();
      _voiceRecorder = null;
      return;
    }
  }

  Future<void> stopVoiceInput() async {
    if (_voiceRecorder == null) {
      isVoiceRecording.value = false;
      return;
    }

    final path = await _voiceRecorder!.stop();
    await _voiceRecorder!.dispose();
    _voiceRecorder = null;

    if (path == null) {
      isVoiceRecording.value = false;
      AppToast.show('Recording failed');
      return;
    }

    final file = File(path);
    final size = await file.length();
    if (size < 100) {
      isVoiceRecording.value = false;
      AppToast.show('No audio captured — microphone may be unavailable');
      try {
        await file.delete();
      } catch (_) {}
      return;
    }

    // Transition directly: recording → transcribing (no gap/flash).
    isTranscribing.value = true;
    isVoiceRecording.value = false;
    try {
      final bytes = await file.readAsBytes();
      final result = await _transcribe.call(bytes, 'audio/m4a');
      if (result.text.isNotEmpty) {
        final current = inputController.text;
        if (current.isNotEmpty && !current.endsWith(' ')) {
          inputController.text = '$current ${result.text}';
        } else {
          inputController.text = '$current${result.text}';
        }
        // Move cursor to end
        inputController.selection = TextSelection.collapsed(
          offset: inputController.text.length,
        );
      }
    } catch (e) {
      AppToast.show('Transcription failed: $e');
    } finally {
      isTranscribing.value = false;
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  // ── File mention detection ──

  void _detectMention() {
    final value = inputController.value;

    // Skip during IME composing (e.g. Chinese pinyin input)
    if (value.composing.isValid && !value.composing.isCollapsed) return;

    final text = value.text;
    final cursorPos = value.selection.baseOffset;
    if (cursorPos < 0) return;

    // Scan backwards from cursor for nearest valid @
    int atPos = -1;
    for (var i = cursorPos - 1; i >= 0; i--) {
      if (text[i] == '@') {
        // Valid @ must be at start of text or preceded by whitespace
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
          atPos = i;
        }
        break; // Stop at first @ found regardless of validity
      }
      // Stop scanning if we hit whitespace before finding @
      if (text[i] == ' ' || text[i] == '\n') break;
    }

    if (atPos < 0) {
      if (showFilePicker.value) _dismissFilePicker();
      return;
    }

    final query = text.substring(atPos + 1, cursorPos);

    // Space in query terminates mention
    if (query.contains(' ')) {
      if (showFilePicker.value) _dismissFilePicker();
      return;
    }

    _atPosition = atPos;

    if (query.isEmpty) {
      // Browse mode
      isFileSearchMode.value = false;
      if (!showFilePicker.value) {
        showFilePicker.value = true;
        _browsePath = '';
        _fetchListing(_browsePath);
      }
    } else {
      // Search mode
      isFileSearchMode.value = true;
      showFilePicker.value = true;
      if (query != _lastMentionQuery) {
        _lastMentionQuery = query;
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 300), () {
          _fetchSearch(query);
        });
      }
    }
  }

  Future<void> _fetchListing(String path) async {
    filePickerLoading.value = true;
    try {
      filePickerEntries.value = await _wsRepo.listFiles(
        machineId: machineId,
        sessionId: sessionId,
        path: path,
      );
    } catch (e) {
      debugPrint('[ChatVM] fs.list failed: $e');
      filePickerEntries.clear();
    } finally {
      filePickerLoading.value = false;
    }
  }

  Future<void> _fetchSearch(String query) async {
    filePickerLoading.value = true;
    try {
      filePickerEntries.value = await _wsRepo.searchFiles(
        machineId: machineId,
        sessionId: sessionId,
        query: query,
      );
    } catch (e) {
      debugPrint('[ChatVM] fs.search failed: $e');
      filePickerEntries.clear();
    } finally {
      filePickerLoading.value = false;
    }
  }

  void onFileEntryDrillDown(FsEntry entry) {
    _browsePath = entry.path;
    _fetchListing(_browsePath);
  }

  void onFileEntryTap(FsEntry entry) {
    // Insert file path replacing @query
    final text = inputController.text;
    final cursorPos = inputController.selection.baseOffset;
    if (_atPosition < 0 || _atPosition >= text.length) {
      _dismissFilePicker();
      return;
    }

    final before = text.substring(0, _atPosition);
    final after = cursorPos < text.length ? text.substring(cursorPos) : '';
    final insertion = '@${entry.path} ';
    final newText = '$before$insertion$after';
    final newCursor = before.length + insertion.length;

    inputController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _dismissFilePicker();
  }

  void _dismissFilePicker() {
    showFilePicker.value = false;
    filePickerEntries.clear();
    filePickerLoading.value = false;
    isFileSearchMode.value = false;
    _atPosition = -1;
    _browsePath = '';
    _lastMentionQuery = '';
    _searchDebounce?.cancel();
  }

  Future<void> sendMessage(String text) async {
    if (!canPrompt) {
      AppToast.show('Chat is read-only right now.');
      return;
    }
    if (showFilePicker.value) _dismissFilePicker();

    final trimmed = text.trim();
    final hasImages = pendingImages.isNotEmpty;
    if (trimmed.isEmpty && !hasImages) return;

    inputController.clear();

    // Snapshot pending images and clear state
    final previewsToSend = List<Uint8List>.from(pendingPreviews);
    final mimeTypesToSend = List<String>.from(pendingMimeTypes);
    pendingImages.clear();
    pendingPreviews.clear();
    pendingMimeTypes.clear();

    // Build optimistic message parts
    final parts = <MessagePart>[];
    for (var i = 0; i < previewsToSend.length; i++) {
      parts.add(
        MessagePart(
          type: PartType.media,
          media: MediaPart(
            base64: base64Encode(previewsToSend[i]),
            mimeType: mimeTypesToSend[i],
          ),
        ),
      );
    }
    if (trimmed.isNotEmpty) {
      parts.add(MessagePart(type: PartType.text, text: trimmed));
    }

    final userMsg = Message(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      sessionId: sessionId,
      role: MessageRole.user,
      parts: parts,
      createdAt: DateTime.now(),
    );
    _hasOptimisticUserMsg = true;
    chatState.finalizeMessage(userMsg);
    _refreshMessages();
    _setFollowBottom(false);
    _scrollToBottom();
    sessionStatus.value = SessionStatus.running;
    _eventRepo.setSessionStatus(sessionId, SessionStatus.running);

    // Build content blocks for the RPC
    final content = <PromptContentBlock>[];
    for (var i = 0; i < previewsToSend.length; i++) {
      content.add(
        PromptContentBlock.imageBase64(
          mimeType: mimeTypesToSend[i],
          data: base64Encode(previewsToSend[i]),
        ),
      );
    }
    if (trimmed.isNotEmpty) {
      content.add(PromptContentBlock.text(trimmed));
    }

    // Await ACK from daemon — prompt runs asynchronously on daemon side,
    // so this returns quickly. Failure means daemon rejected the request.
    try {
      await _wsRepo.promptSession(
        machineId: machineId,
        sessionId: sessionId,
        content: content,
      );
    } catch (e) {
      debugPrint('Prompt rejected: $e');
      // ACK failure = daemon didn't start the prompt = no events coming
      sessionStatus.value = SessionStatus.error;
      _eventRepo.setSessionStatus(sessionId, SessionStatus.error);
    }
  }

  static String _mimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> replyApproval(String requestId, String optionId) async {
    if (!canReplyApprovals) return;
    try {
      await _wsRepo.replyApproval(
        machineId: machineId,
        sessionId: sessionId,
        requestId: requestId,
        optionId: optionId,
      );
      chatState.resolveApproval(requestId);
      _refreshApprovals();
      sessionStatus.value = SessionStatus.running;
      _eventRepo.setSessionStatus(sessionId, SessionStatus.running);
    } catch (e) {
      debugPrint('[ChatVM] replyApproval FAILED: $e');
    }
  }

  Future<void> cancelSession() async {
    if (!canCancelRun) return;
    // Fast path: WS disconnected, skip RPC
    if (!_wsRepo.isConnected) {
      _resetSessionLocally();
      return;
    }
    try {
      await _wsRepo.cancelSession(machineId: machineId, sessionId: sessionId);
    } catch (e) {
      debugPrint('Failed to cancel session: $e');
      _resetSessionLocally();
    }
  }

  void _resetSessionLocally() {
    // Guard: only reset non-terminal status to avoid overwriting done/error
    if (sessionStatus.value == SessionStatus.running ||
        sessionStatus.value == SessionStatus.waitingApproval) {
      sessionStatus.value = SessionStatus.idle;
      _eventRepo.setSessionStatus(sessionId, SessionStatus.idle);
    }
    // Clear stale approvals to avoid badge count and ghost approval cards
    _eventRepo.pendingApprovals.removeWhere(
      (_, approval) => approval.sessionId == sessionId,
    );
    chatState.approvals.clear();
    _refreshApprovals();
    AppToast.show('Session stopped locally');
  }

  Future<bool> prepareForClose() async {
    _cacheWriteDebounce?.cancel();
    _cacheWriteDebounce = null;
    await _flushVisibleSnapshot(promoteReady: true, force: true);
    return true;
  }

  @override
  void onClose() {
    if (_historyCompleter != null && !_historyCompleter!.isCompleted) {
      _historyCompleter!.complete(false);
    }
    _historyTimeout?.cancel();
    _recoveryEpoch++;
    _cacheWriteDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _eventRepo.markNotViewing(sessionId);
    _eventSub?.cancel();
    _sessionMetaSub?.cancel();
    _recoverySub?.cancel();
    _connStateWorker?.dispose();
    _searchDebounce?.cancel();
    _stopForegroundReconnectRetry();
    scrollController.dispose();
    inputController.removeListener(_detectMention);
    inputController.dispose();
    _voiceRecorder?.dispose();
    super.onClose();
  }
}
