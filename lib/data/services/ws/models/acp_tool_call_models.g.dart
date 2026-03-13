// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'acp_tool_call_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AcpToolCallUpdateDtoImpl _$$AcpToolCallUpdateDtoImplFromJson(
  Map<String, dynamic> json,
) => _$AcpToolCallUpdateDtoImpl(
  meta: json['_meta'] as Map<String, dynamic>?,
  toolCallId: json['toolCallId'] as String,
  title: json['title'] as String?,
  kind: json['kind'] as String?,
  status: json['status'] as String?,
  content: (json['content'] as List<dynamic>?)
      ?.map((e) => e as Map<String, dynamic>)
      .toList(),
  locations: (json['locations'] as List<dynamic>?)
      ?.map((e) => AcpToolCallLocationDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  rawInput: json['rawInput'],
  rawOutput: json['rawOutput'],
);

Map<String, dynamic> _$$AcpToolCallUpdateDtoImplToJson(
  _$AcpToolCallUpdateDtoImpl instance,
) => <String, dynamic>{
  '_meta': instance.meta,
  'toolCallId': instance.toolCallId,
  'title': instance.title,
  'kind': instance.kind,
  'status': instance.status,
  'content': instance.content,
  'locations': instance.locations?.map((e) => e.toJson()).toList(),
  'rawInput': instance.rawInput,
  'rawOutput': instance.rawOutput,
};

_$AcpToolCallLocationDtoImpl _$$AcpToolCallLocationDtoImplFromJson(
  Map<String, dynamic> json,
) => _$AcpToolCallLocationDtoImpl(
  meta: json['_meta'] as Map<String, dynamic>?,
  path: json['path'] as String,
  line: (json['line'] as num?)?.toInt(),
);

Map<String, dynamic> _$$AcpToolCallLocationDtoImplToJson(
  _$AcpToolCallLocationDtoImpl instance,
) => <String, dynamic>{
  '_meta': instance.meta,
  'path': instance.path,
  'line': instance.line,
};
