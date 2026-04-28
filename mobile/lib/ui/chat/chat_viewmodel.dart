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
import '../../data/services/ws/event_envelope_parser.dart';
import '../../data/services/ws/session_config_mapper.dart';
import '../../data/services/ws/transport_error_classifier.dart';
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
import '../../i18n/tx.dart';
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
    required ConnState transportState,
    required bool hasSession,
  }) {
    return hasSeenDisconnect &&
        result.transcript == TranscriptRecoveryState.fallbackNeeded &&
        transportState == ConnState.connected &&
        hasSession &&
        result.sessionReady;
  }

  @visibleForTesting
  static bool shouldQueueReconnectFallback({
    required ReconnectRecoveryResult result,
    required bool hasSeenDisconnect,
    required ConnState transportState,
    required bool hasSession,
  }) {
    return hasSeenDisconnect &&
        result.transcript == TranscriptRecoveryState.fallbackNeeded &&
        transportState != ConnState.connected &&
        hasSession &&
        result.sessionReady;
  }

  @visibleForTesting
  static bool shouldResumeQueuedReconnectFallback({
    required bool hasQueuedReconnectFallback,
    required bool hasSeenDisconnect,
    required ConnState transportState,
    required bool hasSession,
  }) {
    return hasQueuedReconnectFallback &&
        hasSeenDisconnect &&
        transportState == ConnState.connected &&
        hasSession;
  }

  @visibleForTesting
  static bool shouldAttemptInitialPrompt({
    required bool didAttemptInitialPrompt,
    required String initialPrompt,
    required bool canPrompt,
  }) {
    return !didAttemptInitialPrompt &&
        initialPrompt.trim().isNotEmpty &&
        canPrompt;
  }

  @visibleForTesting
  static bool shouldClearPromptPendingFromSessionSnapshot({
    required bool applyPendingTruth,
  }) {
    return applyPendingTruth;
  }

  @visibleForTesting
  static bool shouldClearCancelPendingFromSessionSnapshot({
    required bool applyPendingTruth,
    required SessionStatus sessionStatus,
  }) {
    return applyPendingTruth &&
        sessionStatus != SessionStatus.running &&
        sessionStatus != SessionStatus.waitingApproval;
  }

  @visibleForTesting
  static bool shouldRepairCachedSession({
    required SessionChatCacheEntry? entry,
    required bool hasRenderableVisibleState,
    int transcriptWatermark = 0,
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
    return transcriptWatermark > entry.lastAppliedSeq;
  }

  @visibleForTesting
  static bool shouldRetryRepairAfterSessionSnapshotSync({
    required ChatUiMode uiMode,
    required bool canRepair,
    required bool hasPendingRepair,
    required SessionChatCacheEntry? entry,
    required int transcriptWatermark,
    required bool isRebuilding,
    required bool hasActiveSessionLoad,
  }) {
    if (isRebuilding || hasActiveSessionLoad) {
      return false;
    }
    if (uiMode != ChatUiMode.viewOnly && uiMode != ChatUiMode.unsupported) {
      return false;
    }
    if (!hasPendingRepair) {
      return false;
    }
    return canRepair &&
        shouldRepairCachedSession(
          entry: entry,
          hasRenderableVisibleState: entry?.isRenderable ?? false,
          transcriptWatermark: transcriptWatermark,
        );
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
    required ConnState transportState,
    required bool isRecoveringAfterReconnect,
  }) {
    return uiMode == ChatUiMode.normal &&
        transportState == ConnState.connected &&
        !isRecoveringAfterReconnect;
  }

  @visibleForTesting
  static bool shouldToastSessionLoadError({
    required Object error,
    required bool preserveVisible,
  }) {
    return !preserveVisible || !isRecoverableSessionTransportError(error);
  }

  @visibleForTesting
  static ChatUiMode restoredUiModeAfterSessionLoadFailure(
    ChatUiMode previousUiMode,
  ) {
    if (previousUiMode == ChatUiMode.rebuildingReadonly) {
      return ChatUiMode.viewOnly;
    }
    return previousUiMode;
  }

  @visibleForTesting
  static String restoreUnavailableCopy({
    required String runtime,
    required String cwd,
    Object? restoreError,
  }) {
    if (restoreError != null) {
      final message = restoreError.toString().trim().replaceFirst(
        RegExp(r'^(Exception|Bad state|TimeoutException):\s*'),
        '',
      );
      if (message == 'missing runtime for session.load') {
        return Tx.chatRestoreMissingRuntime.tr;
      }
      if (message == 'missing cwd for session.load') {
        return Tx.chatRestoreMissingCwd.tr;
      }
      return Tx.chatRestoreErrorWith(message);
    }

    final missingRuntime = runtime.trim().isEmpty;
    final missingCwd = cwd.trim().isEmpty;
    if (!missingRuntime && !missingCwd) return Tx.chatUnsupportedRestore.tr;
    if (missingRuntime && missingCwd) return Tx.chatRestoreMissingBoth.tr;
    if (missingRuntime) return Tx.chatRestoreMissingRuntime.tr;
    return Tx.chatRestoreMissingCwd.tr;
  }

  @visibleForTesting
  static bool hasPersistableVisibleTranscript({
    required Iterable<Message> messages,
    required Map<String, ApprovalRequest> approvals,
    required List<PlanEntry> planEntries,
  }) {
    return messages.isNotEmpty ||
        approvals.isNotEmpty ||
        planEntries.isNotEmpty;
  }

  @visibleForTesting
  static bool shouldPromoteCacheOnClose({required ChatUiMode uiMode}) {
    return uiMode == ChatUiMode.normal;
  }

  late final String machineId;
  late final String sessionId;
  late final String routeCwd;
  late final ChatState chatState;
  final effectiveCwd = ''.obs;
  final uiMode = ChatUiMode.initialLoading.obs;
  final restoreUnavailableMessage = ''.obs;

  final messages = <Message>[].obs;
  final approvals = <String, ApprovalRequest>{}.obs;
  final planEntries = <PlanEntry>[].obs;
  final sessionStatus = SessionStatus.idle.obs;
  final currentMode = Rxn<ModeOption>();
  final availableModes = <ModeOption>[].obs;
  final runtimeId = ''.obs;
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
  final isChangingMode = false.obs;
  final pendingModeId = ''.obs;
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
  Rx<ConnState> get transportState => _wsRepo.connectionState;
  ConnState get currentTransportState => _wsRepo.connectionState.value;
  bool get canPrompt =>
      shouldEnableComposer(
        uiMode: uiMode.value,
        transportState: currentTransportState,
        isRecoveringAfterReconnect: isRecoveringAfterReconnect.value,
      ) &&
      !isPromptPending.value &&
      !isCancelingRun.value &&
      sessionStatus.value != SessionStatus.running &&
      sessionStatus.value != SessionStatus.waitingApproval;
  bool get canMutateSession =>
      uiMode.value == ChatUiMode.normal &&
      currentTransportState == ConnState.connected &&
      !isCancelingRun.value;
  bool get _shouldPromoteCache => uiMode.value == ChatUiMode.normal;
  bool get canReplyApprovals =>
      uiMode.value == ChatUiMode.normal &&
      currentTransportState == ConnState.connected;
  bool get canCancelRun =>
      uiMode.value == ChatUiMode.normal &&
      currentTransportState == ConnState.connected &&
      !isCancelingRun.value &&
      (sessionStatus.value == SessionStatus.running ||
          sessionStatus.value == SessionStatus.waitingApproval);
  bool get inputReadOnly => !canPrompt;

  /// Live usage info for this session (cost, tokens, context window).
  UsageInfo? get usageInfo => _eventRepo.liveUsageFor(sessionId);

  bool get hasModeOptions => currentMode.value != null;
  bool get canOpenModeDropdown {
    return canOpenModeDropdownFor(
      currentMode: currentMode.value,
      availableModes: availableModes,
      isChangingMode: isChangingMode.value,
    );
  }

  @visibleForTesting
  static bool canOpenModeDropdownFor({
    required ModeOption? currentMode,
    required List<ModeOption> availableModes,
    required bool isChangingMode,
  }) {
    if (isChangingMode) {
      return false;
    }
    if (currentMode == null || availableModes.length < 2) {
      return false;
    }
    for (final mode in availableModes) {
      if (mode.id == currentMode.id) {
        return true;
      }
    }
    return false;
  }

  String _browsePath = '';
  int _atPosition = -1;
  String _lastMentionQuery = '';
  Timer? _searchDebounce;

  AudioRecorder? _voiceRecorder;
  final hasSttConfig = false.obs;
  bool _userIsScrolling = false;
  bool _isAnimatingToBottom = false;
  bool _hasOptimisticUserMsg = false;
  final isPromptPending = false.obs;
  final isCancelingRun = false.obs;
  final pendingModelValue = ''.obs;
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
  final _rebuildBacklog = <AgentEvent>[];
  SessionChatCacheEntry? _lastCacheEntry;
  Future<void>? _sessionLoadFuture;
  bool _pendingTranscriptRepair = false;
  bool _pendingReconnectFallback = false;
  int _visibleTranscriptWatermark = 0;
  int _rebuildTranscriptWatermark = 0;
  String? _initialPrompt;
  bool _didAttemptInitialPrompt = false;
  ConnState _lastTransportState = ConnState.connected;

  StreamSubscription<AgentEvent>? _eventSub;
  StreamSubscription<void>? _sessionMetaSub;
  StreamSubscription<ReconnectRecoveryResult>? _recoverySub;
  Worker? _transportStateWorker;
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
    _lastTransportState = currentTransportState;

    scrollController.addListener(_onScrollChanged);
    inputController.addListener(_detectMention);
    _checkSttConfig();

    _syncSessionSnapshotFromRepository();

    _initialPrompt = args['initialPrompt'] as String?;
    final isNewSession = args['isNewSession'] as bool? ?? false;

    if (isNewSession) {
      _attachSubscriptions();
      _syncSessionSnapshotFromRepository();
      unawaited(_refreshSessionConfigInBackground());
      restoreUnavailableMessage.value = '';
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
    _subscribeTransportState();
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
      unawaited(_maybeResumeRepairAfterSessionSnapshotSync());
    });
  }

  void _subscribeRecoveryNotifications() {
    _recoverySub = _recovery.recoveries
        .where((result) => result.machineId == machineId)
        .listen((result) {
          unawaited(_handleRecoveryNotification(result));
        });
  }

  void _subscribeTransportState() {
    _transportStateWorker = ever<ConnState>(_wsRepo.connectionState, (state) {
      unawaited(_handleTransportStateChange(state));
    });
    if (currentTransportState == ConnState.disconnected) {
      _hasSeenDisconnect = true;
      _startForegroundReconnectRetry();
    } else if (currentTransportState == ConnState.reconnecting) {
      _hasSeenDisconnect = true;
    }
  }

  Future<void> _handleTransportStateChange(ConnState state) async {
    final previous = _lastTransportState;
    _lastTransportState = state;
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
      await _maybeRunQueuedReconnectFallback();
      _maybeSendInitialPrompt();
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
      _pendingTranscriptRepair = initialNeedsRepair;
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
    _pendingTranscriptRepair = needsRepair;
    if (!needsRepair) {
      unawaited(_refreshSessionConfigInBackground());
      restoreUnavailableMessage.value = '';
      uiMode.value = ChatUiMode.normal;
      _scrollToBottom();
      _maybeSendInitialPrompt();
      return;
    }

    if (!_canRepairSession()) {
      unawaited(_refreshSessionConfigInBackground());
      restoreUnavailableMessage.value = restoreUnavailableCopy(
        runtime: runtimeId.value,
        cwd: effectiveCwd.value,
      );
      uiMode.value = hydrated != null
          ? ChatUiMode.viewOnly
          : ChatUiMode.unsupported;
      isLoading.value = false;
      return;
    }

    await _performSessionLoad(preserveVisible: hydrated != null);
    unawaited(_refreshSessionConfigInBackground());
    _maybeSendInitialPrompt();
  }

  void _applyHydratedCache(SessionChatCacheHydrated hydrated) {
    chatState.replaceWith(hydrated.chatState);
    _visibleTranscriptWatermark = hydrated.entry.lastAppliedSeq;
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
      transcriptWatermark: _eventRepo.transcriptWatermarkFor(sessionId),
    );
  }

  bool _canRepairSession() {
    final runtime = runtimeId.value.trim();
    final cwdValue = effectiveCwd.value.trim();
    return runtime.isNotEmpty && cwdValue.isNotEmpty;
  }

  void _maybeSendInitialPrompt() {
    final prompt = _initialPrompt?.trim() ?? '';
    if (_didAttemptInitialPrompt) {
      return;
    }
    if (prompt.isEmpty) {
      _didAttemptInitialPrompt = true;
      return;
    }
    if (!shouldAttemptInitialPrompt(
      didAttemptInitialPrompt: _didAttemptInitialPrompt,
      initialPrompt: prompt,
      canPrompt: canPrompt,
    )) {
      return;
    }
    _didAttemptInitialPrompt = true;
    unawaited(sendMessage(prompt));
  }

  void _syncSessionSnapshotFromRepository({bool applyPendingTruth = false}) {
    final session = _eventRepo.sessionById(sessionId);
    if (session != null) {
      sessionStatus.value = session.status;
      if (isPromptPending.value &&
          shouldClearPromptPendingFromSessionSnapshot(
            applyPendingTruth: applyPendingTruth,
          )) {
        isPromptPending.value = false;
      }
      if (isCancelingRun.value &&
          shouldClearCancelPendingFromSessionSnapshot(
            applyPendingTruth: applyPendingTruth,
            sessionStatus: session.status,
          )) {
        isCancelingRun.value = false;
      }
      if (session.title.isNotEmpty) {
        sessionTitle.value = session.title;
      }
      if (session.runtime.isNotEmpty) {
        runtimeId.value = session.runtime;
      }
      if (session.cwd.isNotEmpty) {
        effectiveCwd.value = session.cwd;
      }
      _applyRepositoryConfigSnapshot(session.configSnapshot);
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
      if (isClosed || currentTransportState == ConnState.connected) {
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
      await _recovery.recoverMachine(
        machineId,
        transcriptMode: TranscriptRecoveryMode.replayIfPossible,
      );
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
      'transport=$currentTransportState '
      'hasSession=${_wsRepo.hasSession(machineId)} '
      'sessionReady=${result.sessionReady}',
    );
    _syncSessionSnapshotFromRepository(
      applyPendingTruth: result.knownSessionsOk || result.statusesOk,
    );
    if (!_hasSeenDisconnect) return;

    if (result.transcript == TranscriptRecoveryState.skipped) {
      unawaited(_refreshSessionConfigInBackground());
      return;
    }

    if (result.transcript == TranscriptRecoveryState.complete) {
      _pendingReconnectFallback = false;
      unawaited(_refreshSessionConfigInBackground());
      _hasSeenDisconnect = false;
      _maybeSendInitialPrompt();
      return;
    }
    final hasSession = _wsRepo.hasSession(machineId);
    if (shouldQueueReconnectFallback(
      result: result,
      hasSeenDisconnect: _hasSeenDisconnect,
      transportState: currentTransportState,
      hasSession: hasSession,
    )) {
      _pendingReconnectFallback = true;
      return;
    }
    if (!shouldTriggerReconnectFallback(
      result: result,
      hasSeenDisconnect: _hasSeenDisconnect,
      transportState: currentTransportState,
      hasSession: hasSession,
    )) {
      return;
    }

    await _runReconnectFallback();
  }

  Future<void> _maybeRunQueuedReconnectFallback() async {
    if (!shouldResumeQueuedReconnectFallback(
      hasQueuedReconnectFallback: _pendingReconnectFallback,
      hasSeenDisconnect: _hasSeenDisconnect,
      transportState: currentTransportState,
      hasSession: _wsRepo.hasSession(machineId),
    )) {
      return;
    }
    await _runReconnectFallback();
  }

  Future<void> _runReconnectFallback() async {
    _pendingReconnectFallback = false;
    debugPrint(
      '[ChatRecovery] session=$sessionId machine=$machineId '
      'triggering=session.load-fallback',
    );
    final refreshed = await _chatCacheRepo.reloadSession(sessionId);
    _lastCacheEntry = refreshed;
    _pendingTranscriptRepair = true;
    if (!_canRepairSession()) {
      unawaited(_refreshSessionConfigInBackground());
      if (refreshed != null && refreshed.isRenderable) {
        uiMode.value = ChatUiMode.viewOnly;
      } else {
        restoreUnavailableMessage.value = restoreUnavailableCopy(
          runtime: runtimeId.value,
          cwd: effectiveCwd.value,
        );
      }
      _maybeSendInitialPrompt();
      return;
    }
    await _performSessionLoad(
      preserveVisible:
          _hasVisibleTranscript || (refreshed?.isRenderable ?? false),
    );
    unawaited(_refreshSessionConfigInBackground());
    if (!isClosed) {
      _hasSeenDisconnect = false;
    }
    _maybeSendInitialPrompt();
  }

  void _applyRepositoryConfigSnapshot(SessionConfigSnapshot snapshot) {
    modelConfigId.value = snapshot.modelConfigId ?? '';
    currentModel.value = snapshot.currentModel;
    availableModels.value = snapshot.availableModels;
    availableModes.value = snapshot.availableModes;
    currentMode.value = snapshot.currentMode;
    if (pendingModeId.value.isNotEmpty &&
        currentMode.value?.id == pendingModeId.value) {
      pendingModeId.value = '';
      isChangingMode.value = false;
    }
    if (pendingModelValue.value.isNotEmpty &&
        currentModel.value == pendingModelValue.value) {
      pendingModelValue.value = '';
    }
    if (!canOpenModeDropdown) {
      showModeDropdown.value = false;
    }
  }

  Future<void> _maybeResumeRepairAfterSessionSnapshotSync() async {
    final repairStillNeeded = shouldRepairCachedSession(
      entry: _lastCacheEntry,
      hasRenderableVisibleState: _lastCacheEntry?.isRenderable ?? false,
      transcriptWatermark: _eventRepo.transcriptWatermarkFor(sessionId),
    );
    if (!repairStillNeeded) {
      _pendingTranscriptRepair = false;
    }
    if (!ChatViewModel.shouldRetryRepairAfterSessionSnapshotSync(
      uiMode: uiMode.value,
      canRepair: _canRepairSession(),
      hasPendingRepair: _pendingTranscriptRepair,
      entry: _lastCacheEntry,
      transcriptWatermark: _eventRepo.transcriptWatermarkFor(sessionId),
      isRebuilding: _isRebuilding,
      hasActiveSessionLoad: _sessionLoadFuture != null,
    )) {
      return;
    }
    await _performSessionLoad(
      preserveVisible:
          _hasVisibleTranscript || (_lastCacheEntry?.isRenderable ?? false),
    );
    unawaited(_refreshSessionConfigInBackground());
    _maybeSendInitialPrompt();
  }

  Future<void> _refreshSessionConfigInBackground() async {
    if (isClosed ||
        machineId.isEmpty ||
        currentTransportState != ConnState.connected ||
        _sessionLoadFuture != null) {
      return;
    }
    try {
      await _eventRepo.refreshSessionConfig(
        machineId: machineId,
        sessionId: sessionId,
        runtime: runtimeId.value.trim().isEmpty ? null : runtimeId.value.trim(),
      );
    } catch (e) {
      debugPrint('[ChatVM] refresh session config failed: $e');
    }
  }

  Future<void> _reconcileSessionTruthAfterAck() async {
    try {
      if (isClosed ||
          machineId.isEmpty ||
          currentTransportState != ConnState.connected) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (isClosed || currentTransportState != ConnState.connected) {
        return;
      }
      final result = await _eventRepo.syncKnownSessions(machineId);
      if (!result.ok) {
        debugPrint('[ChatVM] session truth reconcile failed: ${result.error}');
        return;
      }
      _syncSessionSnapshotFromRepository(applyPendingTruth: true);
    } catch (e) {
      debugPrint('[ChatVM] session truth reconcile threw: $e');
    }
  }

  Future<void> _clearModePendingAfterTimeout(String requestedModeId) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    if (isClosed || pendingModeId.value != requestedModeId) {
      return;
    }
    isChangingMode.value = false;
    pendingModeId.value = '';
  }

  Future<void> _clearModelPendingAfterTimeout(String requestedModel) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    if (isClosed || pendingModelValue.value != requestedModel) {
      return;
    }
    pendingModelValue.value = '';
  }

  Future<void> _clearCancelPendingAfterTimeout() async {
    await Future<void>.delayed(const Duration(seconds: 10));
    if (isClosed) {
      return;
    }
    isCancelingRun.value = false;
  }

  Future<void> _performSessionLoad({required bool preserveVisible}) async {
    final inFlight = _sessionLoadFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _runSessionLoad(preserveVisible: preserveVisible);
    _sessionLoadFuture = future;
    future.whenComplete(() {
      if (identical(_sessionLoadFuture, future)) {
        _sessionLoadFuture = null;
      }
    });
    return future;
  }

  Future<void> _runSessionLoad({required bool preserveVisible}) async {
    final loadToken = ++_recoveryEpoch;
    final loadRuntime = runtimeId.value.trim();
    final loadCwd = effectiveCwd.value.trim();
    final previousUiMode = uiMode.value;

    isRecoveringAfterReconnect.value = preserveVisible;
    if (preserveVisible) {
      _isRebuilding = true;
      _rebuildTranscriptWatermark = 0;
      _rebuildBacklog.clear();
      uiMode.value = ChatUiMode.rebuildingReadonly;
      isLoading.value = false;
    } else {
      _isRebuilding = true;
      _rebuildTranscriptWatermark = 0;
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
      final baselineConfigRevision = _eventRepo.sessionConfigRevisionFor(
        sessionId,
      );

      final response = await _wsRepo.loadSession(
        machineId: machineId,
        sessionId: sessionId,
        cwd: loadCwd,
        runtime: loadRuntime,
        permissionMode: mode.isNotEmpty && mode != 'default' ? mode : null,
        model: model,
      );
      if (!response.app.ok) {
        throw Exception('session.load failed');
      }
      if (response.app.sessionId != sessionId) {
        throw FormatException(
          'session.load returned sessionId ${response.app.sessionId} for $sessionId',
        );
      }

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
      await _eventRepo.applySessionLoadSnapshot(
        machineId: machineId,
        sessionId: sessionId,
        runtime: loadedRuntime.isNotEmpty ? loadedRuntime : loadRuntime,
        cwd: loadedCwd,
        title: response.app.title,
        status: response.app.status,
        updatedAt: response.app.updatedAt,
        baselineConfigRevision: baselineConfigRevision,
        configSnapshot: snapshot,
      );
      _syncSessionSnapshotFromRepository(applyPendingTruth: true);

      if (!response.app.replay.complete) {
        throw StateError('session.load replay incomplete');
      }

      final replayState = _buildChatStateFromScopedReplay(
        response.app.replay.events,
      );
      for (final event in _rebuildBacklog) {
        _applyTranscriptEventToState(
          event,
          replayState,
          updateVisibleCollections: false,
          allowOptimisticAdoption: false,
        );
      }

      final refreshedSession = _eventRepo.sessionById(sessionId);
      if (refreshedSession != null && refreshedSession.cwd.isNotEmpty) {
        effectiveCwd.value = refreshedSession.cwd;
      } else {
        effectiveCwd.value = loadedCwd;
      }

      chatState.replaceWith(replayState);
      _visibleTranscriptWatermark = _rebuildTranscriptWatermark;
      _syncVisibleStateFromChatState();
      _syncSessionSnapshotFromRepository();
      await _flushVisibleSnapshot(promoteReady: true, force: true);
      if (!isClosed && loadToken == _recoveryEpoch) {
        _pendingTranscriptRepair = false;
        restoreUnavailableMessage.value = '';
        uiMode.value = ChatUiMode.normal;
        isLoading.value = false;
      }
    } catch (e) {
      if (shouldToastSessionLoadError(
        error: e,
        preserveVisible: preserveVisible,
      )) {
        AppToast.show(
          restoreUnavailableCopy(
            runtime: loadRuntime,
            cwd: loadCwd,
            restoreError: e,
          ),
        );
      } else {
        debugPrint(
          '[ChatRecovery] session.load recovered with preserved UI: $e',
        );
      }
      if (preserveVisible) {
        if (!isClosed && loadToken == _recoveryEpoch) {
          uiMode.value = restoredUiModeAfterSessionLoadFailure(previousUiMode);
        }
      } else if (!isClosed && loadToken == _recoveryEpoch) {
        restoreUnavailableMessage.value = restoreUnavailableCopy(
          runtime: loadRuntime,
          cwd: loadCwd,
          restoreError: e,
        );
        uiMode.value = ChatUiMode.unsupported;
      }
    } finally {
      _isRebuilding = false;
      _rebuildTranscriptWatermark = 0;
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
    _visibleTranscriptWatermark = 0;
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

  bool get _hasPersistableVisibleTranscript => hasPersistableVisibleTranscript(
    messages: chatState.orderedMessages,
    approvals: chatState.approvals,
    planEntries: chatState.planEntries,
  );

  ChatState _buildChatStateFromScopedReplay(
    List<Map<String, dynamic>> replayEvents,
  ) {
    final target = ChatState(sessionId: sessionId);
    for (final payload in replayEvents) {
      final event = EventEnvelopeParser.parseScopedReplayEvent(
        payload,
        machineId: machineId,
      );
      _applyTranscriptEventToState(
        event,
        target,
        updateVisibleCollections: false,
        allowOptimisticAdoption: false,
      );
    }
    return target;
  }

  void _handleEvent(AgentEvent event) {
    _observeCommittedEventEvidence(event);
    if (_isRebuilding) {
      _rebuildBacklog.add(event);
      _rebuildTranscriptWatermark = _advanceTranscriptWatermark(
        _rebuildTranscriptWatermark,
        event,
      );
      return;
    }
    _visibleTranscriptWatermark = _advanceTranscriptWatermark(
      _visibleTranscriptWatermark,
      event,
    );
    _applyEventToState(event, chatState, updateVisibleCollections: true);
  }

  void _observeCommittedEventEvidence(AgentEvent event) {
    if (event.seq <= 0) return;
    if (isPromptPending.value) {
      final messagePart = event.messagePart;
      if (messagePart?.role == MessageRole.user ||
          event.type == EventType.sessionStatus ||
          event.type == EventType.runFinished ||
          event.type == EventType.runFailed) {
        isPromptPending.value = false;
      }
    }
    if (isCancelingRun.value && event.type == EventType.sessionStatus) {
      final status = event.session?.status;
      if (status != SessionStatus.running &&
          status != SessionStatus.waitingApproval) {
        isCancelingRun.value = false;
      }
    }
  }

  int _advanceTranscriptWatermark(int current, AgentEvent event) {
    if (!eventAffectsTranscript(event.type) || event.seq <= 0) {
      return current;
    }
    return event.seq > current ? event.seq : current;
  }

  int _persistedTranscriptWatermark() {
    final repoWatermark = _eventRepo.transcriptWatermarkFor(sessionId);
    return repoWatermark > _visibleTranscriptWatermark
        ? repoWatermark
        : _visibleTranscriptWatermark;
  }

  void _applyTranscriptEventToState(
    AgentEvent event,
    ChatState target, {
    required bool updateVisibleCollections,
    bool allowOptimisticAdoption = true,
  }) {
    switch (event.type) {
      case EventType.reasoning:
      case EventType.messageDelta:
        if (event.messagePart != null) {
          if (allowOptimisticAdoption &&
              shouldReplaceOptimisticUserMessage(
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
          }
        }

      case EventType.approvalReplied:
        if (event.approval != null) {
          target.resolveApproval(event.approval!.id);
          if (updateVisibleCollections) {
            _refreshApprovals();
          }
        }

      case EventType.runFailed:
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

      case EventType.planUpdated:
        final entries = event.planUpdate?.entries;
        if (entries != null) {
          target.updatePlan(entries);
          if (updateVisibleCollections) {
            planEntries.value = entries;
            _scheduleSnapshotWrite();
          }
        }

      case EventType.runFinished:
      case EventType.sessionStatus:
      case EventType.usageUpdate:
      case EventType.modeChanged:
      case EventType.modelChanged:
      case null:
        break;
    }
  }

  void _applyEventToState(
    AgentEvent event,
    ChatState target, {
    required bool updateVisibleCollections,
  }) {
    _applyTranscriptEventToState(
      event,
      target,
      updateVisibleCollections: updateVisibleCollections,
    );

    switch (event.type) {
      case EventType.reasoning:
      case EventType.messageDelta:
      case EventType.toolStarted:
      case EventType.toolUpdated:
      case EventType.toolCompleted:
      case EventType.toolFailed:
      case EventType.approvalRequested:
      case EventType.approvalReplied:
      case EventType.runFailed:
      case EventType.planUpdated:
        break;

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
        if (updateVisibleCollections) {
          usageVersion.value++;
        }

      case EventType.modeChanged:
        if (updateVisibleCollections) {
          _syncSessionSnapshotFromRepository();
        }

      case EventType.modelChanged:
        if (event.configChange != null && updateVisibleCollections) {
          _syncSessionSnapshotFromRepository();
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
    if (!canOpenModeDropdown) return;
    showModeDropdown.toggle();
  }

  Future<void> changeMode(ModeOption mode) async {
    if (!canMutateSession || isChangingMode.value) return;
    showModeDropdown.value = false;
    if (mode.id == currentMode.value?.id) return;

    isChangingMode.value = true;
    pendingModeId.value = mode.id;
    try {
      await _wsRepo.setMode(
        machineId: machineId,
        sessionId: sessionId,
        permissionMode: mode.id,
      );
      unawaited(_refreshSessionConfigInBackground());
      unawaited(_clearModePendingAfterTimeout(mode.id));
    } catch (e) {
      debugPrint('[ChatVM] changeMode failed: $e');
      isChangingMode.value = false;
      pendingModeId.value = '';
    }
  }

  Future<void> changeModel(String value) async {
    if (!canMutateSession) return;
    if (value == currentModel.value) return;
    final configId = modelConfigId.value;
    if (configId.isEmpty) return;

    debugPrint(
      '[ChatVM] changeModel: $currentModel → $value (configId=$configId)',
    );

    pendingModelValue.value = value;
    try {
      await _wsRepo.setConfigOption(
        machineId: machineId,
        sessionId: sessionId,
        configId: configId,
        value: value,
      );
      unawaited(_refreshSessionConfigInBackground());
      unawaited(_clearModelPendingAfterTimeout(value));
    } catch (e) {
      debugPrint('[ChatVM] changeModel failed: $e');
      pendingModelValue.value = '';
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

  void _scheduleSnapshotWrite() {
    _cacheWriteDebounce?.cancel();
    _cacheWriteDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_flushVisibleSnapshot(promoteReady: false));
    });
  }

  Future<void> _flushSnapshotForBackground() async {
    _cacheWriteDebounce?.cancel();
    _cacheWriteDebounce = null;
    await _flushVisibleSnapshot(promoteReady: _shouldPromoteCache, force: true);
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
          configSnapshot: _eventRepo.sessionConfigSnapshotFor(sessionId),
          cacheState: nextState,
          lastAppliedSeq: _persistedTranscriptWatermark(),
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
    return promoteReady
        ? SessionChatCacheState.ready
        : SessionChatCacheState.stale;
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
      AppToast.show(Tx.newRecordingPermissionDenied.tr);
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
      AppToast.show(Tx.newRecordingStartFailed.tr);
      isVoiceRecording.value = false;
      await _voiceRecorder!.dispose();
      _voiceRecorder = null;
      return;
    }

    if (!await _voiceRecorder!.isRecording()) {
      AppToast.show(Tx.newMicrophoneUnavailable.tr);
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
      AppToast.show(Tx.newRecordingFailed.tr);
      return;
    }

    final file = File(path);
    final size = await file.length();
    if (size < 100) {
      isVoiceRecording.value = false;
      AppToast.show(Tx.newNoAudioCaptured.tr);
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
      AppToast.show(Tx.transcriptionFailed(e));
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
      AppToast.show(Tx.chatReadOnly.tr);
      return;
    }
    if (showFilePicker.value) _dismissFilePicker();

    final trimmed = text.trim();
    final hasImages = pendingImages.isNotEmpty;
    if (trimmed.isEmpty && !hasImages) return;

    inputController.clear();

    // Snapshot pending images and clear state
    final imagesToSend = List<XFile>.from(pendingImages);
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
    isPromptPending.value = true;

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
      unawaited(_reconcileSessionTruthAfterAck());
    } catch (e) {
      debugPrint('Prompt rejected: $e');
      isPromptPending.value = false;
      _hasOptimisticUserMsg = false;
      chatState.messages.remove(userMsg.id);
      chatState.messageOrder.remove(userMsg.id);
      _refreshMessages();
      pendingImages.assignAll(imagesToSend);
      pendingPreviews.assignAll(previewsToSend);
      pendingMimeTypes.assignAll(mimeTypesToSend);
      inputController.text = text;
      inputController.selection = TextSelection.collapsed(
        offset: inputController.text.length,
      );
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
      unawaited(_reconcileSessionTruthAfterAck());
    } catch (e) {
      debugPrint('[ChatVM] replyApproval FAILED: $e');
    }
  }

  Future<void> cancelSession() async {
    if (!canCancelRun) return;
    isCancelingRun.value = true;
    try {
      await _wsRepo.cancelSession(machineId: machineId, sessionId: sessionId);
      unawaited(_reconcileSessionTruthAfterAck());
      unawaited(_clearCancelPendingAfterTimeout());
    } catch (e) {
      debugPrint('Failed to cancel session: $e');
      isCancelingRun.value = false;
    }
  }

  Future<bool> prepareForClose() async {
    _cacheWriteDebounce?.cancel();
    _cacheWriteDebounce = null;
    await _flushVisibleSnapshot(promoteReady: _shouldPromoteCache, force: true);
    return true;
  }

  @override
  void onClose() {
    _recoveryEpoch++;
    _cacheWriteDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _eventRepo.markNotViewing(sessionId);
    _eventSub?.cancel();
    _sessionMetaSub?.cancel();
    _recoverySub?.cancel();
    _transportStateWorker?.dispose();
    _searchDebounce?.cancel();
    _stopForegroundReconnectRetry();
    scrollController.dispose();
    inputController.removeListener(_detectMention);
    inputController.dispose();
    _voiceRecorder?.dispose();
    super.onClose();
  }
}
