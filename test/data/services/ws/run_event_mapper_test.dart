import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/run_event_mapper.dart';
import 'package:muxagent/data/services/ws/models/run_event_models.dart';
import 'package:muxagent/domain/enums.dart';

void main() {
  test('maps run.finished payload from runFinished.app', () {
    final event = RunEventMapper.mapRunFinishedEnvelope(
      RunFinishedEventEnvelopeDto.fromJson({
        'type': 'run.finished',
        'sessionId': 'session-123',
        'seq': 18,
        'at': '2026-03-14T04:10:00.000Z',
        'runFinished': {
          'app': {
            'stopReason': 'end_turn',
            'inputTokens': 1200,
            'outputTokens': 350,
            'cachedReadTokens': 800,
            'cachedWriteTokens': 100,
            'totalTokens': 2450,
          },
        },
      }),
      'machine-1',
    );

    expect(event.type, EventType.runFinished);
    expect(event.sessionId, 'session-123');
    expect(event.seq, 18);
    expect(event.runFinished, isNotNull);
    expect(event.runFinished!.stopReason, 'end_turn');
    expect(event.runFinished!.inputTokens, 1200);
    expect(event.runFinished!.outputTokens, 350);
    expect(event.runFinished!.cachedReadTokens, 800);
    expect(event.runFinished!.cachedWriteTokens, 100);
    expect(event.runFinished!.totalTokens, 2450);
  });
}
