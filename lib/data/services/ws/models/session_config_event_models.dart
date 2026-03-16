// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'acp_session_models.dart';

part 'session_config_event_models.freezed.dart';
part 'session_config_event_models.g.dart';

Map<String, dynamic> _requiredObject(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected an object');
}

String _requiredString(Object? value) {
  if (value is String) return value;
  throw FormatException('Expected a string');
}

@Freezed(toJson: false)
class ModeChangedEventEnvelopeDto with _$ModeChangedEventEnvelopeDto {
  const factory ModeChangedEventEnvelopeDto({
    @JsonKey(fromJson: _requiredString) required String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    @Default(0) int seq,
    DateTime? at,
    @JsonKey(name: 'modeChanged', fromJson: _modeChangedEnvelopeFromJson)
    required AppModeChangedEventDataDto modeChanged,
  }) = _ModeChangedEventEnvelopeDto;

  factory ModeChangedEventEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$ModeChangedEventEnvelopeDtoFromJson(json);
}

@Freezed(toJson: false)
class ConfigChangedEventEnvelopeDto with _$ConfigChangedEventEnvelopeDto {
  const factory ConfigChangedEventEnvelopeDto({
    @JsonKey(fromJson: _requiredString) required String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    @Default(0) int seq,
    DateTime? at,
    @JsonKey(name: 'configChanged', fromJson: _configChangedEnvelopeFromJson)
    required AppConfigChangedEventDataDto configChanged,
  }) = _ConfigChangedEventEnvelopeDto;

  factory ConfigChangedEventEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$ConfigChangedEventEnvelopeDtoFromJson(json);
}

AppModeChangedEventDataDto _modeChangedEnvelopeFromJson(Object? value) {
  return AppModeChangedEventDataDto.fromJson(_requiredObject(value));
}

AppConfigChangedEventDataDto _configChangedEnvelopeFromJson(Object? value) {
  return AppConfigChangedEventDataDto.fromJson(_requiredObject(value));
}
