import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/models/acp_session_models.dart';

void main() {
  test('parses app session.create response with exact ACP payload', () {
    final dto = AppSessionCreateResponseDto.fromJson({
      'app': {
        'sessionId': 'session-123',
        'runtime': 'codex',
        'cwd': '/workspace',
        'title': 'New chat',
        'status': 'idle',
        'updatedAt': '2026-04-27T00:00:00Z',
      },
      'acp': {
        'sessionId': 'session-123',
        'modes': {
          'currentModeId': 'auto',
          'availableModes': [
            {'id': 'read-only', 'name': 'Read Only'},
            {'id': 'auto', 'name': 'Default'},
          ],
        },
        'configOptions': [
          {
            'id': 'mode',
            'name': 'Approval Preset',
            'type': 'select',
            'currentValue': 'auto',
            'category': 'mode',
            'options': [
              {'value': 'read-only', 'name': 'Read Only'},
              {'value': 'auto', 'name': 'Default'},
            ],
          },
        ],
      },
    });

    expect(dto.app.sessionId, 'session-123');
    expect(dto.app.runtime, 'codex');
    expect(dto.app.cwd, '/workspace');
    expect(dto.app.title, 'New chat');
    expect(dto.app.status, 'idle');
    expect(dto.app.updatedAt, DateTime.parse('2026-04-27T00:00:00Z'));
    expect(dto.acp.sessionId, 'session-123');
    expect(dto.acp.modes?.currentModeId, 'auto');
    expect(dto.acp.configOptions, isNotNull);
    expect(dto.acp.configOptions!.single.options.flatten().length, 2);
  });

  test('parses app session.load response with exact ACP payload', () {
    final dto = AppSessionLoadResponseDto.fromJson({
      'app': {
        'ok': true,
        'sessionId': 'session-123',
        'runtime': 'codex',
        'cwd': '/workspace',
        'title': 'Existing chat',
        'status': 'running',
        'updatedAt': '2026-04-27T00:00:01Z',
        'replay': {
          'complete': true,
          'events': [
            {'type': 'message.delta', 'sessionId': 'session-123', 'seq': 0},
          ],
        },
      },
      'acp': {
        'configOptions': [
          {
            'id': 'model',
            'name': 'Model',
            'type': 'select',
            'currentValue': 'gpt-5.4',
            'category': 'model',
            'options': [
              {'value': 'gpt-5.4', 'name': 'gpt-5.4'},
            ],
          },
        ],
      },
    });

    expect(dto.app.ok, isTrue);
    expect(dto.app.sessionId, 'session-123');
    expect(dto.app.runtime, 'codex');
    expect(dto.app.cwd, '/workspace');
    expect(dto.app.title, 'Existing chat');
    expect(dto.app.status, 'running');
    expect(dto.app.updatedAt, DateTime.parse('2026-04-27T00:00:01Z'));
    expect(dto.app.replay.complete, isTrue);
    expect(dto.app.replay.events, hasLength(1));
    expect(dto.acp.configOptions, isNotNull);
    expect(dto.acp.configOptions!.single.id, 'model');
    expect(dto.acp.configOptions!.single.currentValue, 'gpt-5.4');
  });

  test('rejects missing session.load replay', () {
    expect(
      () => AppSessionLoadResponseDto.fromJson({
        'app': {
          'ok': true,
          'sessionId': 'session-123',
          'runtime': 'codex',
          'cwd': '/workspace',
        },
        'acp': {},
      }),
      throwsFormatException,
    );
  });

  test('rejects mismatched create session ids', () {
    expect(
      () => AppSessionCreateResponseDto.fromJson({
        'app': {
          'sessionId': 'app-session',
          'runtime': 'codex',
          'cwd': '/workspace',
        },
        'acp': {'sessionId': 'acp-session'},
      }),
      throwsFormatException,
    );
  });

  test('parses exact ACP plan update payload', () {
    final dto = AcpPlanUpdateDto.fromJson({
      'sessionUpdate': 'plan',
      '_meta': {'source': 'codex'},
      'entries': [
        {
          'content': 'Inspect event payloads',
          'priority': 'high',
          'status': 'completed',
        },
        {
          'content': 'Refactor usage updates',
          'priority': 'medium',
          'status': 'in_progress',
        },
      ],
    });

    expect(dto.sessionUpdate, 'plan');
    expect(dto.entries, hasLength(2));
    expect(dto.entries.first.content, 'Inspect event payloads');
    expect(dto.entries.last.status, 'in_progress');
  });

  test('parses exact ACP usage update payload', () {
    final dto = AcpUsageUpdateDto.fromJson({
      'sessionUpdate': 'usage_update',
      'used': 53000,
      'size': 200000,
      'cost': {'amount': 0.045, 'currency': 'USD'},
    });

    expect(dto.sessionUpdate, 'usage_update');
    expect(dto.used, 53000);
    expect(dto.size, 200000);
    expect(dto.cost, isNotNull);
    expect(dto.cost!.amount, 0.045);
    expect(dto.cost!.currency, 'USD');
  });
}
