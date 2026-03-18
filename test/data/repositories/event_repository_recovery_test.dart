import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/local/session_database.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/rpc_result_mapper.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/approval.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _NoopRelayWsClient extends RelayWsClient {
  _NoopRelayWsClient()
    : super(
        crypto: CryptoService(),
        tokens: TokenService(crypto: CryptoService()),
        sessions: SessionManager(),
      );
}

class _FakeWsSessionRepository extends WsSessionRepository {
  List<ApprovalRequest> nextApprovals = const [];

  _FakeWsSessionRepository()
    : super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  Future<List<ApprovalRequest>> listPendingApprovals({
    required String machineId,
  }) async {
    return nextApprovals;
  }

  @override
  Future<List<ResolvedSessionSnapshot>> resolveSessions({
    required String machineId,
    required Iterable<String> sessionIds,
    String? runtime,
  }) async {
    return const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('EventRepository reconnect helpers', () {
    late _FakeWsSessionRepository wsRepo;
    late EventRepository repo;
    late String sessionId;

    setUp(() async {
      wsRepo = _FakeWsSessionRepository();
      repo = EventRepository(wsRepo: wsRepo);
      sessionId = 'recover-session-${DateTime.now().microsecondsSinceEpoch}';
      final now = DateTime.now();
      await repo.registerSession(
        AgentSession(
          id: sessionId,
          machineId: 'machine-1',
          runtime: 'codex',
          cwd: '/tmp',
          status: SessionStatus.waitingApproval,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      repo.dispose();
      await SessionDatabase.deleteSession(sessionId);
    });

    test('resync reports noCursor when no event sequence exists', () async {
      final result = await repo.resync('machine-1');

      expect(result.outcome, ResyncOutcome.noCursor);
      expect(result.lastSeqUsed, 0);
    });

    test(
      'fetchPendingApprovals removes stale approvals for the machine',
      () async {
        repo.pendingApprovals['req-1'] = ApprovalRequest(
          id: 'req-1',
          sessionId: sessionId,
          title: 'stale',
          options: const [],
          createdAt: DateTime.now(),
        );

        await repo.fetchPendingApprovals('machine-1');

        expect(repo.pendingApprovals, isEmpty);
      },
    );
  });
}
