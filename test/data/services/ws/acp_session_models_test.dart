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
}
