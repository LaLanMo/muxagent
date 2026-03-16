import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/tool_event_mapper.dart';
import 'package:muxagent/domain/enums.dart';

void main() {
  test('maps tool.updated payload from tool.acp and tool.app', () {
    final event = ToolEventMapper.parseEvent({
      'type': 'tool.updated',
      'sessionId': 'session-123',
      'seq': 12,
      'at': '2026-03-14T02:20:16.000Z',
      'tool': {
        'app': {
          'partId': 'part-1',
          'messageId': 'message-1',
          'callId': 'toolu_123',
          'name': 'touch /workspace/claude-approval.txt',
          'kind': 'execute',
          'title': 'touch /workspace/claude-approval.txt',
          'status': 'in_progress',
          'input': {
            'command': {'display': 'touch /workspace/claude-approval.txt'},
            'description': 'Create empty file claude-approval.txt',
            'rawInputJson':
                '{"command":"touch /workspace/claude-approval.txt","description":"Create empty file claude-approval.txt"}',
          },
          'claudeCode': {'toolName': 'Bash'},
          'locations': [
            {'path': '/workspace/claude-approval.txt', 'line': 1},
          ],
        },
        'acp': {
          '_meta': {
            'claudeCode': {'toolName': 'Bash'},
          },
          'toolCallId': 'toolu_123',
          'title': 'touch /workspace/claude-approval.txt',
          'kind': 'execute',
          'content': [
            {
              'type': 'content',
              'content': {
                'type': 'text',
                'text': 'Create empty file claude-approval.txt',
              },
            },
          ],
          'rawInput': {
            'command': 'touch /workspace/claude-approval.txt',
            'description': 'Create empty file claude-approval.txt',
          },
        },
      },
    }, 'machine-1');

    expect(event.type, EventType.toolUpdated);
    expect(event.sessionId, 'session-123');
    expect(event.seq, 12);
    expect(event.tool, isNotNull);
    expect(event.tool!.callId, 'toolu_123');
    expect(event.tool!.name, 'touch /workspace/claude-approval.txt');
    expect(event.tool!.kind, 'execute');
    expect(event.tool!.status, ToolStatus.inProgress);
    expect(
      event.tool!.input?.description,
      'Create empty file claude-approval.txt',
    );
    expect(
      event.tool!.input?.command?.display,
      'touch /workspace/claude-approval.txt',
    );
    expect(event.tool!.claudeCode?.toolName, 'Bash');
    expect(event.tool!.locations, hasLength(1));
    expect(
      event.tool!.locations!.single.path,
      '/workspace/claude-approval.txt',
    );
  });

  test('falls back to ACP metadata when app metadata is absent', () {
    final event = ToolEventMapper.parseEvent({
      'type': 'tool.completed',
      'sessionId': 'session-123',
      'tool': {
        'app': {
          'partId': 'part-2',
          'messageId': 'message-2',
          'callId': 'toolu_456',
          'name': '',
          'title': 'Terminal',
          'status': 'completed',
          'output': '',
          'input': {
            'description': 'Create empty file',
            'command': {'display': 'touch /workspace/output.txt'},
            'rawInputJson': '{"command":"touch /workspace/output.txt"}',
          },
        },
        'acp': {
          '_meta': {
            'claudeCode': {'toolName': 'Bash'},
          },
          'toolCallId': 'toolu_456',
          'title': 'Terminal',
          'kind': 'execute',
          'status': 'completed',
          'rawOutput': '',
        },
      },
    }, 'machine-1');

    expect(event.type, EventType.toolCompleted);
    expect(event.tool, isNotNull);
    expect(event.tool!.name, 'Terminal');
    expect(event.tool!.kind, 'execute');
    expect(event.tool!.claudeCode?.toolName, 'Bash');
    expect(event.tool!.input?.command?.display, 'touch /workspace/output.txt');
    expect(event.tool!.output, isNull);
  });
}
