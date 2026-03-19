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

class ChatViewModel extends GetxController {
  final EventRepository _eventRepo;
  final ReconnectRecoveryCoordinator _recovery;
  final WsSessionRepository _wsRepo;
  final TranscribeAudioUseCase _transcribe;

  ChatViewModel({
    required EventRepository eventRepo,
    required ReconnectRecoveryCoordinator recovery,
    required WsSessionRepository wsRepo,
    required TranscribeAudioUseCase transcribe,
  }) : _eventRepo = eventRepo,
       _recovery = recovery,
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

  late final String machineId;
  late final String sessionId;
  late final String cwd;
  late final ChatState chatState;

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
  Completer<void>? _historyCompleter;
  Timer? _historyTimeout;
  int _scrollRequestId = 0;
  bool _hasSeenDisconnect = false;
  bool _foregroundRecoveryInFlight = false;
  int _recoveryEpoch = 0;

  StreamSubscription<AgentEvent>? _eventSub;
  StreamSubscription<void>? _sessionMetaSub;
  StreamSubscription<ReconnectRecoveryResult>? _recoverySub;
  Worker? _connStateWorker;
  Timer? _foregroundReconnectTimer;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>;
    machineId = args['machineId'] as String;
    sessionId = args['sessionId'] as String;
    cwd = args['cwd'] as String? ?? '';
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
    }
    runtimeId.value = (args['runtime'] as String?) ?? runtimeId.value;

    _eventRepo.markViewing(sessionId);
    _eventRepo.markAsRead(sessionId);
    connState.value = _wsRepo.connectionState.value;

    scrollController.addListener(_onScrollChanged);
    inputController.addListener(_detectMention);
    _subscribeEvents();
    _subscribeSessionSnapshot();
    _subscribeRecoveryNotifications();
    _subscribeConnectionState();
    _checkSttConfig();

    _syncSessionSnapshotFromRepository();

    final initialPrompt = args['initialPrompt'] as String?;
    final isNewSession = args['isNewSession'] as bool? ?? false;

    if (isNewSession) {
      // New sessions are already created via session.create — skip load.
      final configSnapshot = args['configSnapshot'] as SessionConfigSnapshot?;
      if (configSnapshot != null) {
        _applyConfigSnapshot(configSnapshot);
      }
      isLoading.value = false;
      _scheduleScrollStateSync();
      if (initialPrompt != null && initialPrompt.isNotEmpty) {
        sendMessage(initialPrompt);
      }
    } else {
      _loadSession().then((_) {
        _scrollToBottom();
        if (initialPrompt != null && initialPrompt.isNotEmpty) {
          sendMessage(initialPrompt);
        }
      });
    }
  }

  void _subscribeEvents() {
    _eventSub = _eventRepo.events
        .where((e) => e.sessionId == sessionId)
        .listen(_handleEvent);
  }

  void _subscribeSessionSnapshot() {
    _sessionMetaSub = _eventRepo.sessionsChanged.listen((_) {
      if (isClosed) return;
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
      if (session.model != null && session.model!.isNotEmpty) {
        currentModel.value = session.model;
      }
      final mode = _resolveMode(session.mode);
      if (mode != null) {
        currentMode.value = mode;
      }
    }

    chatState.approvals
      ..clear()
      ..addEntries(
        _eventRepo
            .approvalsForSession(sessionId)
            .map((approval) => MapEntry(approval.id, approval)),
      );
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
    await _reloadSessionAfterReconnect();
    if (!isClosed) {
      _hasSeenDisconnect = false;
    }
  }

  void _applyConfigSnapshot(SessionConfigSnapshot snapshot) {
    modelConfigId.value = snapshot.modelConfigId ?? '';
    currentModel.value = snapshot.currentModel;
    availableModels.value = snapshot.availableModels;
    availableModes.value = snapshot.availableModes;
    currentMode.value = snapshot.currentMode;
  }

  Future<void> _loadSession() async {
    _historyCompleter = Completer<void>();
    try {
      if (cwd.isEmpty) throw Exception('missing cwd for session.load');
      if (runtimeId.value.isEmpty) {
        throw Exception('missing runtime for session.load');
      }
      final session = _eventRepo.sessionById(sessionId);
      final mode = session?.mode ?? '';
      final model = session?.model ?? '';

      final response = await _wsRepo.loadSession(
        machineId: machineId,
        sessionId: sessionId,
        cwd: cwd,
        runtime: runtimeId.value,
        permissionMode: mode.isNotEmpty && mode != 'default' ? mode : null,
        model: model,
      );

      // Apply config BEFORE waiting for history — immune to event race.
      final loadedRuntime = response.app.runtime;
      if (loadedRuntime.isNotEmpty) runtimeId.value = loadedRuntime;
      final snapshot = SessionConfigMapper.snapshotFromConfigOptions(
        runtimeId: runtimeId.value,
        configOptions: response.acp.configOptions ?? const [],
        modes: response.acp.modes,
      );
      _applyConfigSnapshot(snapshot);

      // Safety timeout — cancellable Timer, not Future.delayed.
      _historyTimeout = Timer(const Duration(seconds: 30), () {
        if (!isClosed &&
            _historyCompleter != null &&
            !_historyCompleter!.isCompleted) {
          _historyCompleter!.complete();
        }
      });

      // Wait for history.complete signal (or timeout).
      await _historyCompleter!.future;
    } catch (e) {
      AppToast.show('$e');
    } finally {
      _historyTimeout?.cancel();
      _historyTimeout = null;
      _historyCompleter = null;
      if (!isClosed) {
        isLoading.value = false;
        _refreshMessages();
        _scheduleScrollStateSync();
      }
    }
  }

  Future<void> _reloadSessionAfterReconnect() async {
    if (isRecoveringAfterReconnect.value || isClosed) return;

    // Guard against stale async completions mutating a newer replay attempt.
    final token = ++_recoveryEpoch;
    isRecoveringAfterReconnect.value = true;
    _hasOptimisticUserMsg = false;
    // Clear rebuild-sensitive state before daemon replay to avoid duplicate
    // messages, tool activity, and approval cards after session.load.
    _resetTranscriptState();
    _syncSessionSnapshotFromRepository();
    isLoading.value = true;

    try {
      await _loadSession();
    } finally {
      if (!isClosed && token == _recoveryEpoch) {
        isRecoveringAfterReconnect.value = false;
        _syncSessionSnapshotFromRepository();
      }
    }
  }

  void _resetTranscriptState() {
    chatState.reset();
    messages.clear();
    approvals.clear();
    planEntries.clear();
    showScrollToBottomButton.value = false;
    _userIsScrolling = false;
    _isProgrammaticScroll = false;
    _scrollRequestId++;
  }

  void _handleEvent(AgentEvent event) {
    switch (event.type) {
      case EventType.reasoning:
      case EventType.messageDelta:
        if (event.messagePart != null) {
          // Skip user message echoes when we already show the optimistic
          // version created in sendMessage(). During session.load history
          // replay _hasOptimisticUserMsg is false so messages pass through.
          if (_hasOptimisticUserMsg &&
              event.messagePart!.role == MessageRole.user) {
            break;
          }
          chatState.applyDelta(event.messagePart!);
          if (!isLoading.value) _refreshMessages();
        }

      case EventType.toolStarted:
      case EventType.toolUpdated:
      case EventType.toolCompleted:
      case EventType.toolFailed:
        if (event.tool != null) {
          chatState.applyToolEvent(event.tool!);
          if (!isLoading.value) _refreshMessages();
        }

      case EventType.approvalRequested:
        if (event.approval != null) {
          chatState.addApproval(event.approval!);
          _refreshApprovals();
          sessionStatus.value = SessionStatus.waitingApproval;
        }

      case EventType.approvalReplied:
        if (event.approval != null) {
          chatState.resolveApproval(event.approval!.id);
          _refreshApprovals();
        }

      case EventType.sessionStatus:
        if (event.session != null) {
          sessionStatus.value = event.session!.status;
          if (event.session!.title.isNotEmpty) {
            sessionTitle.value = event.session!.title;
          }
        }

      case EventType.usageUpdate:
        usageVersion.value++;

      case EventType.runFinished:
        _hasOptimisticUserMsg = false;
        sessionStatus.value = SessionStatus.idle;
        usageVersion.value++;

      case EventType.runFailed:
        _hasOptimisticUserMsg = false;
        sessionStatus.value = SessionStatus.error;
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
          chatState.finalizeMessage(errorMsg);
          if (!isLoading.value) _refreshMessages();
        }

      case EventType.planUpdated:
        final entries = event.planUpdate?.entries;
        if (entries != null) {
          chatState.updatePlan(entries);
          planEntries.value = entries;
        }

      case EventType.modeChanged:
        currentMode.value = _resolveMode(event.modeChange?.currentModeId);

      case EventType.modelChanged:
        if (event.configChange != null) {
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
        }

      case EventType.historyComplete:
        if (_historyCompleter != null && !_historyCompleter!.isCompleted) {
          _historyCompleter!.complete();
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
    if (isRecoveringAfterReconnect.value) {
      AppToast.show('Reconnecting chat. Please wait.');
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

  @override
  void onClose() {
    if (_historyCompleter != null && !_historyCompleter!.isCompleted) {
      _historyCompleter!.complete();
    }
    _historyTimeout?.cancel();
    _recoveryEpoch++;
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
