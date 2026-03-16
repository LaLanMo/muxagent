import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/ws/models/acp_session_models.dart';
import 'package:muxagent/data/services/ws/models/approval_event_models.dart';
import 'package:muxagent/data/services/ws/models/message_event_models.dart';

Map<String, dynamic> _json(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(value);

void _expectRoundTrip<T>({
  required Map<String, dynamic> fixture,
  required T Function(Map<String, dynamic>) decode,
  required Map<String, dynamic> Function(T) encode,
}) {
  final decoded = decode(_json(fixture));
  expect(encode(decoded), equals(fixture));
}

void main() {
  test('round-trips exact ACP request_permission payload', () {
    final fixture = <String, dynamic>{
      '_meta': {'source': 'schema-fixture'},
      'sessionId': 'session-123',
      'toolCall': {
        '_meta': {'runtime': 'codex'},
        'toolCallId': 'call-123',
        'title': 'Run touch /workspace/hello.txt',
        'kind': 'execute',
        'status': 'pending',
        'content': [
          {'type': 'output_text', 'text': 'touch /workspace/hello.txt'},
        ],
        'locations': [
          {
            '_meta': {'source': 'tool'},
            'path': '/workspace/hello.txt',
            'line': 12,
          },
        ],
        'rawInput': {
          'command': ['touch', '/workspace/hello.txt'],
          'cwd': '/workspace',
        },
        'rawOutput': {'stdout': '', 'stderr': '', 'success': true},
      },
      'options': [
        {
          '_meta': {'source': 'runtime'},
          'optionId': 'allow',
          'name': 'Allow',
          'kind': 'allow_once',
        },
        {'optionId': 'deny', 'name': 'Deny', 'kind': 'reject_once'},
      ],
    };

    _expectRoundTrip(
      fixture: fixture,
      decode: AcpRequestPermissionRequestDto.fromJson,
      encode: (dto) => dto.toJson(),
    );
  });

  test('round-trips exact ACP content chunk payload', () {
    final fixture = <String, dynamic>{
      '_meta': {'source': 'schema-fixture'},
      'sessionUpdate': 'agent_message_chunk',
      'messageId': 'msg-123',
      'content': {
        '_meta': {'part': 'text'},
        'type': 'text',
        'text': 'hello world',
      },
    };

    _expectRoundTrip(
      fixture: fixture,
      decode: AcpContentChunkDto.fromJson,
      encode: (dto) => dto.toJson(),
    );
  });

  test('round-trips exact ACP session update payloads', () {
    final currentModeFixture = <String, dynamic>{
      '_meta': {'source': 'schema-fixture'},
      'currentModeId': 'auto',
    };
    _expectRoundTrip(
      fixture: currentModeFixture,
      decode: AcpCurrentModeUpdateDto.fromJson,
      encode: (dto) => dto.toJson(),
    );

    final configOptionFixture = <String, dynamic>{
      '_meta': {'source': 'schema-fixture'},
      'configOptions': [
        {
          '_meta': {'source': 'schema-fixture'},
          'id': 'model',
          'name': 'Model',
          'description': 'Choose a model',
          'category': 'model',
          'type': 'select',
          'currentValue': 'gpt-5.4',
          'options': [
            {
              'group': 'Frontier',
              'name': 'Frontier Models',
              'options': [
                {
                  'value': 'gpt-5.4',
                  'name': 'gpt-5.4',
                  'description': 'Latest frontier agentic coding model.',
                },
              ],
            },
          ],
        },
      ],
    };
    _expectRoundTrip(
      fixture: configOptionFixture,
      decode: AcpConfigOptionUpdateDto.fromJson,
      encode: (dto) => dto.toJson(),
    );

    final planFixture = <String, dynamic>{
      '_meta': {'source': 'schema-fixture'},
      'sessionUpdate': 'plan',
      'entries': [
        {
          '_meta': {'source': 'schema-fixture'},
          'content': 'Inspect event payloads',
          'priority': 'high',
          'status': 'completed',
        },
        {
          'content': 'Refactor transport contract',
          'priority': 'medium',
          'status': 'in_progress',
        },
      ],
    };
    _expectRoundTrip(
      fixture: planFixture,
      decode: AcpPlanUpdateDto.fromJson,
      encode: (dto) => dto.toJson(),
    );

    final usageFixture = <String, dynamic>{
      '_meta': {'source': 'schema-fixture'},
      'sessionUpdate': 'usage_update',
      'used': 53000,
      'size': 200000,
      'cost': {'amount': 0.045, 'currency': 'USD'},
    };
    _expectRoundTrip(
      fixture: usageFixture,
      decode: AcpUsageUpdateDto.fromJson,
      encode: (dto) => dto.toJson(),
    );
  });

  test('round-trips exact ACP session response payloads', () {
    final newSessionFixture = <String, dynamic>{
      '_meta': {'source': 'schema-fixture'},
      'sessionId': 'session-123',
      'modes': {
        '_meta': {'source': 'schema-fixture'},
        'currentModeId': 'auto',
        'availableModes': [
          {
            'id': 'read-only',
            'name': 'Read Only',
            'description': 'Read files only',
          },
          {'id': 'auto', 'name': 'Default'},
        ],
      },
      'configOptions': [
        {
          'id': 'mode',
          'name': 'Approval Preset',
          'type': 'select',
          'currentValue': 'auto',
          'category': 'mode',
          'options': [
            {'value': 'read-only', 'name': 'Read Only'},
            {'value': 'auto', 'name': 'Default'},
          ],
        },
      ],
    };
    _expectRoundTrip(
      fixture: newSessionFixture,
      decode: AcpNewSessionResponseDto.fromJson,
      encode: (dto) => dto.toJson(),
    );

    final loadSessionFixture = <String, dynamic>{
      '_meta': {'source': 'schema-fixture'},
      'modes': {
        'currentModeId': 'read-only',
        'availableModes': [
          {'id': 'read-only', 'name': 'Read Only'},
        ],
      },
      'configOptions': [
        {
          'id': 'model',
          'name': 'Model',
          'type': 'select',
          'currentValue': 'gpt-5.4',
          'category': 'model',
          'options': [
            {'value': 'gpt-5.4', 'name': 'gpt-5.4'},
          ],
        },
      ],
    };
    _expectRoundTrip(
      fixture: loadSessionFixture,
      decode: AcpLoadSessionResponseDto.fromJson,
      encode: (dto) => dto.toJson(),
    );
  });
}
