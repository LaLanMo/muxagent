import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/session_chat_cache_dto.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/event.dart';
import 'package:muxagent/domain/message.dart';
import 'package:muxagent/ui/chat/chat_state.dart';
import 'package:muxagent/ui/chat/chat_viewmodel.dart';

void main() {
  ReconnectRecoveryResult buildResult({
    required TranscriptRecoveryState transcript,
    required MetadataRecoveryState metadata,
    bool sessionReady = true,
  }) {
    return ReconnectRecoveryResult(
      machineId: 'machine-1',
      transcript: transcript,
      metadata: metadata,
      resyncOutcome: ResyncOutcome.complete,
      sessionReady: sessionReady,
      statusesOk: metadata != MetadataRecoveryState.degraded,
      titlesOk: metadata != MetadataRecoveryState.degraded,
      approvalsOk: metadata != MetadataRecoveryState.degraded,
    );
  }

  group('ChatViewModel reconnect fallback rule', () {
    test(
      'allows fallback only for fallbackNeeded transcript on active chat',
      () {
        final shouldFallback = ChatViewModel.shouldTriggerReconnectFallback(
          result: buildResult(
            transcript: TranscriptRecoveryState.fallbackNeeded,
            metadata: MetadataRecoveryState.complete,
          ),
          hasSeenDisconnect: true,
          connState: ConnState.connected,
          hasSession: true,
        );

        expect(shouldFallback, isTrue);
      },
    );

    test('does not fallback for metadata-only degradation', () {
      final shouldFallback = ChatViewModel.shouldTriggerReconnectFallback(
        result: buildResult(
          transcript: TranscriptRecoveryState.complete,
          metadata: MetadataRecoveryState.degraded,
        ),
        hasSeenDisconnect: true,
        connState: ConnState.connected,
        hasSession: true,
      );

      expect(shouldFallback, isFalse);
    });

    test('does not fallback when transcript recovery failed', () {
      final shouldFallback = ChatViewModel.shouldTriggerReconnectFallback(
        result: buildResult(
          transcript: TranscriptRecoveryState.failed,
          metadata: MetadataRecoveryState.skipped,
          sessionReady: false,
        ),
        hasSeenDisconnect: true,
        connState: ConnState.connected,
        hasSession: false,
      );

      expect(shouldFallback, isFalse);
    });

    test('does not fallback without a disconnect edge', () {
      final shouldFallback = ChatViewModel.shouldTriggerReconnectFallback(
        result: buildResult(
          transcript: TranscriptRecoveryState.fallbackNeeded,
          metadata: MetadataRecoveryState.complete,
        ),
        hasSeenDisconnect: false,
        connState: ConnState.connected,
        hasSession: true,
      );

      expect(shouldFallback, isFalse);
    });

    test('does not fallback without an active session', () {
      final shouldFallback = ChatViewModel.shouldTriggerReconnectFallback(
        result: buildResult(
          transcript: TranscriptRecoveryState.fallbackNeeded,
          metadata: MetadataRecoveryState.complete,
          sessionReady: false,
        ),
        hasSeenDisconnect: true,
        connState: ConnState.connected,
        hasSession: false,
      );

      expect(shouldFallback, isFalse);
    });
  });

  group('ChatViewModel cache repair contract', () {
    test('requires repair for stale cache rows', () {
      final entry = SessionChatCacheEntry(
        sessionId: 'session-1',
        machineId: 'machine-1',
        title: 'Cached',
        cacheState: SessionChatCacheState.stale,
        lastAppliedSeq: 8,
        chatStateJson: {
          'messages': [
            {
              'id': 'msg-1',
              'role': 'agent',
              'createdAt': DateTime(2026, 1, 1).toIso8601String(),
              'parts': [
                {'type': 'text', 'text': 'hello'},
              ],
            },
          ],
          'messageOrder': ['msg-1'],
          'toolsByCallId': const <String, dynamic>{},
          'approvalsById': const <String, dynamic>{},
          'planEntries': const <dynamic>[],
        },
        configSnapshotJson: SessionChatCacheEntry.emptyConfigSnapshotJson(),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(
        ChatViewModel.shouldRepairCachedSession(
          entry: entry,
          hasRenderableVisibleState: true,
          machineLastSeq: 8,
        ),
        isTrue,
      );
      expect(
        ChatViewModel.initialUiModeForCachedSession(
          entry: entry,
          canRepair: true,
          needsRepair: true,
        ),
        ChatUiMode.rebuildingReadonly,
      );
    });

    test('requires repair when machine cursor is ahead of ready cache', () {
      final entry = SessionChatCacheEntry(
        sessionId: 'session-1',
        machineId: 'machine-1',
        title: 'Cached',
        cacheState: SessionChatCacheState.ready,
        lastAppliedSeq: 5,
        chatStateJson: {
          'messages': [
            {
              'id': 'msg-1',
              'role': 'agent',
              'createdAt': DateTime(2026, 1, 1).toIso8601String(),
              'parts': [
                {'type': 'text', 'text': 'hello'},
              ],
            },
          ],
          'messageOrder': ['msg-1'],
          'toolsByCallId': const <String, dynamic>{},
          'approvalsById': const <String, dynamic>{},
          'planEntries': const <dynamic>[],
        },
        configSnapshotJson: SessionChatCacheEntry.emptyConfigSnapshotJson(),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(
        ChatViewModel.shouldRepairCachedSession(
          entry: entry,
          hasRenderableVisibleState: true,
          machineLastSeq: 7,
        ),
        isTrue,
      );
      expect(
        ChatViewModel.shouldRepairCachedSession(
          entry: entry.copyWith(lastAppliedSeq: 7),
          hasRenderableVisibleState: true,
          machineLastSeq: 7,
        ),
        isFalse,
      );
    });

    test(
      'replaces optimistic user message only for authoritative user deltas',
      () {
        expect(
          ChatViewModel.shouldReplaceOptimisticUserMessage(
            hasOptimisticUserMessage: true,
            part: MessagePartEvent(
              partId: 'user-part-1',
              messageId: 'user-1',
              role: MessageRole.user,
              delta: 'hello',
              partType: 'text',
            ),
          ),
          isTrue,
        );
        expect(
          ChatViewModel.shouldReplaceOptimisticUserMessage(
            hasOptimisticUserMessage: true,
            part: MessagePartEvent(
              partId: 'assistant-part-1',
              messageId: 'assistant-1',
              role: MessageRole.agent,
              delta: 'hello',
              partType: 'text',
            ),
          ),
          isFalse,
        );
        expect(
          ChatViewModel.shouldReplaceOptimisticUserMessage(
            hasOptimisticUserMessage: false,
            part: MessagePartEvent(
              partId: 'user-part-1',
              messageId: 'user-1',
              role: MessageRole.user,
              delta: 'hello',
              partType: 'text',
            ),
          ),
          isFalse,
        );
      },
    );

    test('adopting optimistic user message preserves timeline position', () {
      final chatState = ChatState(sessionId: 'session-1');
      chatState.finalizeMessage(
        Message(
          id: 'local-1',
          sessionId: 'session-1',
          role: MessageRole.user,
          parts: [MessagePart(type: PartType.text, text: 'hello')],
          createdAt: DateTime(2026, 1, 1, 0, 0),
        ),
      );
      chatState.finalizeMessage(
        Message(
          id: 'assistant-1',
          sessionId: 'session-1',
          role: MessageRole.agent,
          parts: [MessagePart(type: PartType.text, text: 'world')],
          createdAt: DateTime(2026, 1, 1, 0, 1),
        ),
      );

      expect(chatState.adoptLocalOptimisticUserMessage('user-1'), isTrue);
      chatState.applyDelta(
        MessagePartEvent(
          partId: 'user-part-1',
          messageId: 'user-1',
          role: MessageRole.user,
          delta: 'hello',
          partType: 'text',
        ),
      );

      expect(chatState.orderedMessages.map((message) => message.id).toList(), [
        'user-1',
        'assistant-1',
      ]);
      expect(chatState.messages['user-1']?.parts.single.text, 'hello');
      expect(chatState.messages.containsKey('local-1'), isFalse);
    });

    test('disables composer while transport is reconnecting', () {
      expect(
        ChatViewModel.shouldEnableComposer(
          uiMode: ChatUiMode.normal,
          connState: ConnState.reconnecting,
          isRecoveringAfterReconnect: false,
        ),
        isFalse,
      );
      expect(
        ChatViewModel.shouldEnableComposer(
          uiMode: ChatUiMode.normal,
          connState: ConnState.disconnected,
          isRecoveringAfterReconnect: false,
        ),
        isFalse,
      );
      expect(
        ChatViewModel.shouldEnableComposer(
          uiMode: ChatUiMode.normal,
          connState: ConnState.connected,
          isRecoveringAfterReconnect: false,
        ),
        isTrue,
      );
      expect(
        ChatViewModel.shouldEnableComposer(
          uiMode: ChatUiMode.rebuildingReadonly,
          connState: ConnState.connected,
          isRecoveringAfterReconnect: false,
        ),
        isFalse,
      );
    });
  });
}
