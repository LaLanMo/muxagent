import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/approval_event_mapper.dart';
import 'package:muxagent/data/services/ws/models/approval_event_models.dart';
import 'package:muxagent/domain/enums.dart';

void main() {
  test(
    'maps approval.requested payload from approval.acp and approval.app',
    () {
      final payload = <String, dynamic>{
        'type': 'approval.requested',
        'sessionId': 'sid-1',
        'seq': 7,
        'at': '2026-03-14T01:45:00.000Z',
        'approval': {
          'app': {
            'requestId': 'req-1',
            'createdAt': '2026-03-14T01:44:59.000Z',
            'runtime': 'codex',
            'toolCallId': 'call-1',
            'toolKind': 'execute',
            'title': 'Run touch /workspace/hello.txt',
            'bodyText': 'Create an empty file in the project root.',
            'cwd': '/workspace',
            'command': {
              'argv': ['touch', '/workspace/hello.txt'],
              'display': 'touch hello.txt',
            },
            'reason': 'Create an empty file in the project root.',
          },
          'acp': {
            'sessionId': 'sid-1',
            'toolCall': {
              'toolCallId': 'call-1',
              'title': 'Run touch /workspace/hello.txt',
              'kind': 'execute',
              'status': 'pending',
              'rawInput': {
                'command': ['touch', '/workspace/hello.txt'],
                'cwd': '/workspace',
              },
            },
            'options': [
              {'optionId': 'approved', 'name': 'Yes', 'kind': 'allow_once'},
              {
                'optionId': 'approved-for-session',
                'name': 'Always',
                'kind': 'allow_always',
              },
            ],
          },
        },
      };

      final event = ApprovalEventMapper.mapEnvelope(
        ApprovalEventEnvelopeDto.fromJson(payload),
        'machine-1',
      );
      final approval = event.approval;

      expect(event.type, EventType.approvalRequested);
      expect(event.sessionId, 'sid-1');
      expect(event.seq, 7);
      expect(approval, isNotNull);
      expect(approval!.id, 'req-1');
      expect(approval.runtime, 'codex');
      expect(approval.toolCallId, 'call-1');
      expect(approval.kind, 'execute');
      expect(approval.title, 'Run touch /workspace/hello.txt');
      expect(approval.commandText, 'touch hello.txt');
      expect(approval.cwd, '/workspace');
      expect(approval.reason, 'Create an empty file in the project root.');
      expect(approval.options, hasLength(2));
      expect(approval.options.first.kind, PermOptionKind.allowOnce);
    },
  );
}
