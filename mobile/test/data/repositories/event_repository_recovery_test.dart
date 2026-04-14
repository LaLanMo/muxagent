import 'dart:async';
import 'dart:io';

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
import 'package:muxagent/domain/mode_option.dart';
import 'package:muxagent/domain/session.dart';
import 'package:muxagent/domain/session_config_snapshot.dart';
import 'package:path/path.dart' as p;
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
  ReplayHeadSnapshot nextReplayHead = const ReplayHeadSnapshot(
    streamEpoch: 77,
    replayedThroughSeq: 0,
  );
  List<ReplayPage> nextReplayPages = const [];
  ReplaySummary nextReplaySummary = const ReplaySummary(
    status: ReplayResyncStatus.reset,
    streamEpoch: 77,
    replayedThroughSeq: 0,
  );
  int replayHeadCalls = 0;
  int? lastResyncStreamEpoch;
  int? lastResyncSeq;
  Completer<void>? beforeReplaySummary;
  Object? replayError;
  Completer<void>? resolveBlocker;

  _FakeWsSessionRepository()
    : super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  Stream<WsEvent> get events => _events.stream;

  void emitEvent(WsEvent event) => _events.add(event);

  Future<void> disposeEvents() => _events.close();

  @override
  Future<ReplayHeadSnapshot> fetchReplayHead({
    required String machineId,
  }) async {
    replayHeadCalls++;
    return nextReplayHead;
  }

  @override
  Future<ReplaySummary> consumeResyncPages({
    required String machineId,
    required int lastSeq,
    int? streamEpoch,
    required ResyncPageConsumer onPage,
  }) async {
    lastResyncSeq = lastSeq;
    lastResyncStreamEpoch = streamEpoch;
    for (final page in nextReplayPages) {
      await onPage(page);
    }
    final blocker = beforeReplaySummary;
    if (blocker != null) {
      await blocker.future;
    }
    final error = replayError;
    if (error != null) {
      throw error;
    }
    return nextReplaySummary;
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
    final blocker = resolveBlocker;
    if (blocker != null) {
      await blocker.future;
    }
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

WsEvent _messageDeltaWsEvent({
  required String machineId,
  required String sessionId,
  required int seq,
  required String partId,
  required String messageId,
  required String text,
}) {
  return WsEvent(
    type: WsMessageType.event.value,
    payload: {
      'type': 'message.delta',
      'machineId': machineId,
      'sessionId': sessionId,
      'seq': seq,
      'messagePart': {
        'app': {
          'partId': partId,
          'messageId': messageId,
          'role': 'agent',
          'delta': text,
          'partType': 'text',
          'fullText': text,
        },
      },
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('EventRepository reconnect helpers', () {
    late Directory tempDir;
    late String dbPath;
    late _FakeWsSessionRepository wsRepo;
    late _FakeSessionChatCacheRepository chatCacheRepo;
    late EventRepository repo;
    late String sessionId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp(
        'muxagent-event-repo-recovery-test-',
      );
      dbPath = p.join(tempDir.path, SessionDatabase.databaseFileName);
      await SessionDatabase.resetForTest(databasePathOverride: dbPath);
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
      await SessionDatabase.resetForTest();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'resync without a cursor bootstraps replay head without requesting replay',
      () async {
        final result = await repo.resync('machine-1');

        expect(result.outcome, ResyncOutcome.noCursor);
        expect(result.lastSeqUsed, 0);
        expect(result.streamEpoch, 77);
        expect(wsRepo.replayHeadCalls, 1);
        expect(wsRepo.lastResyncSeq, isNull);
        expect(wsRepo.lastResyncStreamEpoch, isNull);
        expect(repo.lastSeqFor('machine-1'), 0);
      },
    );

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
      expect(repo.transcriptWatermarkFor(sessionId), 6);
      expect(chatCacheRepo.staleMarked, [sessionId]);
      expect(wsRepo.replayHeadCalls, 1);
      expect(wsRepo.lastResyncSeq, isNull);

      repo.dispose();

      repo = EventRepository(
        wsRepo: wsRepo,
        chatCacheRepo: chatCacheRepo,
        replayCursorPersistDebounce: Duration.zero,
      );
      await repo.init();
      wsRepo.nextReplaySummary = const ReplaySummary(
        status: ReplayResyncStatus.ok,
        streamEpoch: 77,
        replayedThroughSeq: 6,
      );

      final result = await repo.resync('machine-1');

      expect(result.outcome, ResyncOutcome.complete);
      expect(wsRepo.replayHeadCalls, 1);
      expect(wsRepo.lastResyncSeq, 6);
      expect(wsRepo.lastResyncStreamEpoch, 77);
    });

    test(
      'reasoning events advance transcript watermark and stale cache',
      () async {
        wsRepo.emitEvent(
          WsEvent(
            type: WsMessageType.event.value,
            payload: {
              'type': 'reasoning',
              'machineId': 'machine-1',
              'sessionId': sessionId,
              'seq': 7,
              'messagePart': {
                'app': {
                  'partId': 'reasoning-part-1',
                  'messageId': 'msg-1',
                  'role': 'agent',
                  'delta': 'thinking',
                  'partType': 'reasoning',
                  'fullText': 'thinking',
                },
              },
            },
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repo.transcriptWatermarkFor(sessionId), 7);
        expect(chatCacheRepo.staleMarked, [sessionId]);
      },
    );

    test('metadata-only events do not advance transcript watermark', () async {
      wsRepo.emitEvent(
        WsEvent(
          type: WsMessageType.event.value,
          payload: {
            'type': 'mode.changed',
            'machineId': 'machine-1',
            'sessionId': sessionId,
            'seq': 11,
            'modeChanged': {
              'app': {'currentModeId': 'plan'},
              'acp': {'currentModeId': 'plan'},
            },
          },
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repo.transcriptWatermarkFor(sessionId), 0);
      expect(chatCacheRepo.staleMarked, isEmpty);
    });

    test(
      'resync applies replay pages incrementally and drops live overlap on drain',
      () async {
        wsRepo.nextReplayHead = const ReplayHeadSnapshot(
          streamEpoch: 77,
          replayedThroughSeq: 7,
        );
        wsRepo.emitEvent(
          _messageDeltaWsEvent(
            machineId: 'machine-1',
            sessionId: sessionId,
            seq: 7,
            partId: 'seed-part',
            messageId: 'msg-0',
            text: 'seed',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(repo.lastSeqFor('machine-1'), 7);

        final seenSeqs = <int>[];
        final sub = repo.events.listen((event) {
          if (event.sessionId == sessionId) {
            seenSeqs.add(event.seq);
          }
        });

        wsRepo.nextReplayPages = [
          ReplayPage(
            streamEpoch: 77,
            events: [
              _messageDeltaWsEvent(
                machineId: 'machine-1',
                sessionId: sessionId,
                seq: 8,
                partId: 'replay-part',
                messageId: 'msg-1',
                text: 'replay',
              ),
            ],
          ),
        ];
        wsRepo.nextReplaySummary = const ReplaySummary(
          status: ReplayResyncStatus.ok,
          streamEpoch: 77,
          replayedThroughSeq: 8,
        );
        wsRepo.beforeReplaySummary = Completer<void>();

        final resyncFuture = repo.resync('machine-1');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(seenSeqs, [8]);
        expect(repo.lastSeqFor('machine-1'), 8);

        wsRepo.emitEvent(
          _messageDeltaWsEvent(
            machineId: 'machine-1',
            sessionId: sessionId,
            seq: 8,
            partId: 'dup-part',
            messageId: 'msg-1',
            text: 'replay',
          ),
        );
        wsRepo.emitEvent(
          _messageDeltaWsEvent(
            machineId: 'machine-1',
            sessionId: sessionId,
            seq: 9,
            partId: 'live-part',
            messageId: 'msg-2',
            text: 'live',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(seenSeqs, [8]);
        expect(repo.lastSeqFor('machine-1'), 8);

        wsRepo.beforeReplaySummary!.complete();
        final result = await resyncFuture;
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(result.outcome, ResyncOutcome.complete);
        expect(seenSeqs, [8, 9]);
        expect(repo.lastSeqFor('machine-1'), 9);

        await sub.cancel();
      },
    );

    test(
      'resync failure after applied pages preserves partial replay progress',
      () async {
        wsRepo.nextReplayHead = const ReplayHeadSnapshot(
          streamEpoch: 77,
          replayedThroughSeq: 7,
        );
        wsRepo.emitEvent(
          _messageDeltaWsEvent(
            machineId: 'machine-1',
            sessionId: sessionId,
            seq: 7,
            partId: 'seed-part',
            messageId: 'msg-0',
            text: 'seed',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(repo.lastSeqFor('machine-1'), 7);

        final seenSeqs = <int>[];
        final sub = repo.events.listen((event) {
          if (event.sessionId == sessionId) {
            seenSeqs.add(event.seq);
          }
        });

        wsRepo.nextReplayPages = [
          ReplayPage(
            streamEpoch: 77,
            events: [
              _messageDeltaWsEvent(
                machineId: 'machine-1',
                sessionId: sessionId,
                seq: 8,
                partId: 'replay-part',
                messageId: 'msg-1',
                text: 'replay',
              ),
            ],
          ),
        ];
        wsRepo.beforeReplaySummary = Completer<void>();
        wsRepo.replayError = StateError('boom');

        final resyncFuture = repo.resync('machine-1');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(seenSeqs, [8]);
        expect(repo.lastSeqFor('machine-1'), 8);

        wsRepo.emitEvent(
          _messageDeltaWsEvent(
            machineId: 'machine-1',
            sessionId: sessionId,
            seq: 8,
            partId: 'dup-part',
            messageId: 'msg-1',
            text: 'replay',
          ),
        );
        wsRepo.emitEvent(
          _messageDeltaWsEvent(
            machineId: 'machine-1',
            sessionId: sessionId,
            seq: 9,
            partId: 'live-part',
            messageId: 'msg-2',
            text: 'live',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(seenSeqs, [8]);

        wsRepo.beforeReplaySummary!.complete();
        final result = await resyncFuture;
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(result.outcome, ResyncOutcome.failed);
        expect(result.highestSeqApplied, 8);
        expect(repo.lastSeqFor('machine-1'), 9);
        expect(seenSeqs, [8, 9]);

        await sub.cancel();
      },
    );

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

    test(
      'refreshSessionConfig applies session-scoped config from resolve',
      () async {
        wsRepo.nextResolvedSessions = [
          ResolvedSessionSnapshot(
            sessionId: sessionId,
            title: 'Resolved title',
            cwd: '/tmp',
            runtime: 'codex',
            status: SessionStatus.idle,
            updatedAt: DateTime.now(),
            configSnapshot: const SessionConfigSnapshot(
              modeConfigId: 'mode',
              currentMode: ModeOption(id: 'read-only', label: 'Read Only'),
              availableModes: [
                ModeOption(id: 'full-access', label: 'Full Access'),
                ModeOption(id: 'read-only', label: 'Read Only'),
              ],
            ),
          ),
        ];

        await repo.refreshSessionConfig(
          machineId: 'machine-1',
          sessionId: sessionId,
          runtime: 'codex',
        );

        final session = repo.sessionById(sessionId);
        expect(session?.configSnapshot.modeConfigId, 'mode');
        expect(session?.configSnapshot.currentMode?.id, 'read-only');
        expect(
          session?.configSnapshot.availableModes
              .map((mode) => mode.id)
              .toList(),
          ['full-access', 'read-only'],
        );
        expect(session?.runtime, 'codex');
        expect(session?.cwd, '/tmp');
      },
    );

    test(
      'refreshSessionConfig persists runtime and cwd even without config snapshot',
      () async {
        final runtimeOnlySessionId =
            'runtime-only-${DateTime.now().microsecondsSinceEpoch}';
        final now = DateTime.now();
        await repo.registerSession(
          AgentSession(
            id: runtimeOnlySessionId,
            machineId: 'machine-1',
            createdAt: now,
            updatedAt: now,
          ),
        );

        wsRepo.nextResolvedSessions = [
          ResolvedSessionSnapshot(
            sessionId: runtimeOnlySessionId,
            title: 'Resolved title',
            cwd: '/tmp/runtime-only',
            runtime: 'codex',
            status: SessionStatus.idle,
            updatedAt: now,
            configSnapshot: null,
          ),
        ];

        await repo.refreshSessionConfig(
          machineId: 'machine-1',
          sessionId: runtimeOnlySessionId,
        );

        final session = repo.sessionById(runtimeOnlySessionId);
        expect(session?.runtime, 'codex');
        expect(session?.cwd, '/tmp/runtime-only');

        await SessionDatabase.deleteSession(runtimeOnlySessionId);
      },
    );

    test(
      'refreshSessionConfig does not overwrite a newer live mode update',
      () async {
        wsRepo.nextResolvedSessions = [
          ResolvedSessionSnapshot(
            sessionId: sessionId,
            title: 'Resolved title',
            cwd: '/tmp',
            runtime: 'codex',
            status: SessionStatus.idle,
            updatedAt: DateTime.now(),
            configSnapshot: const SessionConfigSnapshot(
              modeConfigId: 'mode',
              currentMode: ModeOption(id: 'read-only', label: 'Read Only'),
              availableModes: [
                ModeOption(id: 'full-access', label: 'Full Access'),
                ModeOption(id: 'read-only', label: 'Read Only'),
              ],
            ),
          ),
        ];
        wsRepo.resolveBlocker = Completer<void>();

        final refreshFuture = repo.refreshSessionConfig(
          machineId: 'machine-1',
          sessionId: sessionId,
          runtime: 'codex',
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        wsRepo.emitEvent(
          WsEvent(
            type: WsMessageType.event.value,
            payload: {
              'type': 'mode.changed',
              'machineId': 'machine-1',
              'sessionId': sessionId,
              'seq': 12,
              'modeChanged': {
                'app': {'currentModeId': 'full-access'},
                'acp': {
                  'configOptions': [
                    {
                      'id': 'mode',
                      'name': 'Approval Preset',
                      'type': 'select',
                      'category': 'mode',
                      'currentValue': 'full-access',
                      'options': [
                        {'value': 'full-access', 'name': 'Full Access'},
                        {'value': 'read-only', 'name': 'Read Only'},
                      ],
                    },
                  ],
                },
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        wsRepo.resolveBlocker!.complete();
        await refreshFuture;

        final session = repo.sessionById(sessionId);
        expect(session?.configSnapshot.currentMode?.id, 'full-access');
        expect(
          session?.configSnapshot.availableModes
              .map((mode) => mode.id)
              .toList(),
          ['full-access', 'read-only'],
        );
      },
    );

    test(
      'refreshSessionConfig still persists runtime and cwd after a revision race',
      () async {
        final racingSessionId =
            'revision-race-${DateTime.now().microsecondsSinceEpoch}';
        final now = DateTime.now();
        await repo.registerSession(
          AgentSession(
            id: racingSessionId,
            machineId: 'machine-1',
            createdAt: now,
            updatedAt: now,
          ),
        );

        wsRepo.nextResolvedSessions = [
          ResolvedSessionSnapshot(
            sessionId: racingSessionId,
            title: 'Resolved title',
            cwd: '/tmp/revision-race',
            runtime: 'codex',
            status: SessionStatus.idle,
            updatedAt: now,
            configSnapshot: const SessionConfigSnapshot(
              modeConfigId: 'mode',
              currentMode: ModeOption(id: 'read-only', label: 'Read Only'),
              availableModes: [
                ModeOption(id: 'full-access', label: 'Full Access'),
                ModeOption(id: 'read-only', label: 'Read Only'),
              ],
            ),
          ),
        ];
        wsRepo.resolveBlocker = Completer<void>();

        final refreshFuture = repo.refreshSessionConfig(
          machineId: 'machine-1',
          sessionId: racingSessionId,
          runtime: 'codex',
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        wsRepo.emitEvent(
          WsEvent(
            type: WsMessageType.event.value,
            payload: {
              'type': 'mode.changed',
              'machineId': 'machine-1',
              'sessionId': racingSessionId,
              'seq': 34,
              'modeChanged': {
                'app': {'currentModeId': 'full-access'},
                'acp': {
                  'configOptions': [
                    {
                      'id': 'mode',
                      'name': 'Approval Preset',
                      'type': 'select',
                      'category': 'mode',
                      'currentValue': 'full-access',
                      'options': [
                        {'value': 'full-access', 'name': 'Full Access'},
                        {'value': 'read-only', 'name': 'Read Only'},
                      ],
                    },
                  ],
                },
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        wsRepo.resolveBlocker!.complete();
        await refreshFuture;

        final session = repo.sessionById(racingSessionId);
        expect(session?.runtime, 'codex');
        expect(session?.cwd, '/tmp/revision-race');
        expect(session?.configSnapshot.currentMode?.id, 'full-access');
        expect(
          session?.configSnapshot.availableModes
              .map((mode) => mode.id)
              .toList(),
          ['full-access', 'read-only'],
        );

        await SessionDatabase.deleteSession(racingSessionId);
      },
    );

    test(
      'applySessionConfigSnapshotIfUnchanged skips stale full snapshots after revision changes',
      () async {
        final baselineRevision = repo.sessionConfigRevisionFor(sessionId);

        wsRepo.emitEvent(
          WsEvent(
            type: WsMessageType.event.value,
            payload: {
              'type': 'mode.changed',
              'machineId': 'machine-1',
              'sessionId': sessionId,
              'seq': 21,
              'modeChanged': {
                'app': {'currentModeId': 'full-access'},
                'acp': {
                  'configOptions': [
                    {
                      'id': 'mode',
                      'name': 'Approval Preset',
                      'type': 'select',
                      'category': 'mode',
                      'currentValue': 'full-access',
                      'options': [
                        {'value': 'full-access', 'name': 'Full Access'},
                        {'value': 'read-only', 'name': 'Read Only'},
                      ],
                    },
                  ],
                },
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final applied = await repo.applySessionConfigSnapshotIfUnchanged(
          sessionId,
          baselineRevision: baselineRevision,
          snapshot: const SessionConfigSnapshot(
            modeConfigId: 'mode',
            currentMode: ModeOption(id: 'read-only', label: 'Read Only'),
            availableModes: [
              ModeOption(id: 'full-access', label: 'Full Access'),
              ModeOption(id: 'read-only', label: 'Read Only'),
            ],
          ),
        );

        expect(applied, isFalse);
        final session = repo.sessionById(sessionId);
        expect(session?.configSnapshot.currentMode?.id, 'full-access');
      },
    );
  });
}
