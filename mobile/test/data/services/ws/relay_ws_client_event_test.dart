import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/event_envelope_parser.dart';
import 'package:muxagent/data/services/ws/models/ws_models.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/domain/enums.dart';

void main() {
  test('fills decrypted event payload machineId from encrypted envelope', () {
    final payload = enrichEventPayloadWithMachineId(
      _messageDeltaPayload(),
      'machine-outer',
    );

    final event = EventEnvelopeParser.parse(
      WsEvent(type: 'event', payload: payload),
    );

    expect(event, isNotNull);
    expect(event!.type, EventType.messageDelta);
    expect(event.machineId, 'machine-outer');
    expect(event.messagePart?.delta, 'hello');
  });

  test('keeps payload machineId when event payload already includes it', () {
    final payload = enrichEventPayloadWithMachineId({
      ..._messageDeltaPayload(),
      'machineId': 'machine-payload',
    }, 'machine-outer');

    expect(payload['machineId'], 'machine-payload');
  });
}

Map<String, dynamic> _messageDeltaPayload() {
  return {
    'type': 'message.delta',
    'sessionId': 'sid-1',
    'seq': 1,
    'messagePart': {
      'app': {
        'partId': 'part-1',
        'messageId': 'msg-1',
        'role': 'agent',
        'delta': 'hello',
        'partType': 'text',
      },
    },
  };
}
