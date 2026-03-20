import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/services/ws/session_crypto.dart';

void main() {
  group('SessionManager', () {
    test('invalidateSession fails in-flight rpc and clears active session', () async {
      final manager = SessionManager();
      manager.activateSession(
        'machine-1',
        SessionCrypto(
          machineId: 'machine-1',
          key: SecretKey(List<int>.filled(32, 7)),
        ),
      );

      final completer = manager.registerPendingRpc('machine-1', 'msg-1');
      manager.invalidateSession('machine-1', StateError('machine offline'));

      await expectLater(
        completer.future,
        throwsA(isA<StateError>()),
      );
      expect(manager.hasSession('machine-1'), isFalse);
      expect(manager.activeSessionIds, isEmpty);
    });

    test('endSession fails in-flight rpc instead of leaving it hanging', () async {
      final manager = SessionManager();
      manager.activateSession(
        'machine-1',
        SessionCrypto(
          machineId: 'machine-1',
          key: SecretKey(List<int>.filled(32, 9)),
        ),
      );

      final completer = manager.registerPendingRpc('machine-1', 'msg-1');
      manager.endSession('machine-1');

      await expectLater(
        completer.future,
        throwsA(isA<StateError>()),
      );
      expect(manager.hasSession('machine-1'), isFalse);
      expect(manager.activeSessionIds, isEmpty);
    });
  });
}
