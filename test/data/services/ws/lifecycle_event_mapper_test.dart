import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/lifecycle_event_mapper.dart';
import 'package:muxagent/domain/enums.dart';

void main() {
  test('maps session.status payload from sessionStatus.app', () {
    final event = LifecycleEventMapper.parseSessionStatus({
      'type': 'session.status',
      'sessionId': 'session-123',
      'seq': 21,
      'at': '2026-03-14T04:20:00.000Z',
      'sessionStatus': {
        'app': {
          'id': 'session-123',
          'title': 'Example Session',
          'status': 'done',
          'model': 'opus',
          'createdAt': '2026-03-14T04:10:00.000Z',
          'updatedAt': '2026-03-14T04:20:00.000Z',
          'metadata': {'cwd': '/tmp/project'},
        },
      },
    }, 'machine-1');

    expect(event.type, EventType.sessionStatus);
    expect(event.sessionId, 'session-123');
    expect(event.session, isNotNull);
    expect(event.session!.id, 'session-123');
    expect(event.session!.title, 'Example Session');
    expect(event.session!.status, SessionStatus.done);
    expect(event.session!.model, 'opus');
    expect(event.session!.cwd, '/tmp/project');
  });

  test('maps run.failed payload from runFailed.app', () {
    final event = LifecycleEventMapper.parseRunFailed({
      'type': 'run.failed',
      'sessionId': 'session-123',
      'seq': 22,
      'at': '2026-03-14T04:21:00.000Z',
      'runFailed': {
        'app': {
          'error': {'code': 'prompt_error', 'message': 'runtime failed'},
        },
      },
    }, 'machine-1');

    expect(event.type, EventType.runFailed);
    expect(event.sessionId, 'session-123');
    expect(event.error, isNotNull);
    expect(event.error!.code, 'prompt_error');
    expect(event.error!.message, 'runtime failed');
  });
}
