import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/session_config_event_mapper.dart';
import 'package:muxagent/data/services/ws/models/session_config_event_models.dart';
import 'package:muxagent/domain/enums.dart';

void main() {
  test('maps mode.changed event from app and acp payloads', () {
    final event = SessionConfigEventMapper.mapModeChangedEnvelope(
      ModeChangedEventEnvelopeDto.fromJson({
        'type': 'mode.changed',
        'sessionId': 'session-123',
        'seq': 4,
        'at': '2026-03-14T00:00:00.000Z',
        'modeChanged': {
          'app': {'currentModeId': 'auto'},
          'acp': {'currentModeId': 'auto'},
        },
      }),
      'machine-1',
    );

    expect(event.type, EventType.modeChanged);
    expect(event.sessionId, 'session-123');
    expect(event.modeChange?.currentModeId, 'auto');
  });

  test('maps model.changed event from app and acp payloads', () {
    final event = SessionConfigEventMapper.mapConfigChangedEnvelope(
      ConfigChangedEventEnvelopeDto.fromJson({
        'type': 'model.changed',
        'sessionId': 'session-123',
        'seq': 9,
        'at': '2026-03-14T00:00:01.000Z',
        'configChanged': {
          'app': {
            'configId': 'model',
            'category': 'model',
            'currentValue': 'gpt-5.4',
            'values': [
              {
                'value': 'gpt-5.4',
                'name': 'gpt-5.4',
                'description': 'Latest frontier agentic coding model.',
              },
            ],
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
        },
      }),
      'machine-1',
    );

    expect(event.type, EventType.modelChanged);
    expect(event.configChange?.configId, 'model');
    expect(event.configChange?.currentValue, 'gpt-5.4');
    expect(event.configChange?.values.single.name, 'gpt-5.4');
  });

  test('maps mode.changed event when ACP source is config_option_update', () {
    final event = SessionConfigEventMapper.mapModeChangedEnvelope(
      ModeChangedEventEnvelopeDto.fromJson({
        'type': 'mode.changed',
        'sessionId': 'session-123',
        'seq': 10,
        'at': '2026-03-14T00:00:02.000Z',
        'modeChanged': {
          'app': {'currentModeId': 'read-only'},
          'acp': {
            'configOptions': [
              {
                'id': 'mode',
                'name': 'Approval Preset',
                'type': 'select',
                'currentValue': 'read-only',
                'category': 'mode',
                'options': [
                  {'value': 'read-only', 'name': 'Read Only'},
                  {'value': 'auto', 'name': 'Default'},
                ],
              },
            ],
          },
        },
      }),
      'machine-1',
    );

    expect(event.type, EventType.modeChanged);
    expect(event.modeChange?.currentModeId, 'read-only');
  });
}
