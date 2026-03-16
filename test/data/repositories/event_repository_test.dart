import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/local/session_database.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/models/rpc_transport_models.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeRelayWsClient extends RelayWsClient {
  _FakeRelayWsClient()
    : super(
        crypto: CryptoService(),
        tokens: TokenService(crypto: CryptoService()),
        sessions: SessionManager(),
      );

  @override
  Future<RpcResponseEnvelopeDto> callRpc({
    required String machineId,
    required String method,
    Map<String, dynamic>? params,
  }) async {
    return const RpcResponseEnvelopeDto(result: {'ok': true});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('EventRepository acknowledged config persistence', () {
    late EventRepository repo;
    late String sessionId;

    setUp(() async {
      final wsRepo = WsSessionRepository(
        relay: _FakeRelayWsClient(),
        sessions: SessionManager(),
      );
      repo = EventRepository(wsRepo: wsRepo);
      sessionId = 'test-session-${DateTime.now().microsecondsSinceEpoch}';
      final now = DateTime.now();
      await repo.registerSession(
        AgentSession(
          id: sessionId,
          machineId: 'machine-1',
          runtime: 'claude-code',
          cwd: '/tmp',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      repo.dispose();
      await SessionDatabase.deleteSession(sessionId);
    });

    test('setSessionModel persists model to memory and sqlite', () async {
      repo.setSessionModel(sessionId, 'opus');

      expect(repo.sessionById(sessionId)?.model, 'opus');

      final rows = await SessionDatabase.loadAll();
      final restored = rows.firstWhere((row) => row.id == sessionId);
      expect(restored.model, 'opus');
    });

    test('setSessionMode persists mode to memory and sqlite', () async {
      repo.setSessionMode(sessionId, 'plan');

      expect(repo.sessionById(sessionId)?.mode, 'plan');

      final rows = await SessionDatabase.loadAll();
      final restored = rows.firstWhere((row) => row.id == sessionId);
      expect(restored.mode, 'plan');
    });
  });
}
