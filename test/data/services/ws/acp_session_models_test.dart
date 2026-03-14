import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/models/acp_session_models.dart';

void main() {
  test('parses app session.create response with exact ACP payload', () {
    final dto = AppSessionCreateResponseDto.fromJson({
      'app': {'runtime': 'codex', 'cwd': '/workspace'},
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

    expect(dto.app.runtime, 'codex');
    expect(dto.app.cwd, '/workspace');
    expect(dto.acp.sessionId, 'session-123');
    expect(dto.acp.modes?.currentModeId, 'auto');
    expect(dto.acp.configOptions, isNotNull);
    expect(dto.acp.configOptions!.single.options.flatten().length, 2);
  });

  test('parses app session.load response with exact ACP payload', () {
    final dto = AppSessionLoadResponseDto.fromJson({
      'app': {'ok': true, 'runtime': 'codex'},
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
    expect(dto.app.runtime, 'codex');
    expect(dto.acp.configOptions, isNotNull);
    expect(dto.acp.configOptions!.single.id, 'model');
    expect(dto.acp.configOptions!.single.currentValue, 'gpt-5.4');
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
