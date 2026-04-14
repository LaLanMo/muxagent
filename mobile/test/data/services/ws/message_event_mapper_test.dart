import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/message_event_mapper.dart';
import 'package:muxagent/data/services/ws/models/message_event_models.dart';
import 'package:muxagent/domain/enums.dart';

void main() {
  test('parses exact ACP content chunk payload', () {
    final dto = AcpContentChunkDto.fromJson({
      'sessionUpdate': 'agent_message_chunk',
      'messageId': 'msg-1',
      'content': {'type': 'text', 'text': 'hello'},
    });

    expect(dto.sessionUpdate, 'agent_message_chunk');
    expect(dto.messageId, 'msg-1');
    expect(dto.content.type, 'text');
    expect(dto.content.text, 'hello');
  });

  test(
    'maps message.delta payload from messagePart.acp and messagePart.app',
    () {
      final event = MessageEventMapper.mapEnvelope(
        MessageEventEnvelopeDto.fromJson({
          'type': 'message.delta',
          'sessionId': 'session-123',
          'seq': 8,
          'at': '2026-03-14T03:05:00.000Z',
          'messagePart': {
            'app': {
              'partId': 'part-1',
              'messageId': 'message-1',
              'role': 'agent',
              'delta': 'MUX',
              'partType': 'text',
            },
            'acp': {
              'sessionUpdate': 'agent_message_chunk',
              'messageId': 'message-1',
              'content': {'type': 'text', 'text': 'MUX'},
            },
          },
        }),
        'machine-1',
      );

      expect(event.type, EventType.messageDelta);
      expect(event.sessionId, 'session-123');
      expect(event.seq, 8);
      expect(event.messagePart, isNotNull);
      expect(event.messagePart!.messageId, 'message-1');
      expect(event.messagePart!.partId, 'part-1');
      expect(event.messagePart!.role, MessageRole.agent);
      expect(event.messagePart!.delta, 'MUX');
      expect(event.messagePart!.partType, 'text');
    },
  );

  test('maps reasoning payload from messagePart.acp and messagePart.app', () {
    final event = MessageEventMapper.mapEnvelope(
      MessageEventEnvelopeDto.fromJson({
        'type': 'reasoning',
        'sessionId': 'session-123',
        'messagePart': {
          'app': {
            'partId': 'part-2',
            'messageId': 'message-1',
            'role': 'agent',
            'delta': 'thinking...',
            'partType': 'reasoning',
          },
          'acp': {
            'sessionUpdate': 'agent_thought_chunk',
            'messageId': 'message-1',
            'content': {'type': 'text', 'text': 'thinking...'},
          },
        },
      }),
      'machine-1',
    );

    expect(event.type, EventType.reasoning);
    expect(event.messagePart, isNotNull);
    expect(event.messagePart!.role, MessageRole.agent);
    expect(event.messagePart!.partType, 'reasoning');
    expect(event.messagePart!.delta, 'thinking...');
  });
}
