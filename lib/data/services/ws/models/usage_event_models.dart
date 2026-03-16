// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'acp_session_models.dart';

part 'usage_event_models.freezed.dart';
part 'usage_event_models.g.dart';

num _requiredNum(Object? value) {
  if (value is num) return value;
  throw FormatException('Expected a number');
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Expected a number or null');
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected a string or null');
}

Map<String, dynamic> _requiredObject(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected an object');
}

@Freezed(toJson: false)
class AppUsageUpdateDto with _$AppUsageUpdateDto {
  const factory AppUsageUpdateDto({
    @JsonKey(name: 'contextUsed', fromJson: _requiredNum)
    required num contextUsed,
    @JsonKey(name: 'contextSize', fromJson: _requiredNum)
    required num contextSize,
    @JsonKey(name: 'costAmount', fromJson: _nullableDouble) double? costAmount,
    @JsonKey(name: 'costCurrency', fromJson: _nullableString)
    String? costCurrency,
  }) = _AppUsageUpdateDto;

  factory AppUsageUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$AppUsageUpdateDtoFromJson(json);
}

@Freezed(toJson: false)
class UsageWireDto with _$UsageWireDto {
  const factory UsageWireDto({
    @JsonKey(fromJson: _appUsageFromJson) required AppUsageUpdateDto app,
    @JsonKey(fromJson: _nullableAcpUsage) AcpUsageUpdateDto? acp,
  }) = _UsageWireDto;

  factory UsageWireDto.fromJson(Map<String, dynamic> json) =>
      _$UsageWireDtoFromJson(json);
}

@Freezed(toJson: false)
class UsageEventEnvelopeDto with _$UsageEventEnvelopeDto {
  const factory UsageEventEnvelopeDto({
    @JsonKey(fromJson: _requiredString) required String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    @Default(0) int seq,
    DateTime? at,
    @JsonKey(fromJson: _usageWireFromJson) required UsageWireDto usage,
  }) = _UsageEventEnvelopeDto;

  factory UsageEventEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$UsageEventEnvelopeDtoFromJson(json);
}

String _requiredString(Object? value) {
  if (value is String) return value;
  throw FormatException('Expected a string');
}

AppUsageUpdateDto _appUsageFromJson(Object? value) {
  return AppUsageUpdateDto.fromJson(_requiredObject(value));
}

UsageWireDto _usageWireFromJson(Object? value) {
  return UsageWireDto.fromJson(_requiredObject(value));
}

AcpUsageUpdateDto? _nullableAcpUsage(Object? value) {
  if (value == null) return null;
  return AcpUsageUpdateDto.fromJson(_requiredObject(value));
}
