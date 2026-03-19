import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/models/rpc_result_models.dart';
import 'package:muxagent/data/services/ws/rpc_result_mapper.dart';

void main() {
  test('parses and maps session.resolve results', () {
    final dto = RpcSessionResolveResponseDto.fromJson({
      'sessions': [
        {
          'sessionId': 'sid-1',
          'title': 'Create file',
          'cwd': '/workspace',
          'status': 'waiting_approval',
          'updatedAt': '2026-03-14T02:00:00.000Z',
        },
      ],
    });

    final resolved = RpcResultMapper.toResolvedSessions(dto.sessions);

    expect(resolved, hasLength(1));
    expect(resolved.first.sessionId, 'sid-1');
    expect(resolved.first.title, 'Create file');
    expect(resolved.first.cwd, '/workspace');
    expect(resolved.first.status.value, 'waiting_approval');
    expect(
      resolved.first.updatedAt,
      DateTime.parse('2026-03-14T02:00:00.000Z'),
    );
  });

  test('parses and maps approvals.pending results', () {
    final dto = RpcPendingApprovalsResponseDto.fromJson({
      'approvals': [
        {
          'app': {
            'requestId': 'req-1',
            'createdAt': '2026-03-14T02:00:00.000Z',
            'runtime': 'claude-code',
            'toolCallId': 'call-1',
            'toolKind': 'edit',
            'title': 'Write hello.txt',
            'bodyText': 'Create hello.txt',
          },
          'acp': {
            'sessionId': 'sid-1',
            'toolCall': {
              'toolCallId': 'call-1',
              'title': 'Write hello.txt',
              'kind': 'edit',
              'status': 'pending',
              'rawInput': {'file_path': '/workspace/hello.txt', 'content': ''},
            },
            'options': [
              {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
            ],
          },
        },
      ],
    });

    final approvals = RpcResultMapper.toPendingApprovals(dto.approvals);

    expect(approvals, hasLength(1));
    expect(approvals.first.id, 'req-1');
    expect(approvals.first.sessionId, 'sid-1');
    expect(approvals.first.kind, 'edit');
    expect(approvals.first.options, hasLength(1));
  });

  test('parses approvals.pending null approvals as empty list', () {
    final dto = RpcPendingApprovalsResponseDto.fromJson({'approvals': null});

    final approvals = RpcResultMapper.toPendingApprovals(dto.approvals);

    expect(approvals, isEmpty);
  });

  test('parses and maps fs.list results', () {
    final dto = RpcFsListResponseDto.fromJson({
      'entries': [
        {'path': '/workspace/lib', 'isDir': true},
        {'path': '/workspace/README.md', 'isDir': false, 'name': 'README.md'},
      ],
    });

    final entries = RpcResultMapper.toFsEntries(dto.entries);

    expect(entries, hasLength(2));
    expect(entries.first.name, 'lib');
    expect(entries.first.isDir, isTrue);
    expect(entries.last.name, 'README.md');
    expect(entries.last.path, '/workspace/README.md');
  });

  test('parses events.resync envelope', () {
    final dto = RpcResyncResponseDto.fromJson({
      'events': [
        {'type': 'message.delta', 'sessionId': 'sid-1', 'seq': 9},
      ],
      'status': 'ok',
      'streamEpoch': 99,
      'replayedThroughSeq': 9,
    });

    expect(dto.status, RpcResyncStatusDto.ok);
    expect(dto.streamEpoch, 99);
    expect(dto.replayedThroughSeq, 9);
    expect(dto.events, hasLength(1));
    expect(dto.events.first['type'], 'message.delta');
  });

  test('rejects events.resync envelopes missing required replay fields', () {
    expect(
      () => RpcResyncResponseDto.fromJson({
        'events': const [],
        'replayedThroughSeq': 12,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => RpcResyncResponseDto.fromJson({
        'events': const [],
        'status': 'ok',
        'replayedThroughSeq': 12,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects missing required list fields', () {
    expect(
      () => RpcFsListResponseDto.fromJson({}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => RpcPendingApprovalsResponseDto.fromJson({}),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Expected approvals field',
        ),
      ),
    );
  });

  test('rejects invalid timestamp strings', () {
    expect(
      () => RpcSessionResolveResponseDto.fromJson({
        'sessions': [
          {'sessionId': 'sid-1', 'updatedAt': 'not-a-date'},
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
