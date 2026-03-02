import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/message.dart';
import '../../domain/plan_entry.dart';
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
  final planEntries = <PlanEntry>[].obs;
  final sessionStatus = SessionStatus.idle.obs;
  final connState = ConnState.connected.obs;
  final sessionTitle = ''.obs;
  final isLoading = true.obs;
  final showScrollToBottomButton = false.obs;
  final inputController = TextEditingController();
  final scrollController = ScrollController();
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
    }

    scrollController.addListener(_onScrollChanged);
    _subscribeEvents();

    // Restore pending approvals for this session
    for (final approval in _eventRepo.pendingApprovals.values) {
      if (approval.sessionId == sessionId) {
        chatState.addApproval(approval);
      }
    }
    _refreshApprovals();

    final initialPrompt = args['initialPrompt'] as String?;
    _loadSession().then((_) {
      _scrollToBottom();
      if (initialPrompt != null && initialPrompt.isNotEmpty) {
        sendMessage(initialPrompt);
      }
    });
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
      _scheduleScrollStateSync();
    }
  }

  void _handleEvent(AgentEvent event) {
    debugPrint(
      '[Event] ${event.type?.value ?? 'null'}'
      '${event.messagePart != null ? ' part=${event.messagePart!.partType}' : ''}'
      '${event.tool != null ? ' tool=${event.tool!.name}(${event.tool!.status.value})' : ''}'
      '${event.data != null ? ' data=${event.data}' : ''}',
    );

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
          debugPrint(
            '[Approval] tool=${event.approval!.toolName} '
            'options=${event.approval!.options.map((o) => '${o.name}(${o.kind}:${o.optionId})').toList()}',
          );
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

      case EventType.planUpdated:
        final rawEntries = event.data?['entries'] as List?;
        if (rawEntries != null) {
          final entries = rawEntries
              .map((e) => PlanEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          chatState.updatePlan(entries);
          planEntries.value = entries;
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
    _setFollowBottom(false);
    _scrollToBottom();
    sessionStatus.value = SessionStatus.running;
    _eventRepo.setSessionStatus(sessionId, SessionStatus.running);

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
    debugPrint(
      '[ChatVM] replyApproval requestId=$requestId optionId=$optionId',
    );
    try {
      final result = await _wsRepo.callRpc(
        machineId: machineId,
        method: 'approval.reply',
        params: {
          'sessionId': sessionId,
          'requestId': requestId,
          'optionId': optionId,
        },
      );
      debugPrint('[ChatVM] replyApproval success: $result');
      chatState.resolveApproval(requestId);
      _refreshApprovals();
      sessionStatus.value = SessionStatus.running;
      _eventRepo.setSessionStatus(sessionId, SessionStatus.running);
    } catch (e) {
      debugPrint('[ChatVM] replyApproval FAILED: $e');
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
    scrollController.dispose();
    inputController.dispose();
    super.onClose();
  }
}
