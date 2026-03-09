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
import '../../data/repositories/ws_session_repository.dart';
import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/fs_entry.dart';
import '../../domain/model_info.dart';
import '../../domain/message.dart';
import '../../domain/permission_mode.dart';
import '../../domain/plan_entry.dart';
import '../../domain/usage_info.dart';
import '../../usecases/transcribe_audio.dart';
import '../../utils/app_toast.dart';
import 'chat_state.dart';
import 'widgets/mention_text_controller.dart';

class ChatViewModel extends GetxController {
  final EventRepository _eventRepo;
  final WsSessionRepository _wsRepo;
  final TranscribeAudioUseCase _transcribe;

  ChatViewModel({
    required EventRepository eventRepo,
    required WsSessionRepository wsRepo,
    required TranscribeAudioUseCase transcribe,
  })  : _eventRepo = eventRepo,
        _wsRepo = wsRepo,
        _transcribe = transcribe;

  late final String machineId;
  late final String sessionId;
  late final String cwd;
  late final ChatState chatState;

  final messages = <Message>[].obs;
  final approvals = <String, ApprovalRequest>{}.obs;
  final planEntries = <PlanEntry>[].obs;
  final sessionStatus = SessionStatus.idle.obs;
  final currentMode = Rxn<PermissionMode>();
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

  /// Live usage info for this session (cost, tokens, context window).
  UsageInfo? get usageInfo => _eventRepo.liveUsageFor(sessionId);

  String _browsePath = '';
  int _atPosition = -1;
  String _lastMentionQuery = '';
  Timer? _searchDebounce;

  AudioRecorder? _voiceRecorder;
  final hasSttConfig = false.obs;
  bool _userIsScrolling = false;
  bool _isProgrammaticScroll = false;
  bool _hasOptimisticUserMsg = false;
  int _scrollRequestId = 0;

