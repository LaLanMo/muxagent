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
      input: json['input'] == null
          ? null
          : ToolInputDto.fromJson(json['input'] as Map<String, dynamic>),
      output: json['output'] as String?,
      error: json['error'] as String?,
      diffs:
          (json['diffs'] as List<dynamic>?)
              ?.map((e) => ToolDiffDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ToolDiffDto>[],
      claudeCode: json['claudeCode'] == null
          ? null
          : ClaudeCodeToolDto.fromJson(
              json['claudeCode'] as Map<String, dynamic>,
            ),
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
      'input': instance.input?.toJson(),
      'output': instance.output,
      'error': instance.error,
      'diffs': instance.diffs.map((e) => e.toJson()).toList(),
      'claudeCode': instance.claudeCode?.toJson(),
      'locations': instance.locations.map((e) => e.toJson()).toList(),
    };

_$ToolInputDtoImpl _$$ToolInputDtoImplFromJson(Map<String, dynamic> json) =>
    _$ToolInputDtoImpl(
      description: json['description'] as String?,
      command: json['command'] == null
          ? null
          : ToolCommandDto.fromJson(json['command'] as Map<String, dynamic>),
      filePath: json['filePath'] as String?,
      sourcePath: json['sourcePath'] as String?,
      targetPath: json['targetPath'] as String?,
      pattern: json['pattern'] as String?,
      url: json['url'] as String?,
      mode: json['mode'] as String?,
      edit: json['edit'] == null
          ? null
          : ToolEditInputDto.fromJson(json['edit'] as Map<String, dynamic>),
      rawInputJson: json['rawInputJson'] as String?,
    );

Map<String, dynamic> _$$ToolInputDtoImplToJson(_$ToolInputDtoImpl instance) =>
    <String, dynamic>{
      'description': instance.description,
      'command': instance.command?.toJson(),
      'filePath': instance.filePath,
      'sourcePath': instance.sourcePath,
      'targetPath': instance.targetPath,
      'pattern': instance.pattern,
      'url': instance.url,
      'mode': instance.mode,
      'edit': instance.edit?.toJson(),
      'rawInputJson': instance.rawInputJson,
    };

_$ToolCommandDtoImpl _$$ToolCommandDtoImplFromJson(Map<String, dynamic> json) =>
    _$ToolCommandDtoImpl(
      argv:
          (json['argv'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      display: json['display'] as String?,
    );

Map<String, dynamic> _$$ToolCommandDtoImplToJson(
  _$ToolCommandDtoImpl instance,
) => <String, dynamic>{'argv': instance.argv, 'display': instance.display};

_$ToolEditInputDtoImpl _$$ToolEditInputDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ToolEditInputDtoImpl(
  filePath: json['filePath'] as String?,
  oldString: json['oldString'] as String?,
  newString: json['newString'] as String?,
);

Map<String, dynamic> _$$ToolEditInputDtoImplToJson(
  _$ToolEditInputDtoImpl instance,
) => <String, dynamic>{
  'filePath': instance.filePath,
  'oldString': instance.oldString,
  'newString': instance.newString,
};

_$ClaudeCodeToolDtoImpl _$$ClaudeCodeToolDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ClaudeCodeToolDtoImpl(
  parentToolUseId: json['parentToolUseId'] as String?,
  toolName: json['toolName'] as String?,
);

Map<String, dynamic> _$$ClaudeCodeToolDtoImplToJson(
  _$ClaudeCodeToolDtoImpl instance,
) => <String, dynamic>{
  'parentToolUseId': instance.parentToolUseId,
  'toolName': instance.toolName,
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
