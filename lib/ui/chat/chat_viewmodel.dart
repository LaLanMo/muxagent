import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/message.dart';
import 'chat_state.dart';

class ChatViewModel extends GetxController {
  final EventRepository _eventRepo = Get.find<EventRepository>();
  final WsSessionRepository _wsRepo = Get.find<WsSessionRepository>();

  late final String machineId;
  late final String sessionId;
  late final String cwd;
  late final ChatState chatState;

  final messages = <Message>[].obs;
  final approvals = <String, ApprovalRequest>{}.obs;
  final sessionStatus = SessionStatus.idle.obs;
  final sessionTitle = ''.obs;
  final isLoading = true.obs;
  final inputController = TextEditingController();

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

    _subscribeEvents();
    _loadSession();
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
      await _wsRepo.callRpc(
        machineId: machineId,
        method: 'session.load',
        params: {'sessionId': sessionId, 'cwd': cwd},
      );
    } catch (e) {
      debugPrint('Failed to load session: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _handleEvent(AgentEvent event) {
    switch (event.type) {
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

      default:
        break;
    }
  }

  void _refreshMessages() {
    messages.value = chatState.orderedMessages;
  }

  void _refreshApprovals() {
    approvals.value = Map.from(chatState.approvals);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final trimmed = text.trim();
    inputController.clear();

    // Optimistic insert of user message
    final userMsg = Message(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      sessionId: sessionId,
      role: MessageRole.user,
      parts: [MessagePart(type: PartType.text, text: trimmed)],
      createdAt: DateTime.now(),
    );
    chatState.finalizeMessage(userMsg);
    _refreshMessages();
    sessionStatus.value = SessionStatus.running;

    // Fire-and-forget: the prompt RPC blocks until the agent finishes,
    // but the UI is event-driven (messageDelta, runFinished, etc.).
    _wsRepo
        .callRpc(
          machineId: machineId,
          method: 'session.prompt',
          params: {'sessionId': sessionId, 'text': trimmed},
        )
        .then((_) {
          // Prompt completed; status is updated via events.
        })
        .catchError((e) {
          debugPrint('Prompt RPC error (non-fatal): $e');
        });
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
    } catch (e) {
      debugPrint('Failed to reply approval: $e');
    }
  }

  Future<void> cancelSession() async {
    try {
      await _wsRepo.callRpc(
        machineId: machineId,
        method: 'session.cancel',
        params: {'sessionId': sessionId},
      );
    } catch (e) {
      debugPrint('Failed to cancel session: $e');
    }
  }

  @override
  void onClose() {
    _eventSub?.cancel();
    inputController.dispose();
    super.onClose();
  }
}