  StreamSubscription<AgentEvent>? _eventSub;

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
      currentMode.value = PermissionMode.fromId(existing.mode);
    }

    _eventRepo.markViewing(sessionId);
    _eventRepo.markAsRead(sessionId);

    scrollController.addListener(_onScrollChanged);
    inputController.addListener(_detectMention);
    _subscribeEvents();
    _checkSttConfig();

    // Restore pending approvals for this session
    for (final approval in _eventRepo.pendingApprovals.values) {
      if (approval.sessionId == sessionId) {
        chatState.addApproval(approval);
      }
    }
    _refreshApprovals();

    final initialPrompt = args['initialPrompt'] as String?;
    final isNewSession = args['isNewSession'] as bool? ?? false;

    if (isNewSession) {
      // New sessions are already created via session.create — skip load.
      // Apply configOptions from the create response (synchronous, no event timing issues).
      final configOptions = args['configOptions'] as List<dynamic>?;
      debugPrint('[ChatVM] new session configOptions: ${configOptions?.length} items');
      if (configOptions != null) {
        for (final item in configOptions) {
          debugPrint('[ChatVM]   item type=${item.runtimeType} keys=${item is Map ? (item as Map).keys.toList() : "N/A"}');
          if (item is Map) debugPrint('[ChatVM]   item=$item');
        }
      }
      if (configOptions != null) {
        _applyConfigOptions(configOptions);
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

  void _applyConfigOptions(List<dynamic> configOptions) {
    debugPrint('[ChatVM] _applyConfigOptions called with ${configOptions.length} items');
    for (final raw in configOptions) {
      debugPrint('[ChatVM]   raw item type: ${raw.runtimeType}, value: $raw');
      if (raw is! Map<String, dynamic>) continue;
      final category = raw['category'] as String? ?? '';
      debugPrint('[ChatVM]   category: $category');
      if (category == 'model') {
        modelConfigId.value = raw['id'] as String? ?? '';
        currentModel.value = raw['currentValue'] as String?;
        final rawValues = raw['options'] as List? ?? [];
        availableModels.value = rawValues
            .map((v) => ModelInfo.fromJson(v as Map<String, dynamic>))
            .toList();
      }
    }
  }

  Future<void> _loadSession() async {
    try {
      if (cwd.isEmpty) {
        throw Exception('missing cwd for session.load');
      }
      final session = _eventRepo.sessionById(sessionId);
      final mode = session?.mode ?? '';
      final model = session?.model ?? '';
      final params = <String, dynamic>{
        'sessionId': sessionId,
        'cwd': cwd,
        if (mode.isNotEmpty && mode != 'default') 'permissionMode': mode,
        if (model.isNotEmpty && model != 'default') 'model': model,
      };
      final result = await _wsRepo.callRpc(
        machineId: machineId,
        method: 'session.load',
        params: params,
      );
      final configOptions = result['configOptions'] as List<dynamic>?;
      debugPrint('[ChatVM] load session configOptions: ${configOptions?.length} items');
      if (configOptions != null) {
        for (final item in configOptions) {
          debugPrint('[ChatVM] load item type=${item.runtimeType} keys=${item is Map ? (item as Map).keys.toList() : "N/A"}');
        }
        _applyConfigOptions(configOptions);
      }
    } catch (e) {
      debugPrint('Failed to load session: $e');
    } finally {
      isLoading.value = false;
      _scheduleScrollStateSync();
    }
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
          _refreshMessages();
        }

      case EventType.messageFinal:
        if (event.message != null) {
          chatState.finalizeMessage(event.message!);
          _refreshMessages();
        }

      case EventType.toolStarted:
      case EventType.toolUpdated:
      case EventType.toolCompleted:
      case EventType.toolFailed:
        if (event.tool != null) {
          chatState.applyToolEvent(event.tool!);
          _refreshMessages();
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
        sessionStatus.value = SessionStatus.done;
        usageVersion.value++;

      case EventType.runFailed:
        _hasOptimisticUserMsg = false;
        sessionStatus.value = SessionStatus.error;
        if (event.error != null && event.error!.message.isNotEmpty) {
          final errorMsg = Message(
            id: 'error-${event.at.millisecondsSinceEpoch}',
            sessionId: sessionId,
            role: MessageRole.agent,
            parts: [MessagePart(type: PartType.text, text: event.error!.message)],
            createdAt: event.at,
          );
          chatState.finalizeMessage(errorMsg);
          _refreshMessages();
        }

      case EventType.planUpdated:
        final rawEntries = event.data?['entries'] as List?;
        if (rawEntries != null) {
          final entries = rawEntries
              .map((e) => PlanEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          chatState.updatePlan(entries);
          planEntries.value = entries;
        }

      case EventType.modeChanged:
        final modeId = event.data?['currentModeId'] as String?;
        currentMode.value = PermissionMode.fromId(modeId);

      case EventType.modelChanged:
        if (event.data != null) {
          currentModel.value = event.data!['currentValue'] as String?;
          modelConfigId.value = event.data!['configId'] as String? ?? '';
          final rawValues = event.data!['values'] as List? ?? [];
          availableModels.value = rawValues
              .map((v) => ModelInfo.fromJson(v as Map<String, dynamic>))
              .toList();
        }

      case EventType.connectionState:
        final state = event.data?['state'] as String? ?? 'connected';
        connState.value = ConnState.fromValue(state);

      default:
        break;
    }
  }

  bool get _isAtBottom {
    if (!scrollController.hasClients) return true;
    final pos = scrollController.position;
    return pos.maxScrollExtent - pos.pixels <= 100;
  }

  void _onScrollChanged() {
    if (_isProgrammaticScroll) return;
    if (showModeDropdown.value) showModeDropdown.value = false;
    _syncScrollState();
  }

  void toggleModeDropdown() => showModeDropdown.toggle();

  Future<void> changeMode(PermissionMode mode) async {
    showModeDropdown.value = false;
    if (mode == currentMode.value) return;

    final previous = currentMode.value;
    currentMode.value = mode;

    try {
      await _wsRepo.callRpc(
        machineId: machineId,
        method: 'session.setMode',
        params: {'sessionId': sessionId, 'permissionMode': mode.id},
      );
    } catch (e) {
      debugPrint('[ChatVM] changeMode failed: $e');
      currentMode.value = previous;
    }
  }

  Future<void> changeModel(String value) async {
    if (value == currentModel.value) return;
    final configId = modelConfigId.value;
    if (configId.isEmpty) return;

    debugPrint('[ChatVM] changeModel: $currentModel → $value (configId=$configId)');
    final previous = currentModel.value;
    currentModel.value = value;

    try {
      final result = await _wsRepo.callRpc(
        machineId: machineId,
        method: 'session.setConfigOption',
        params: {
          'sessionId': sessionId,
          'configId': configId,
          'value': value,
        },
      );
      debugPrint('[ChatVM] changeModel success: $result');
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
      if (_isProgrammaticScroll || !scrollController.hasClients) return;
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

    final requestId = ++_scrollRequestId;
    _isProgrammaticScroll = true;
    if (force) {
      _setFollowBottom(false);
    }

    Future<void> doScroll() async {
      try {
        for (var i = 0; i < 8; i++) {
          if (requestId != _scrollRequestId) return;

          if (!scrollController.hasClients) {
            await Future<void>.delayed(const Duration(milliseconds: 16));
            continue;
          }

          final position = scrollController.position;
          final target = position.maxScrollExtent;
          final remaining = target - position.pixels;

          if (remaining > 1) {
            if (animated) {
              await scrollController.animateTo(
                target,
                duration: Duration(milliseconds: i == 0 ? 240 : 140),
                curve: Curves.easeOutCubic,
              );
            } else {
              scrollController.jumpTo(target);
            }
          }

          await Future<void>.delayed(const Duration(milliseconds: 16));

          if (requestId != _scrollRequestId || !scrollController.hasClients) {
            return;
          }

          final settledRemaining =
              scrollController.position.maxScrollExtent -
              scrollController.position.pixels;
          if (settledRemaining <= 1) {
            await Future<void>.delayed(const Duration(milliseconds: 16));
            if (requestId != _scrollRequestId || !scrollController.hasClients) {
              return;
            }
            final finalRemaining =
                scrollController.position.maxScrollExtent -
                scrollController.position.pixels;
            if (finalRemaining <= 1) {
              break;
            }
          }
        }
      } finally {
        if (requestId == _scrollRequestId) {
          _isProgrammaticScroll = false;
          _scheduleScrollStateSync();
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (requestId != _scrollRequestId) return;
      unawaited(doScroll());
    });
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
      await _voiceRecorder!.start(const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ), path: path);
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
      final result = await _wsRepo.callRpc(
        machineId: machineId,
        method: 'fs.list',
        params: {'sessionId': sessionId, 'path': path},
      );
      final raw = result['entries'] as List? ?? [];
      final entries = raw
          .map((e) => FsEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      filePickerEntries.value = entries;
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
      final result = await _wsRepo.callRpc(
        machineId: machineId,
        method: 'fs.search',
        params: {'sessionId': sessionId, 'query': query},
      );
      final raw = result['results'] as List? ?? [];
      final entries = raw
          .map((e) => FsEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      filePickerEntries.value = entries;
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
      parts.add(MessagePart(
        type: PartType.media,
        media: MediaPart(
          base64: base64Encode(previewsToSend[i]),
          mimeType: mimeTypesToSend[i],
        ),
      ));
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
    final content = <Map<String, dynamic>>[];
    for (var i = 0; i < previewsToSend.length; i++) {
      content.add({
        'type': 'image',
        'mimeType': mimeTypesToSend[i],
        'data': base64Encode(previewsToSend[i]),
      });
    }
    if (trimmed.isNotEmpty) {
      content.add({'type': 'text', 'text': trimmed});
    }

    // Await ACK from daemon — prompt runs asynchronously on daemon side,
    // so this returns quickly. Failure means daemon rejected the request.
    try {
      await _wsRepo.callRpc(
        machineId: machineId,
        method: 'session.prompt',
        params: {'sessionId': sessionId, 'content': content},
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
      await _wsRepo.callRpc(
        machineId: machineId,
        method: 'approval.reply',
        params: {
          'sessionId': sessionId,
          'requestId': requestId,
          'optionId': optionId,
        },
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
      await _wsRepo.callRpc(
        machineId: machineId,
        method: 'session.cancel',
        params: {'sessionId': sessionId},
      );
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
    _eventRepo.markNotViewing(sessionId);
    _eventSub?.cancel();
    _searchDebounce?.cancel();
    scrollController.dispose();
    inputController.removeListener(_detectMention);
    inputController.dispose();
    _voiceRecorder?.dispose();
    super.onClose();
  }
}
