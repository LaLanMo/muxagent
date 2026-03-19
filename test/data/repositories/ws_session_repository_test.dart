import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/models/rpc_transport_models.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/prompt_content_block.dart';

class FakeRelayWsClient extends RelayWsClient {
  Map<String, dynamic> nextPayload;
  String? lastMachineId;
  String? lastMethod;
  Map<String, dynamic>? lastParams;

  FakeRelayWsClient({required this.nextPayload})
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
    lastMachineId = machineId;
    lastMethod = method;
    lastParams = params == null ? null : Map<String, dynamic>.from(params);
    return RpcResponseEnvelopeDto.fromJson(nextPayload);
  }
}

void main() {
  group('WsSessionRepository typed RPC helpers', () {
    test('listRuntimes sends runtime.list and parses DTO', () async {
      final relay = FakeRelayWsClient(
        nextPayload: {
          'result': {
            'runtimes': [
              {'id': 'codex', 'label': 'Codex', 'ready': true},
            ],
          },
        },
      );
      final repo = WsSessionRepository(
        relay: relay,
        sessions: SessionManager(),
      );

      final response = await repo.listRuntimes(machineId: 'machine-1');

      expect(relay.lastMachineId, 'machine-1');
      expect(relay.lastMethod, 'runtime.list');
      expect(relay.lastParams, isNull);
      expect(response.runtimes, hasLength(1));
      expect(response.runtimes.first.id, 'codex');
    });

    test('createSession owns method name and params', () async {
      final relay = FakeRelayWsClient(
        nextPayload: {
          'result': {
            'app': {'runtime': 'codex', 'cwd': '/workspace'},
            'acp': {'sessionId': 'sid-1'},
          },
        },
      );
      final repo = WsSessionRepository(
        relay: relay,
        sessions: SessionManager(),
      );

      final response = await repo.createSession(
        machineId: 'machine-1',
        cwd: '/workspace',
        runtime: 'codex',
        useWorktree: true,
        permissionMode: 'read-only',
      );

      expect(relay.lastMethod, 'session.create');
      expect(relay.lastParams, {
        'cwd': '/workspace',
        'runtime': 'codex',
        'useWorktree': true,
        'permissionMode': 'read-only',
      });
      expect(response.acp.sessionId, 'sid-1');
      expect(response.app.cwd, '/workspace');
    });

    test('loadSession omits empty/default optional params', () async {
      final relay = FakeRelayWsClient(
        nextPayload: {
          'result': {
            'app': {'ok': true, 'runtime': 'claude-code'},
            'acp': {},
          },
        },
      );
      final repo = WsSessionRepository(
        relay: relay,
        sessions: SessionManager(),
      );

      final response = await repo.loadSession(
        machineId: 'machine-1',
        sessionId: 'sid-1',
        cwd: '/workspace',
        runtime: 'claude-code',
        permissionMode: '',
        model: 'default',
      );

      expect(relay.lastMethod, 'session.load');
      expect(relay.lastParams, {
        'sessionId': 'sid-1',
        'cwd': '/workspace',
        'runtime': 'claude-code',
      });
      expect(response.app.runtime, 'claude-code');
    });

    test('file helpers map fs.list and fs.search results', () async {
      final relay = FakeRelayWsClient(
        nextPayload: {
          'result': {
            'entries': [
              {'path': '/workspace/lib', 'isDir': true},
            ],
          },
        },
      );
      final repo = WsSessionRepository(
        relay: relay,
        sessions: SessionManager(),
      );

      final listed = await repo.listFiles(
        machineId: 'machine-1',
        sessionId: 'sid-1',
        path: '',
      );

      expect(relay.lastMethod, 'fs.list');
      expect(relay.lastParams, {'sessionId': 'sid-1', 'path': ''});
      expect(listed.single.name, 'lib');

      relay.nextPayload = {
        'result': {
          'results': [
            {'path': '/workspace/AGENTS.md', 'isDir': false},
          ],
        },
      };

      final searched = await repo.searchFiles(
        machineId: 'machine-1',
        sessionId: 'sid-1',
        query: 'AG',
      );

      expect(relay.lastMethod, 'fs.search');
      expect(relay.lastParams, {'sessionId': 'sid-1', 'query': 'AG'});
      expect(searched.single.name, 'AGENTS.md');
    });

    test('event maintenance helpers own rpc methods and mapping', () async {
      final relay = FakeRelayWsClient(
        nextPayload: {
          'result': {
            'events': [
              {
                'type': 'message.delta',
                'sessionId': 'sid-1',
                'seq': 9,
                'messagePart': {
                  'app': {
                    'partId': 'part-1',
                    'messageId': 'msg-1',
                    'role': 'agent',
                    'delta': 'hi',
                    'partType': 'text',
                    'fullText': 'hi',
                  },
                },
              },
            ],
            'status': 'ok',
            'streamEpoch': 42,
            'replayedThroughSeq': 9,
          },
        },
      );
      final repo = WsSessionRepository(
        relay: relay,
        sessions: SessionManager(),
      );

      final resync = await repo.resyncEvents(
        machineId: 'machine-1',
        lastSeq: 8,
        streamEpoch: 42,
      );

      expect(relay.lastMethod, 'events.resync');
      expect(relay.lastParams, {'lastSeq': 8, 'streamEpoch': 42});
      expect(resync.status, ReplayResyncStatus.ok);
      expect(resync.streamEpoch, 42);
      expect(resync.replayedThroughSeq, 9);
      expect(resync.events, hasLength(1));
      expect(resync.events.single.type, EventType.messageDelta);
      expect(resync.events.single.seq, 9);
      expect(resync.events.single.sessionId, 'sid-1');

      relay.nextPayload = {
        'result': {
          'sessions': [
            {
              'sessionId': 'sid-1',
              'title': 'Hello',
              'cwd': '/workspace',
              'status': 'waiting_approval',
            },
          ],
        },
      };

      final sessions = await repo.resolveSessions(
        machineId: 'machine-1',
        sessionIds: ['sid-1'],
        runtime: 'codex',
      );

      expect(relay.lastMethod, 'session.resolve');
      expect(relay.lastParams, {
        'sessionIds': ['sid-1'],
        'runtime': 'codex',
      });
      expect(sessions.single.title, 'Hello');
      expect(sessions.single.status.value, 'waiting_approval');

      relay.nextPayload = {
        'result': {
          'approvals': [
            {
              'app': {
                'requestId': 'req-1',
                'createdAt': '2026-03-14T02:00:00.000Z',
                'runtime': 'codex',
                'toolCallId': 'call-1',
                'toolKind': 'execute',
                'title': 'Run touch hello.txt',
                'bodyText': 'Create hello.txt',
              },
              'acp': {
                'sessionId': 'sid-1',
                'toolCall': {
                  'toolCallId': 'call-1',
                  'title': 'Run touch hello.txt',
                  'kind': 'execute',
                  'status': 'pending',
                  'rawInput': {
                    'command': ['touch', 'hello.txt'],
                  },
                },
                'options': [
                  {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
                ],
              },
            },
          ],
        },
      };

      final approvals = await repo.listPendingApprovals(machineId: 'machine-1');

      expect(relay.lastMethod, 'approvals.pending');
      expect(relay.lastParams, isEmpty);
      expect(approvals.single.id, 'req-1');
      expect(approvals.single.sessionId, 'sid-1');

      relay.nextPayload = {
        'result': {'approvals': null},
      };

      final emptyApprovals = await repo.listPendingApprovals(
        machineId: 'machine-1',
      );

      expect(emptyApprovals, isEmpty);
    });

    test('action helpers own rpc methods and ack semantics', () async {
      final relay = FakeRelayWsClient(
        nextPayload: {
          'result': {'ok': true},
        },
      );
      final repo = WsSessionRepository(
        relay: relay,
        sessions: SessionManager(),
      );

      await repo.setMode(
        machineId: 'machine-1',
        sessionId: 'sid-1',
        permissionMode: 'read-only',
      );
      expect(relay.lastMethod, 'session.setMode');
      expect(relay.lastParams, {
        'sessionId': 'sid-1',
        'permissionMode': 'read-only',
      });

      await repo.setConfigOption(
        machineId: 'machine-1',
        sessionId: 'sid-1',
        configId: 'model',
        value: 'claude-sonnet',
      );
      expect(relay.lastMethod, 'session.setConfigOption');
      expect(relay.lastParams, {
        'sessionId': 'sid-1',
        'configId': 'model',
        'value': 'claude-sonnet',
      });

      relay.nextPayload = {
        'result': {'accepted': true},
      };
      await repo.promptSession(
        machineId: 'machine-1',
        sessionId: 'sid-1',
        content: [PromptContentBlock.text('hello')],
      );
      expect(relay.lastMethod, 'session.prompt');
      expect(relay.lastParams, {
        'sessionId': 'sid-1',
        'content': [
          {'type': 'text', 'text': 'hello'},
        ],
      });

      relay.nextPayload = {
        'result': {'ok': true},
      };
      await repo.replyApproval(
        machineId: 'machine-1',
        sessionId: 'sid-1',
        requestId: 'req-1',
        optionId: 'allow',
      );
      expect(relay.lastMethod, 'approval.reply');
      expect(relay.lastParams, {
        'sessionId': 'sid-1',
        'requestId': 'req-1',
        'optionId': 'allow',
      });

      await repo.cancelSession(machineId: 'machine-1', sessionId: 'sid-1');
      expect(relay.lastMethod, 'session.cancel');
      expect(relay.lastParams, {'sessionId': 'sid-1'});
    });
  });
}
