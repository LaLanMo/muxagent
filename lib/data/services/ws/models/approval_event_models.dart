// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'acp_tool_call_models.dart';

part 'approval_event_models.freezed.dart';
part 'approval_event_models.g.dart';

@freezed
class ApprovalEventEnvelopeDto with _$ApprovalEventEnvelopeDto {
  const factory ApprovalEventEnvelopeDto({
    required String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    @Default(0) int seq,
    DateTime? at,
    required ApprovalWireDto approval,
  }) = _ApprovalEventEnvelopeDto;

  factory ApprovalEventEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$ApprovalEventEnvelopeDtoFromJson(json);
}

@freezed
class ApprovalWireDto with _$ApprovalWireDto {
  const factory ApprovalWireDto({
    required ApprovalAppDto app,
    AcpRequestPermissionRequestDto? acp,
  }) = _ApprovalWireDto;

  factory ApprovalWireDto.fromJson(Map<String, dynamic> json) =>
      _$ApprovalWireDtoFromJson(json);
}

@freezed
class ApprovalAppDto with _$ApprovalAppDto {
  const factory ApprovalAppDto({
    @JsonKey(name: 'requestId') required String requestId,
    @JsonKey(name: 'createdAt') DateTime? createdAt,
    String? runtime,
    @JsonKey(name: 'toolCallId') String? toolCallId,
    @JsonKey(name: 'toolKind') String? toolKind,
    String? title,
    @JsonKey(name: 'bodyText') String? bodyText,
    ApprovalCommandDto? command,
    String? cwd,
    String? reason,
    ApprovalPlanDto? plan,
  }) = _ApprovalAppDto;

  factory ApprovalAppDto.fromJson(Map<String, dynamic> json) =>
      _$ApprovalAppDtoFromJson(json);
}

@freezed
class ApprovalCommandDto with _$ApprovalCommandDto {
  const factory ApprovalCommandDto({
    @Default(<String>[]) List<String> argv,
    String? display,
  }) = _ApprovalCommandDto;

  factory ApprovalCommandDto.fromJson(Map<String, dynamic> json) =>
      _$ApprovalCommandDtoFromJson(json);
}

@freezed
class ApprovalPlanDto with _$ApprovalPlanDto {
  const factory ApprovalPlanDto({
    String? markdown,
    @JsonKey(name: 'allowedPrompts')
    @Default(<ApprovalAllowedPromptDto>[])
    List<ApprovalAllowedPromptDto> allowedPrompts,
  }) = _ApprovalPlanDto;

  factory ApprovalPlanDto.fromJson(Map<String, dynamic> json) =>
      _$ApprovalPlanDtoFromJson(json);
}

@freezed
class ApprovalAllowedPromptDto with _$ApprovalAllowedPromptDto {
  const factory ApprovalAllowedPromptDto({required String prompt}) =
      _ApprovalAllowedPromptDto;

  factory ApprovalAllowedPromptDto.fromJson(Map<String, dynamic> json) =>
      _$ApprovalAllowedPromptDtoFromJson(json);
}

@freezed
class AcpRequestPermissionRequestDto with _$AcpRequestPermissionRequestDto {
  @JsonSerializable(includeIfNull: false)
  const factory AcpRequestPermissionRequestDto({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    @JsonKey(name: 'sessionId') required String sessionId,
    @JsonKey(name: 'toolCall') required AcpToolCallUpdateDto toolCall,
    @Default(<AcpPermissionOptionDto>[]) List<AcpPermissionOptionDto> options,
  }) = _AcpRequestPermissionRequestDto;

  factory AcpRequestPermissionRequestDto.fromJson(Map<String, dynamic> json) =>
      _$AcpRequestPermissionRequestDtoFromJson(json);
}

@freezed
class AcpPermissionOptionDto with _$AcpPermissionOptionDto {
  @JsonSerializable(includeIfNull: false)
  const factory AcpPermissionOptionDto({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    @JsonKey(name: 'optionId') required String optionId,
    required String name,
    required String kind,
  }) = _AcpPermissionOptionDto;

  factory AcpPermissionOptionDto.fromJson(Map<String, dynamic> json) =>
      _$AcpPermissionOptionDtoFromJson(json);
}

@freezed
class AcpRequestPermissionResponseDto with _$AcpRequestPermissionResponseDto {
  @JsonSerializable(includeIfNull: false)
  const factory AcpRequestPermissionResponseDto({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    required AcpRequestPermissionOutcomeDto outcome,
  }) = _AcpRequestPermissionResponseDto;

  factory AcpRequestPermissionResponseDto.fromJson(Map<String, dynamic> json) =>
      _$AcpRequestPermissionResponseDtoFromJson(json);
}

@freezed
class AcpRequestPermissionOutcomeDto with _$AcpRequestPermissionOutcomeDto {
  @JsonSerializable(includeIfNull: false)
  const factory AcpRequestPermissionOutcomeDto({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    required String outcome,
    @JsonKey(name: 'optionId') String? optionId,
  }) = _AcpRequestPermissionOutcomeDto;

  factory AcpRequestPermissionOutcomeDto.fromJson(Map<String, dynamic> json) =>
      _$AcpRequestPermissionOutcomeDtoFromJson(json);
}
