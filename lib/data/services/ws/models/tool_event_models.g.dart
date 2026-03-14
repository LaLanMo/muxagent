// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_event_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ToolEventEnvelopeDtoImpl _$$ToolEventEnvelopeDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ToolEventEnvelopeDtoImpl(
  type: json['type'] as String,
  sessionId: json['sessionId'] as String?,
  seq: (json['seq'] as num?)?.toInt() ?? 0,
  at: json['at'] == null ? null : DateTime.parse(json['at'] as String),
  tool: ToolWireDto.fromJson(json['tool'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$ToolEventEnvelopeDtoImplToJson(
  _$ToolEventEnvelopeDtoImpl instance,
) => <String, dynamic>{
  'type': instance.type,
  'sessionId': instance.sessionId,
  'seq': instance.seq,
  'at': instance.at?.toIso8601String(),
  'tool': instance.tool.toJson(),
};

_$ToolWireDtoImpl _$$ToolWireDtoImplFromJson(Map<String, dynamic> json) =>
    _$ToolWireDtoImpl(
      app: ToolAppDto.fromJson(json['app'] as Map<String, dynamic>),
      acp: json['acp'] == null
          ? null
          : AcpToolCallUpdateDto.fromJson(json['acp'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$ToolWireDtoImplToJson(_$ToolWireDtoImpl instance) =>
    <String, dynamic>{
      'app': instance.app.toJson(),
      'acp': instance.acp?.toJson(),
    };

_$ToolAppDtoImpl _$$ToolAppDtoImplFromJson(Map<String, dynamic> json) =>
    _$ToolAppDtoImpl(
      partId: json['partId'] as String,
      messageId: json['messageId'] as String,
      callId: json['callId'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String?,
      title: json['title'] as String?,
      status: json['status'] as String,
      input: json['input'] as Map<String, dynamic>?,
      output: json['output'] as String?,
      error: json['error'] as String?,
      diffs:
          (json['diffs'] as List<dynamic>?)
              ?.map((e) => ToolDiffDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ToolDiffDto>[],
      metadata: json['metadata'] as Map<String, dynamic>?,
      locations:
          (json['locations'] as List<dynamic>?)
              ?.map((e) => ToolLocationDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ToolLocationDto>[],
    );

Map<String, dynamic> _$$ToolAppDtoImplToJson(_$ToolAppDtoImpl instance) =>
    <String, dynamic>{
      'partId': instance.partId,
      'messageId': instance.messageId,
      'callId': instance.callId,
      'name': instance.name,
      'kind': instance.kind,
      'title': instance.title,
      'status': instance.status,
      'input': instance.input,
      'output': instance.output,
      'error': instance.error,
      'diffs': instance.diffs.map((e) => e.toJson()).toList(),
      'metadata': instance.metadata,
      'locations': instance.locations.map((e) => e.toJson()).toList(),
    };

_$ToolDiffDtoImpl _$$ToolDiffDtoImplFromJson(Map<String, dynamic> json) =>
    _$ToolDiffDtoImpl(
      path: json['path'] as String,
      oldText: json['oldText'] as String?,
      newText: json['newText'] as String,
    );

Map<String, dynamic> _$$ToolDiffDtoImplToJson(_$ToolDiffDtoImpl instance) =>
    <String, dynamic>{
      'path': instance.path,
      'oldText': instance.oldText,
      'newText': instance.newText,
    };

_$ToolLocationDtoImpl _$$ToolLocationDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ToolLocationDtoImpl(
  path: json['path'] as String,
  line: (json['line'] as num?)?.toInt(),
);

Map<String, dynamic> _$$ToolLocationDtoImplToJson(
  _$ToolLocationDtoImpl instance,
) => <String, dynamic>{'path': instance.path, 'line': instance.line};
