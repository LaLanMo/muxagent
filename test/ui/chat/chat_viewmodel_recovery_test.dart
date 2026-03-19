import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/domain/enums.dart';
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
}
