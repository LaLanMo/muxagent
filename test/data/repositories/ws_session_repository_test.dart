import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';

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
  Future<Map<String, dynamic>> callRpc({
    required String machineId,
    required String method,
    Map<String, dynamic>? params,
  }) async {
    lastMachineId = machineId;
    lastMethod = method;
    lastParams = params == null ? null : Map<String, dynamic>.from(params);
    return nextPayload;
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
  });
}
