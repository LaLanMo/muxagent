// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_config_event_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ModeChangedEventEnvelopeDtoImpl _$$ModeChangedEventEnvelopeDtoImplFromJson(
  Map<String, dynamic> json,
) => _$ModeChangedEventEnvelopeDtoImpl(
  type: _requiredString(json['type']),
  sessionId: json['sessionId'] as String?,
  seq: (json['seq'] as num?)?.toInt() ?? 0,
  at: json['at'] == null ? null : DateTime.parse(json['at'] as String),
  modeChanged: _modeChangedEnvelopeFromJson(json['modeChanged']),
);

_$ConfigChangedEventEnvelopeDtoImpl
_$$ConfigChangedEventEnvelopeDtoImplFromJson(Map<String, dynamic> json) =>
    _$ConfigChangedEventEnvelopeDtoImpl(
      type: _requiredString(json['type']),
      sessionId: json['sessionId'] as String?,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      at: json['at'] == null ? null : DateTime.parse(json['at'] as String),
      configChanged: _configChangedEnvelopeFromJson(json['configChanged']),
    );
