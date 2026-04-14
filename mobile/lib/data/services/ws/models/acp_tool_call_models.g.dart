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
  if (instance.meta case final value?) '_meta': value,
  'toolCallId': instance.toolCallId,
  if (instance.title case final value?) 'title': value,
  if (instance.kind case final value?) 'kind': value,
  if (instance.status case final value?) 'status': value,
  if (instance.content case final value?) 'content': value,
  if (instance.locations?.map((e) => e.toJson()).toList() case final value?)
    'locations': value,
  if (instance.rawInput case final value?) 'rawInput': value,
  if (instance.rawOutput case final value?) 'rawOutput': value,
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
  if (instance.meta case final value?) '_meta': value,
  'path': instance.path,
  if (instance.line case final value?) 'line': value,
};
