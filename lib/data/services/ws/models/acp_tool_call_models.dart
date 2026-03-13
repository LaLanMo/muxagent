// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'acp_tool_call_models.freezed.dart';
part 'acp_tool_call_models.g.dart';

@freezed
class AcpToolCallUpdateDto with _$AcpToolCallUpdateDto {
  const factory AcpToolCallUpdateDto({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    @JsonKey(name: 'toolCallId') required String toolCallId,
    String? title,
    String? kind,
    String? status,
    List<Map<String, dynamic>>? content,
    List<AcpToolCallLocationDto>? locations,
    @JsonKey(name: 'rawInput') Object? rawInput,
    @JsonKey(name: 'rawOutput') Object? rawOutput,
  }) = _AcpToolCallUpdateDto;

  factory AcpToolCallUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$AcpToolCallUpdateDtoFromJson(json);
}

@freezed
class AcpToolCallLocationDto with _$AcpToolCallLocationDto {
  const factory AcpToolCallLocationDto({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    required String path,
    int? line,
  }) = _AcpToolCallLocationDto;

  factory AcpToolCallLocationDto.fromJson(Map<String, dynamic> json) =>
      _$AcpToolCallLocationDtoFromJson(json);
}
