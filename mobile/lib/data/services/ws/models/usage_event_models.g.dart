// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usage_event_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUsageUpdateDtoImpl _$$AppUsageUpdateDtoImplFromJson(
  Map<String, dynamic> json,
) => _$AppUsageUpdateDtoImpl(
  contextUsed: _requiredNum(json['contextUsed']),
  contextSize: _requiredNum(json['contextSize']),
  costAmount: _nullableDouble(json['costAmount']),
  costCurrency: _nullableString(json['costCurrency']),
);

_$UsageWireDtoImpl _$$UsageWireDtoImplFromJson(Map<String, dynamic> json) =>
    _$UsageWireDtoImpl(
      app: _appUsageFromJson(json['app']),
      acp: _nullableAcpUsage(json['acp']),
    );

_$UsageEventEnvelopeDtoImpl _$$UsageEventEnvelopeDtoImplFromJson(
  Map<String, dynamic> json,
) => _$UsageEventEnvelopeDtoImpl(
  type: _requiredString(json['type']),
  sessionId: json['sessionId'] as String?,
  seq: (json['seq'] as num?)?.toInt() ?? 0,
  at: json['at'] == null ? null : DateTime.parse(json['at'] as String),
  usage: _usageWireFromJson(json['usage']),
);
