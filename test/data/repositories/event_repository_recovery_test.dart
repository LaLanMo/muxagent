import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/local/session_database.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
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
import 'package:muxagent/domain/event.dart';
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
  List<ResolvedSessionSnapshot> nextResolvedSessions = const [];
  ResyncBatch nextResyncBatch = const ResyncBatch(
    events: [],
    status: ReplayResyncStatus.reset,
    streamEpoch: 77,
    replayedThroughSeq: 0,
  );
  int? lastResyncStreamEpoch;
  int? lastResyncSeq;
  Completer<void>? resyncBlocker;

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
    final blocker = resyncBlocker;
    if (blocker != null) {
      await blocker.future;
    }
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
    return nextResolvedSessions;
  }
}

class _FakeSessionChatCacheRepository extends SessionChatCacheRepository {
  final staleMarked = <String>[];

  @override
  Future<bool> markSessionCacheStale(String sessionId) async {
    staleMarked.add(sessionId);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('EventRepository reconnect helpers', () {
    late _FakeWsSessionRepository wsRepo;
    late _FakeSessionChatCacheRepository chatCacheRepo;
    late EventRepository repo;
    late String sessionId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      wsRepo = _FakeWsSessionRepository();
      chatCacheRepo = _FakeSessionChatCacheRepository();
      repo = EventRepository(
        wsRepo: wsRepo,
        chatCacheRepo: chatCacheRepo,
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

    test('live events bootstrap cursor and mark chat cache stale', () async {
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
      expect(chatCacheRepo.staleMarked, [sessionId]);

      repo.dispose();

      repo = EventRepository(
        wsRepo: wsRepo,
        chatCacheRepo: chatCacheRepo,
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

    test('resync fence buffers live events and drops replay overlap', () async {
      final seenSeqs = <int>[];
      final sub = repo.events.listen((event) {
        if (event.sessionId == sessionId) {
          seenSeqs.add(event.seq);
        }
      });

      wsRepo.nextResyncBatch = ResyncBatch(
        events: [
          AgentEvent(
            type: EventType.messageDelta,
            sessionId: sessionId,
            machineId: 'machine-1',
            seq: 8,
            at: DateTime.now(),
            messagePart: MessagePartEvent(
              partId: 'replay-part',
              messageId: 'msg-1',
              role: MessageRole.agent,
              partType: 'text',
              fullText: 'replay',
            ),
          ),
        ],
        status: ReplayResyncStatus.ok,
        streamEpoch: 77,
        replayedThroughSeq: 8,
      );
      wsRepo.resyncBlocker = Completer<void>();

      final resyncFuture = repo.resync('machine-1');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      wsRepo.emitEvent(
        WsEvent(
          type: WsMessageType.event.value,
          payload: {
            'type': 'message.delta',
            'machineId': 'machine-1',
            'sessionId': sessionId,
            'seq': 8,
            'messagePart': {
              'app': {
                'partId': 'dup-part',
                'messageId': 'msg-1',
                'role': 'agent',
                'delta': 'replay',
                'partType': 'text',
                'fullText': 'replay',
              },
            },
          },
        ),
      );
      wsRepo.emitEvent(
        WsEvent(
          type: WsMessageType.event.value,
          payload: {
            'type': 'message.delta',
            'machineId': 'machine-1',
            'sessionId': sessionId,
            'seq': 9,
            'messagePart': {
              'app': {
                'partId': 'live-part',
                'messageId': 'msg-2',
                'role': 'agent',
                'delta': 'live',
                'partType': 'text',
                'fullText': 'live',
              },
            },
          },
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(seenSeqs, isEmpty);
      expect(repo.lastSeqFor('machine-1'), 0);

      wsRepo.resyncBlocker!.complete();
      final result = await resyncFuture;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(result.outcome, ResyncOutcome.complete);
      expect(seenSeqs, [8, 9]);
      expect(repo.lastSeqFor('machine-1'), 9);

      await sub.cancel();
    });

    test(
      'backfillMissingTitles does not overwrite an existing repair cwd',
      () async {
        wsRepo.nextResolvedSessions = [
          ResolvedSessionSnapshot(
            sessionId: sessionId,
            title: 'Resolved title',
            cwd: '/repo/root',
            status: SessionStatus.idle,
            updatedAt: DateTime.now(),
          ),
        ];

        final result = await repo.backfillMissingTitles(
          'machine-1',
          sessionIds: [sessionId],
          runtime: 'codex',
        );

        expect(result.ok, isTrue);
        expect(repo.sessionById(sessionId)?.cwd, '/tmp');
        expect(repo.sessionById(sessionId)?.title, 'Resolved title');
      },
    );

    test(
      'backfillMissingTitles skips inserting runtime-less resolved sessions',
      () async {
        wsRepo.nextResolvedSessions = [
          ResolvedSessionSnapshot(
            sessionId: 'resolved-only',
            title: 'Resolved title',
            cwd: '/repo/root',
            status: SessionStatus.idle,
            updatedAt: DateTime.now(),
          ),
        ];

        final result = await repo.backfillMissingTitles(
          'machine-1',
          sessionIds: ['resolved-only'],
        );

        expect(result.ok, isTrue);
        expect(repo.sessionById('resolved-only'), isNull);
      },
    );

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
