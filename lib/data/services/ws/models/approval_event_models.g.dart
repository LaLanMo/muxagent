// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'approval_event_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ApprovalEventEnvelopeDtoImpl _$$ApprovalEventEnvelopeDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ApprovalEventEnvelopeDtoImpl(
  type: json['type'] as String,
  sessionId: json['sessionId'] as String?,
  seq: (json['seq'] as num?)?.toInt() ?? 0,
  at: json['at'] == null ? null : DateTime.parse(json['at'] as String),
  approval: ApprovalWireDto.fromJson(json['approval'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$ApprovalEventEnvelopeDtoImplToJson(
  _$ApprovalEventEnvelopeDtoImpl instance,
) => <String, dynamic>{
  'type': instance.type,
  'sessionId': instance.sessionId,
  'seq': instance.seq,
  'at': instance.at?.toIso8601String(),
  'approval': instance.approval.toJson(),
};

_$ApprovalWireDtoImpl _$$ApprovalWireDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ApprovalWireDtoImpl(
  app: ApprovalAppDto.fromJson(json['app'] as Map<String, dynamic>),
  acp: json['acp'] == null
      ? null
      : AcpRequestPermissionRequestDto.fromJson(
          json['acp'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$$ApprovalWireDtoImplToJson(
  _$ApprovalWireDtoImpl instance,
) => <String, dynamic>{
  'app': instance.app.toJson(),
  'acp': instance.acp?.toJson(),
};

_$ApprovalAppDtoImpl _$$ApprovalAppDtoImplFromJson(Map<String, dynamic> json) =>
    _$ApprovalAppDtoImpl(
      requestId: json['requestId'] as String,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      runtime: json['runtime'] as String?,
      toolCallId: json['toolCallId'] as String?,
      toolKind: json['toolKind'] as String?,
      title: json['title'] as String?,
      bodyText: json['bodyText'] as String?,
      command: json['command'] == null
          ? null
          : ApprovalCommandDto.fromJson(
              json['command'] as Map<String, dynamic>,
            ),
      cwd: json['cwd'] as String?,
      reason: json['reason'] as String?,
      plan: json['plan'] == null
          ? null
          : ApprovalPlanDto.fromJson(json['plan'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$ApprovalAppDtoImplToJson(
  _$ApprovalAppDtoImpl instance,
) => <String, dynamic>{
  'requestId': instance.requestId,
  'createdAt': instance.createdAt?.toIso8601String(),
  'runtime': instance.runtime,
  'toolCallId': instance.toolCallId,
  'toolKind': instance.toolKind,
  'title': instance.title,
  'bodyText': instance.bodyText,
  'command': instance.command?.toJson(),
  'cwd': instance.cwd,
  'reason': instance.reason,
  'plan': instance.plan?.toJson(),
};

_$ApprovalCommandDtoImpl _$$ApprovalCommandDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ApprovalCommandDtoImpl(
  argv:
      (json['argv'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  display: json['display'] as String?,
);

Map<String, dynamic> _$$ApprovalCommandDtoImplToJson(
  _$ApprovalCommandDtoImpl instance,
) => <String, dynamic>{'argv': instance.argv, 'display': instance.display};

_$ApprovalPlanDtoImpl _$$ApprovalPlanDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ApprovalPlanDtoImpl(
  markdown: json['markdown'] as String?,
  allowedPrompts:
      (json['allowedPrompts'] as List<dynamic>?)
          ?.map(
            (e) => ApprovalAllowedPromptDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <ApprovalAllowedPromptDto>[],
);

Map<String, dynamic> _$$ApprovalPlanDtoImplToJson(
  _$ApprovalPlanDtoImpl instance,
) => <String, dynamic>{
  'markdown': instance.markdown,
  'allowedPrompts': instance.allowedPrompts.map((e) => e.toJson()).toList(),
};

_$ApprovalAllowedPromptDtoImpl _$$ApprovalAllowedPromptDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ApprovalAllowedPromptDtoImpl(prompt: json['prompt'] as String);

Map<String, dynamic> _$$ApprovalAllowedPromptDtoImplToJson(
  _$ApprovalAllowedPromptDtoImpl instance,
) => <String, dynamic>{'prompt': instance.prompt};

_$AcpRequestPermissionRequestDtoImpl
_$$AcpRequestPermissionRequestDtoImplFromJson(Map<String, dynamic> json) =>
    _$AcpRequestPermissionRequestDtoImpl(
      meta: json['_meta'] as Map<String, dynamic>?,
      sessionId: json['sessionId'] as String,
      toolCall: AcpToolCallUpdateDto.fromJson(
        json['toolCall'] as Map<String, dynamic>,
      ),
      options:
          (json['options'] as List<dynamic>?)
              ?.map(
                (e) =>
                    AcpPermissionOptionDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <AcpPermissionOptionDto>[],
    );

Map<String, dynamic> _$$AcpRequestPermissionRequestDtoImplToJson(
  _$AcpRequestPermissionRequestDtoImpl instance,
) => <String, dynamic>{
  if (instance.meta case final value?) '_meta': value,
  'sessionId': instance.sessionId,
  'toolCall': instance.toolCall.toJson(),
  'options': instance.options.map((e) => e.toJson()).toList(),
};

_$AcpPermissionOptionDtoImpl _$$AcpPermissionOptionDtoImplFromJson(
  Map<String, dynamic> json,
) => _$AcpPermissionOptionDtoImpl(
  meta: json['_meta'] as Map<String, dynamic>?,
  optionId: json['optionId'] as String,
  name: json['name'] as String,
  kind: json['kind'] as String,
);

Map<String, dynamic> _$$AcpPermissionOptionDtoImplToJson(
  _$AcpPermissionOptionDtoImpl instance,
) => <String, dynamic>{
  if (instance.meta case final value?) '_meta': value,
  'optionId': instance.optionId,
  'name': instance.name,
  'kind': instance.kind,
};

_$AcpRequestPermissionResponseDtoImpl
_$$AcpRequestPermissionResponseDtoImplFromJson(Map<String, dynamic> json) =>
    _$AcpRequestPermissionResponseDtoImpl(
      meta: json['_meta'] as Map<String, dynamic>?,
      outcome: AcpRequestPermissionOutcomeDto.fromJson(
        json['outcome'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$$AcpRequestPermissionResponseDtoImplToJson(
  _$AcpRequestPermissionResponseDtoImpl instance,
) => <String, dynamic>{
  if (instance.meta case final value?) '_meta': value,
  'outcome': instance.outcome.toJson(),
};

_$AcpRequestPermissionOutcomeDtoImpl
_$$AcpRequestPermissionOutcomeDtoImplFromJson(Map<String, dynamic> json) =>
    _$AcpRequestPermissionOutcomeDtoImpl(
      meta: json['_meta'] as Map<String, dynamic>?,
      outcome: json['outcome'] as String,
      optionId: json['optionId'] as String?,
    );

Map<String, dynamic> _$$AcpRequestPermissionOutcomeDtoImplToJson(
  _$AcpRequestPermissionOutcomeDtoImpl instance,
) => <String, dynamic>{
  if (instance.meta case final value?) '_meta': value,
  'outcome': instance.outcome,
  if (instance.optionId case final value?) 'optionId': value,
};
