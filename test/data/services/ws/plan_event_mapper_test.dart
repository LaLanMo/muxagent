import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/plan_event_mapper.dart';
import 'package:muxagent/data/services/ws/models/plan_event_models.dart';
import 'package:muxagent/domain/enums.dart';

void main() {
  test('maps plan.updated payload from plan.acp and plan.app', () {
    final event = PlanEventMapper.mapEnvelope(
      PlanEventEnvelopeDto.fromJson({
        'type': 'plan.updated',
        'sessionId': 'session-123',
        'seq': 4,
        'at': '2026-03-14T03:30:00.000Z',
        'plan': {
          'app': {
            'entries': [
              {
                'content': 'Inspect event payloads',
                'status': 'completed',
                'priority': 'high',
              },
              {
                'content': 'Refactor usage update mapping',
                'status': 'in_progress',
                'priority': 'medium',
              },
            ],
          },
          'acp': {
            'sessionUpdate': 'plan',
            '_meta': {'source': 'codex'},
            'entries': [
              {
                'content': 'Inspect event payloads',
                'status': 'completed',
                'priority': 'high',
              },
              {
                'content': 'Refactor usage update mapping',
                'status': 'in_progress',
                'priority': 'medium',
              },
            ],
          },
        },
      }),
      'machine-1',
    );

    expect(event.type, EventType.planUpdated);
    expect(event.sessionId, 'session-123');
    expect(event.seq, 4);
    expect(event.planUpdate, isNotNull);
    expect(event.planUpdate!.entries, hasLength(2));
    expect(event.planUpdate!.entries.first.content, 'Inspect event payloads');
    expect(event.planUpdate!.entries.last.status, 'in_progress');
  });
}
