// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'acp_tool_call_models.dart';

part 'tool_event_models.freezed.dart';
part 'tool_event_models.g.dart';

@freezed
class ToolEventEnvelopeDto with _$ToolEventEnvelopeDto {
  const factory ToolEventEnvelopeDto({
    required String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    @Default(0) int seq,
    DateTime? at,
    required ToolWireDto tool,
  }) = _ToolEventEnvelopeDto;

  factory ToolEventEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$ToolEventEnvelopeDtoFromJson(json);
}

@freezed
class ToolWireDto with _$ToolWireDto {
  const factory ToolWireDto({
    required ToolAppDto app,
    AcpToolCallUpdateDto? acp,
  }) = _ToolWireDto;

  factory ToolWireDto.fromJson(Map<String, dynamic> json) =>
      _$ToolWireDtoFromJson(json);
}

@freezed
class ToolAppDto with _$ToolAppDto {
  const factory ToolAppDto({
    @JsonKey(name: 'partId') required String partId,
    @JsonKey(name: 'messageId') required String messageId,
    @JsonKey(name: 'callId') required String callId,
    required String name,
    String? kind,
    String? title,
    required String status,
    ToolInputDto? input,
    String? output,
    String? error,
    @Default(<ToolDiffDto>[]) List<ToolDiffDto> diffs,
    @JsonKey(name: 'claudeCode') ClaudeCodeToolDto? claudeCode,
    @Default(<ToolLocationDto>[]) List<ToolLocationDto> locations,
  }) = _ToolAppDto;

  factory ToolAppDto.fromJson(Map<String, dynamic> json) =>
      _$ToolAppDtoFromJson(json);
}

@freezed
class ToolInputDto with _$ToolInputDto {
  const factory ToolInputDto({
    String? description,
    ToolCommandDto? command,
    @JsonKey(name: 'filePath') String? filePath,
    @JsonKey(name: 'sourcePath') String? sourcePath,
    @JsonKey(name: 'targetPath') String? targetPath,
    String? pattern,
    String? url,
    String? mode,
    ToolEditInputDto? edit,
    @JsonKey(name: 'rawInputJson') String? rawInputJson,
  }) = _ToolInputDto;

  factory ToolInputDto.fromJson(Map<String, dynamic> json) =>
      _$ToolInputDtoFromJson(json);
}

@freezed
class ToolCommandDto with _$ToolCommandDto {
  const factory ToolCommandDto({
    @Default(<String>[]) List<String> argv,
    String? display,
  }) = _ToolCommandDto;

  factory ToolCommandDto.fromJson(Map<String, dynamic> json) =>
      _$ToolCommandDtoFromJson(json);
}

@freezed
class ToolEditInputDto with _$ToolEditInputDto {
  const factory ToolEditInputDto({
    @JsonKey(name: 'filePath') String? filePath,
    @JsonKey(name: 'oldString') String? oldString,
    @JsonKey(name: 'newString') String? newString,
  }) = _ToolEditInputDto;

  factory ToolEditInputDto.fromJson(Map<String, dynamic> json) =>
      _$ToolEditInputDtoFromJson(json);
}

@freezed
class ClaudeCodeToolDto with _$ClaudeCodeToolDto {
  const factory ClaudeCodeToolDto({
    @JsonKey(name: 'parentToolUseId') String? parentToolUseId,
    @JsonKey(name: 'toolName') String? toolName,
  }) = _ClaudeCodeToolDto;

  factory ClaudeCodeToolDto.fromJson(Map<String, dynamic> json) =>
      _$ClaudeCodeToolDtoFromJson(json);
}

@freezed
class ToolDiffDto with _$ToolDiffDto {
  const factory ToolDiffDto({
    required String path,
    @JsonKey(name: 'oldText') String? oldText,
    @JsonKey(name: 'newText') required String newText,
  }) = _ToolDiffDto;

  factory ToolDiffDto.fromJson(Map<String, dynamic> json) =>
      _$ToolDiffDtoFromJson(json);
}

@freezed
class ToolLocationDto with _$ToolLocationDto {
  const factory ToolLocationDto({required String path, int? line}) =
      _ToolLocationDto;

  factory ToolLocationDto.fromJson(Map<String, dynamic> json) =>
      _$ToolLocationDtoFromJson(json);
}
