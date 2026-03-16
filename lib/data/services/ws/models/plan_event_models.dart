// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'acp_session_models.dart';

part 'plan_event_models.freezed.dart';
part 'plan_event_models.g.dart';

List<Map<String, dynamic>> _requiredObjectList(Object? value) {
  if (value is! List) {
    throw FormatException('Expected a list of objects');
  }
  return value.map((item) {
    if (item is! Map) {
      throw FormatException('Expected list items to be objects');
    }
    return Map<String, dynamic>.from(item);
  }).toList();
}

Map<String, dynamic> _requiredObject(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected an object');
}

String _requiredString(Object? value) {
  if (value is String) return value;
  throw FormatException('Expected a string');
}

@Freezed(toJson: false)
class AppPlanEntryDto with _$AppPlanEntryDto {
  const factory AppPlanEntryDto({
    @JsonKey(fromJson: _requiredString) required String content,
    @JsonKey(fromJson: _requiredString) required String priority,
    @JsonKey(fromJson: _requiredString) required String status,
  }) = _AppPlanEntryDto;

  factory AppPlanEntryDto.fromJson(Map<String, dynamic> json) =>
      _$AppPlanEntryDtoFromJson(json);
}

@Freezed(toJson: false)
class AppPlanUpdateDto with _$AppPlanUpdateDto {
  const factory AppPlanUpdateDto({
    @JsonKey(fromJson: _appPlanEntryListFromJson)
    @Default(<AppPlanEntryDto>[])
    List<AppPlanEntryDto> entries,
  }) = _AppPlanUpdateDto;

  factory AppPlanUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$AppPlanUpdateDtoFromJson(json);
}

@Freezed(toJson: false)
class PlanWireDto with _$PlanWireDto {
  const factory PlanWireDto({
    @JsonKey(fromJson: _appPlanUpdateFromJson) required AppPlanUpdateDto app,
    @JsonKey(fromJson: _nullableAcpPlanUpdate) AcpPlanUpdateDto? acp,
  }) = _PlanWireDto;

  factory PlanWireDto.fromJson(Map<String, dynamic> json) =>
      _$PlanWireDtoFromJson(json);
}

@Freezed(toJson: false)
class PlanEventEnvelopeDto with _$PlanEventEnvelopeDto {
  const factory PlanEventEnvelopeDto({
    @JsonKey(fromJson: _requiredString) required String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    @Default(0) int seq,
    DateTime? at,
    @JsonKey(fromJson: _planWireFromJson) required PlanWireDto plan,
  }) = _PlanEventEnvelopeDto;

  factory PlanEventEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$PlanEventEnvelopeDtoFromJson(json);
}

List<AppPlanEntryDto> _appPlanEntryListFromJson(Object? value) {
  return _requiredObjectList(value).map(AppPlanEntryDto.fromJson).toList();
}

AppPlanUpdateDto _appPlanUpdateFromJson(Object? value) {
  return AppPlanUpdateDto.fromJson(_requiredObject(value));
}

PlanWireDto _planWireFromJson(Object? value) {
  return PlanWireDto.fromJson(_requiredObject(value));
}

AcpPlanUpdateDto? _nullableAcpPlanUpdate(Object? value) {
  if (value == null) return null;
  return AcpPlanUpdateDto.fromJson(_requiredObject(value));
}
