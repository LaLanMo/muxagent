import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/stt_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/message.dart';
import '../../domain/permission_mode.dart';
import '../../domain/plan_entry.dart';
import '../../usecases/transcribe_audio.dart';
import '../../utils/app_toast.dart';
import 'chat_state.dart';

class ChatViewModel extends GetxController {
  final EventRepository _eventRepo;
  final WsSessionRepository _wsRepo;
  final SttRepository _sttRepo;
  final TranscribeAudioUseCase _transcribe;

  ChatViewModel({
    required EventRepository eventRepo,
    required WsSessionRepository wsRepo,
    required SttRepository sttRepo,
    required TranscribeAudioUseCase transcribe,
  })  : _eventRepo = eventRepo,
        _wsRepo = wsRepo,
        _sttRepo = sttRepo,
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
  final inputController = TextEditingController();
  final scrollController = ScrollController();
  final isVoiceRecording = false.obs;
  final isTranscribing = false.obs;

  AudioRecorder? _voiceRecorder;
  final hasSttConfig = false.obs;
  bool _userIsScrolling = false;
  bool _isProgrammaticScroll = false;
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

    scrollController.addListener(_onScrollChanged);
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

  Future<void> _loadSession() async {
    try {
      if (cwd.isEmpty) {
        throw Exception('missing cwd for session.load');
      }
      final mode = _eventRepo.sessionById(sessionId)?.mode ?? '';
      final params = <String, dynamic>{
        'sessionId': sessionId,
        'cwd': cwd,
        if (mode.isNotEmpty && mode != 'default') 'permissionMode': mode,
      };
      await _wsRepo.callRpc(
        machineId: machineId,
        method: 'session.load',
        params: params,
      );
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

      case EventType.runFinished:
        sessionStatus.value = SessionStatus.done;

      case EventType.runFailed:
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
    if (_isProgrammaticScroll) {
      return;
    }
    _syncScrollState();
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
    messages.value = chatState.orderedMessages;
    _scrollToBottom();
    _scheduleScrollStateSync();
  }

  void _refreshApprovals() {
    approvals.value = Map.from(chatState.approvals);
    _scrollToBottom();
    _scheduleScrollStateSync();
  }

  Future<void> pickImage() async {
    final remaining = 20 - pendingImages.length;
    if (remaining <= 0) return;
    final images = await ImagePicker().pickMultiImage(limit: remaining);
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
    hasSttConfig.value = await _sttRepo.hasConfig();
  }

  Future<void> startVoiceInput() async {
    _voiceRecorder = AudioRecorder();
    if (!await _voiceRecorder!.hasPermission()) {
      AppToast.show('Microphone permission denied');
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
      await _voiceRecorder!.dispose();
      _voiceRecorder = null;
      return;
    }

    if (!await _voiceRecorder!.isRecording()) {
      AppToast.show('Microphone unavailable');
      await _voiceRecorder!.dispose();
      _voiceRecorder = null;
      return;
    }

    isVoiceRecording.value = true;
  }

  Future<void> stopVoiceInput() async {
    if (_voiceRecorder == null) return;

    final path = await _voiceRecorder!.stop();
    isVoiceRecording.value = false;
    await _voiceRecorder!.dispose();
    _voiceRecorder = null;

    if (path == null) {
      AppToast.show('Recording failed');
      return;
    }

    final file = File(path);
    final size = await file.length();
    if (size < 100) {
      AppToast.show('No audio captured — microphone may be unavailable');
      try {
        await file.delete();
      } catch (_) {}
      return;
    }

    isTranscribing.value = true;
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

  Future<void> sendMessage(String text) async {
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
    _eventSub?.cancel();
    scrollController.dispose();
    inputController.dispose();
    _voiceRecorder?.dispose();
    super.onClose();
  }
}
