// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'approval_event_models.dart';

part 'rpc_result_models.freezed.dart';
part 'rpc_result_models.g.dart';

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

String _requiredString(Object? value) {
  if (value is String) return value;
  throw FormatException('Expected a string');
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected a string or null');
}

bool _requiredBool(Object? value) {
  if (value is bool) return value;
  throw FormatException('Expected a bool');
}

bool? _nullableBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  throw FormatException('Expected a bool or null');
}

int _nullableIntWithDefaultZero(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  throw FormatException('Expected a number or null');
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  throw FormatException('Expected a number or null');
}

enum RpcResyncStatusDto { ok, gap, reset }

RpcResyncStatusDto? _nullableResyncStatus(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Expected a string or null');
  }
  return switch (value) {
    'ok' => RpcResyncStatusDto.ok,
    'gap' => RpcResyncStatusDto.gap,
    'reset' => RpcResyncStatusDto.reset,
    _ => throw FormatException('Expected a valid resync status'),
  };
}

DateTime? _nullableDateTime(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Expected an ISO-8601 datetime string or null');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed != null) return parsed;
  throw FormatException('Expected an ISO-8601 datetime string');
}

@freezed
class RpcResyncResponseDto with _$RpcResyncResponseDto {
  const factory RpcResyncResponseDto({
    @JsonKey(fromJson: _requiredObjectList)
    required List<Map<String, dynamic>> events,
    @JsonKey(fromJson: _nullableBool) bool? complete,
    @JsonKey(fromJson: _nullableIntWithDefaultZero) @Default(0) int seq,
    @JsonKey(fromJson: _nullableResyncStatus) RpcResyncStatusDto? status,
    @JsonKey(name: 'streamEpoch', fromJson: _nullableInt) int? streamEpoch,
    @JsonKey(name: 'replayedThroughSeq', fromJson: _nullableInt)
    int? replayedThroughSeq,
  }) = _RpcResyncResponseDto;

  factory RpcResyncResponseDto.fromJson(Map<String, dynamic> json) =>
      _$RpcResyncResponseDtoFromJson(json);
}

@freezed
class RpcOkResponseDto with _$RpcOkResponseDto {
  const factory RpcOkResponseDto({
    @JsonKey(fromJson: _requiredBool) required bool ok,
  }) = _RpcOkResponseDto;

  factory RpcOkResponseDto.fromJson(Map<String, dynamic> json) =>
      _$RpcOkResponseDtoFromJson(json);
}

@freezed
class RpcAcceptedResponseDto with _$RpcAcceptedResponseDto {
  const factory RpcAcceptedResponseDto({
    @JsonKey(fromJson: _requiredBool) required bool accepted,
  }) = _RpcAcceptedResponseDto;

  factory RpcAcceptedResponseDto.fromJson(Map<String, dynamic> json) =>
      _$RpcAcceptedResponseDtoFromJson(json);
}

@freezed
class RpcResolvedSessionDto with _$RpcResolvedSessionDto {
  const factory RpcResolvedSessionDto({
    @JsonKey(name: 'sessionId', fromJson: _requiredString)
    required String sessionId,
    @JsonKey(fromJson: _nullableString) String? title,
    @JsonKey(fromJson: _nullableString) String? cwd,
    @JsonKey(fromJson: _nullableString) String? status,
    @JsonKey(name: 'updatedAt', fromJson: _nullableDateTime)
    DateTime? updatedAt,
  }) = _RpcResolvedSessionDto;

  factory RpcResolvedSessionDto.fromJson(Map<String, dynamic> json) =>
      _$RpcResolvedSessionDtoFromJson(json);
}

@freezed
class RpcSessionResolveResponseDto with _$RpcSessionResolveResponseDto {
  const factory RpcSessionResolveResponseDto({
    @JsonKey(fromJson: _resolvedSessionListFromJson)
    required List<RpcResolvedSessionDto> sessions,
  }) = _RpcSessionResolveResponseDto;

  factory RpcSessionResolveResponseDto.fromJson(Map<String, dynamic> json) =>
      _$RpcSessionResolveResponseDtoFromJson(json);
}

@freezed
class RpcPendingApprovalsResponseDto with _$RpcPendingApprovalsResponseDto {
  const factory RpcPendingApprovalsResponseDto({
    @JsonKey(fromJson: _approvalWireListFromJson)
    required List<ApprovalWireDto> approvals,
  }) = _RpcPendingApprovalsResponseDto;

  factory RpcPendingApprovalsResponseDto.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('approvals')) {
      throw FormatException('Expected approvals field');
    }
    final normalized = Map<String, dynamic>.from(json);
    normalized['approvals'] ??= const <Object>[];
    return RpcPendingApprovalsResponseDto(
      approvals: _approvalWireListFromJson(normalized['approvals']),
    );
  }
}

@freezed
class RpcFsEntryDto with _$RpcFsEntryDto {
  const factory RpcFsEntryDto({
    @JsonKey(fromJson: _requiredString) required String path,
    @JsonKey(name: 'isDir', fromJson: _requiredBool) required bool isDir,
    @JsonKey(fromJson: _nullableString) String? name,
  }) = _RpcFsEntryDto;

  factory RpcFsEntryDto.fromJson(Map<String, dynamic> json) =>
      _$RpcFsEntryDtoFromJson(json);
}

@freezed
class RpcFsListResponseDto with _$RpcFsListResponseDto {
  const factory RpcFsListResponseDto({
    @JsonKey(fromJson: _fsEntryListFromJson)
    required List<RpcFsEntryDto> entries,
  }) = _RpcFsListResponseDto;

  factory RpcFsListResponseDto.fromJson(Map<String, dynamic> json) =>
      _$RpcFsListResponseDtoFromJson(json);
}

@freezed
class RpcFsSearchResponseDto with _$RpcFsSearchResponseDto {
  const factory RpcFsSearchResponseDto({
    @JsonKey(fromJson: _fsEntryListFromJson)
    required List<RpcFsEntryDto> results,
  }) = _RpcFsSearchResponseDto;

  factory RpcFsSearchResponseDto.fromJson(Map<String, dynamic> json) =>
      _$RpcFsSearchResponseDtoFromJson(json);
}

List<RpcResolvedSessionDto> _resolvedSessionListFromJson(Object? value) {
  return _requiredObjectList(
    value,
  ).map(RpcResolvedSessionDto.fromJson).toList();
}

List<ApprovalWireDto> _approvalWireListFromJson(Object? value) {
  return _requiredObjectList(value).map(ApprovalWireDto.fromJson).toList();
}

List<RpcFsEntryDto> _fsEntryListFromJson(Object? value) {
  return _requiredObjectList(value).map(RpcFsEntryDto.fromJson).toList();
}
