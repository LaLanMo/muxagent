import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/event_envelope_parser.dart';
import 'package:muxagent/data/services/ws/models/ws_models.dart';
import 'package:muxagent/data/services/ws/ws_types.dart';
import 'package:muxagent/domain/enums.dart';

void main() {
  Map<String, dynamic> replayMessage({Object? seq = 0}) => {
    'type': 'message.delta',
    'sessionId': 'session-123',
    if (seq != null) 'seq': seq,
    'at': '2026-04-27T00:00:00Z',
    'messagePart': {
      'app': {
        'partId': 'part-1',
        'messageId': 'message-1',
        'role': 'agent',
        'delta': 'hello',
        'partType': 'text',
      },
    },
  };

  test('parses scoped replay transcript events with seq zero', () {
    final event = EventEnvelopeParser.parseScopedReplayEvent(
      replayMessage(),
      machineId: 'machine-1',
    );

    expect(event.type, EventType.messageDelta);
    expect(event.seq, 0);
    expect(event.machineId, 'machine-1');
    expect(event.messagePart?.delta, 'hello');
  });

  test('rejects scoped replay events with positive or missing seq', () {
    expect(
      () => EventEnvelopeParser.parseScopedReplayEvent(
        replayMessage(seq: 1),
        machineId: 'machine-1',
      ),
      throwsFormatException,
    );
    expect(
      () => EventEnvelopeParser.parseScopedReplayEvent(
        replayMessage(seq: 0.5),
        machineId: 'machine-1',
      ),
      throwsFormatException,
    );
    expect(
      () => EventEnvelopeParser.parseScopedReplayEvent(
        replayMessage(seq: null),
        machineId: 'machine-1',
      ),
      throwsFormatException,
    );
  });

  test('rejects non-transcript events in scoped replay', () {
    expect(
      () => EventEnvelopeParser.parseScopedReplayEvent({
        'type': 'usage.update',
        'sessionId': 'session-123',
        'seq': 0,
        'usage': {
          'app': {'contextUsed': 1, 'contextSize': 2},
        },
      }, machineId: 'machine-1'),
      throwsFormatException,
    );
    expect(
      () => EventEnvelopeParser.parseScopedReplayEvent({
        'type': 'session.status',
        'sessionId': 'session-123',
        'seq': 0,
      }, machineId: 'machine-1'),
      throwsFormatException,
    );
  });

  test('rejects committed stream events without positive seq', () {
    expect(
      () => EventEnvelopeParser.parseCommitted(
        WsEvent(type: WsMessageType.event.value, payload: replayMessage()),
      ),
      throwsFormatException,
    );
  });
}
