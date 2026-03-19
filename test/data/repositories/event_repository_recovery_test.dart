import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/local/session_database.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/rpc_result_mapper.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/data/services/ws/models/ws_models.dart';
import 'package:muxagent/data/services/ws/ws_types.dart';
import 'package:muxagent/domain/approval.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final _events = StreamController<WsEvent>.broadcast();
  List<ApprovalRequest> nextApprovals = const [];
  ResyncBatch nextResyncBatch = const ResyncBatch(
    events: [],
    status: ReplayResyncStatus.reset,
    streamEpoch: 77,
    replayedThroughSeq: 0,
  );
  int? lastResyncStreamEpoch;
  int? lastResyncSeq;

  _FakeWsSessionRepository()
    : super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  Stream<WsEvent> get events => _events.stream;

  void emitEvent(WsEvent event) => _events.add(event);

  Future<void> disposeEvents() => _events.close();

  @override
  Future<ResyncBatch> resyncEvents({
    required String machineId,
    required int lastSeq,
    int? streamEpoch,
  }) async {
    lastResyncSeq = lastSeq;
    lastResyncStreamEpoch = streamEpoch;
    return nextResyncBatch;
  }

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
      SharedPreferences.setMockInitialValues({});
      wsRepo = _FakeWsSessionRepository();
      repo = EventRepository(
        wsRepo: wsRepo,
        replayCursorPersistDebounce: Duration.zero,
      );
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
      await wsRepo.disposeEvents();
      await SessionDatabase.deleteSession(sessionId);
    });

    test('resync reports noCursor when no event sequence exists', () async {
      final result = await repo.resync('machine-1');

      expect(result.outcome, ResyncOutcome.noCursor);
      expect(result.lastSeqUsed, 0);
      expect(result.streamEpoch, 77);
      expect(wsRepo.lastResyncSeq, 0);
      expect(wsRepo.lastResyncStreamEpoch, isNull);
    });

    test('live events bootstrap and persist replay cursor', () async {
      wsRepo.emitEvent(
        WsEvent(
          type: WsMessageType.event.value,
          payload: {
            'type': 'message.delta',
            'machineId': 'machine-1',
            'sessionId': sessionId,
            'seq': 6,
            'messagePart': {
              'app': {
                'partId': 'part-1',
                'messageId': 'msg-1',
                'role': 'agent',
                'delta': 'hello',
                'partType': 'text',
                'fullText': 'hello',
              },
            },
          },
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repo.lastSeqFor('machine-1'), 6);

      repo.dispose();

      repo = EventRepository(
        wsRepo: wsRepo,
        replayCursorPersistDebounce: Duration.zero,
      );
      await repo.init();
      wsRepo.nextResyncBatch = const ResyncBatch(
        events: [],
        status: ReplayResyncStatus.ok,
        streamEpoch: 77,
        replayedThroughSeq: 6,
      );

      final result = await repo.resync('machine-1');

      expect(result.outcome, ResyncOutcome.complete);
      expect(wsRepo.lastResyncSeq, 6);
      expect(wsRepo.lastResyncStreamEpoch, 77);
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
