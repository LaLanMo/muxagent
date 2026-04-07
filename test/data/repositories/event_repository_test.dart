import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/local/session_database.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/rpc_result_mapper.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/models/rpc_transport_models.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _NoActiveSessionWsSessionRepository extends WsSessionRepository {
  _NoActiveSessionWsSessionRepository()
    : super(relay: _FakeRelayWsClient(), sessions: SessionManager());

  var resolveSessionsCalled = false;

  @override
  bool hasSession(String machineId) => false;

  @override
  Future<List<ResolvedSessionSnapshot>> resolveSessions({
    required String machineId,
    required Iterable<String> sessionIds,
    String? runtime,
  }) async {
    resolveSessionsCalled = true;
    return const <ResolvedSessionSnapshot>[];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('eventAffectsTranscript', () {
    test('treats visible reasoning as transcript content', () {
      expect(eventAffectsTranscript(EventType.reasoning), isTrue);
      expect(eventAffectsTranscript(EventType.messageDelta), isTrue);
      expect(eventAffectsTranscript(EventType.modeChanged), isFalse);
    });
  });

  group('EventRepository acknowledged config persistence', () {
    late EventRepository repo;
    late String sessionId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
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
      expect(repo.transcriptWatermarkFor(sessionId), 0);

      final rows = await SessionDatabase.loadAll();
      final restored = rows.firstWhere((row) => row.id == sessionId);
      expect(restored.mode, 'plan');
    });

    test(
      'metadata acknowledgements do not advance transcript watermark',
      () async {
        repo.setSessionModel(sessionId, 'opus');
        repo.setSessionMode(sessionId, 'plan');
        await repo.persistSessionRuntimeAndCwd(
          sessionId,
          runtime: 'codex',
          cwd: '/workspace',
        );

        expect(repo.transcriptWatermarkFor(sessionId), 0);
      },
    );
  });

  group('EventRepository config refresh guard', () {
    late _NoActiveSessionWsSessionRepository wsRepo;
    late EventRepository repo;
    late String sessionId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      wsRepo = _NoActiveSessionWsSessionRepository();
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

    test(
      'skips session.resolve when the machine has no active session',
      () async {
        await repo.refreshSessionConfig(
          machineId: 'machine-1',
          sessionId: sessionId,
          runtime: 'claude-code',
        );

        expect(wsRepo.resolveSessionsCalled, isFalse);
      },
    );
  });
}
