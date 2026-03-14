import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/usage_event_mapper.dart';
import 'package:muxagent/domain/enums.dart';

void main() {
  test('maps usage.update payload from usage.acp and usage.app', () {
    final event = UsageEventMapper.parseEvent({
      'type': 'usage.update',
      'sessionId': 'session-123',
      'seq': 8,
      'at': '2026-03-14T03:35:00.000Z',
      'usage': {
        'app': {
          'contextUsed': 53000,
          'contextSize': 200000,
          'costAmount': 0.045,
          'costCurrency': 'USD',
        },
        'acp': {
          'sessionUpdate': 'usage_update',
          'used': 53000,
          'size': 200000,
          'cost': {'amount': 0.045, 'currency': 'USD'},
        },
      },
    }, 'machine-1');

    expect(event.type, EventType.usageUpdate);
    expect(event.sessionId, 'session-123');
    expect(event.seq, 8);
    expect(event.usageUpdate, isNotNull);
    expect(event.usageUpdate!.contextUsed, 53000);
    expect(event.usageUpdate!.contextSize, 200000);
    expect(event.usageUpdate!.costAmount, 0.045);
    expect(event.usageUpdate!.costCurrency, 'USD');
  });
}
