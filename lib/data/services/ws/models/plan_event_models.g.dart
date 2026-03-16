// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_event_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppPlanEntryDtoImpl _$$AppPlanEntryDtoImplFromJson(
  Map<String, dynamic> json,
) => _$AppPlanEntryDtoImpl(
  content: _requiredString(json['content']),
  priority: _requiredString(json['priority']),
  status: _requiredString(json['status']),
);

_$AppPlanUpdateDtoImpl _$$AppPlanUpdateDtoImplFromJson(
  Map<String, dynamic> json,
) => _$AppPlanUpdateDtoImpl(
  entries: json['entries'] == null
      ? const <AppPlanEntryDto>[]
      : _appPlanEntryListFromJson(json['entries']),
);

_$PlanWireDtoImpl _$$PlanWireDtoImplFromJson(Map<String, dynamic> json) =>
    _$PlanWireDtoImpl(
      app: _appPlanUpdateFromJson(json['app']),
      acp: _nullableAcpPlanUpdate(json['acp']),
    );

_$PlanEventEnvelopeDtoImpl _$$PlanEventEnvelopeDtoImplFromJson(
  Map<String, dynamic> json,
) => _$PlanEventEnvelopeDtoImpl(
  type: _requiredString(json['type']),
  sessionId: json['sessionId'] as String?,
  seq: (json['seq'] as num?)?.toInt() ?? 0,
  at: json['at'] == null ? null : DateTime.parse(json['at'] as String),
  plan: _planWireFromJson(json['plan']),
);
