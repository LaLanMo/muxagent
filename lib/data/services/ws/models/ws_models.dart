import 'package:freezed_annotation/freezed_annotation.dart';

part 'ws_models.freezed.dart';
part 'ws_models.g.dart';

@freezed
class WsRegister with _$WsRegister {
  const factory WsRegister({
    required String type,
    required String role,
    @JsonKey(name: 'machine_id') String? machineId,
    String? hostname,
    @JsonKey(name: 'connect_token') String? connectToken,
  }) = _WsRegister;

  factory WsRegister.fromJson(Map<String, dynamic> json) =>
      _$WsRegisterFromJson(json);
}

@freezed
class WsChallenge with _$WsChallenge {
  const factory WsChallenge({required String type, required String nonce}) =
      _WsChallenge;

  factory WsChallenge.fromJson(Map<String, dynamic> json) =>
      _$WsChallengeFromJson(json);
}

@freezed
class WsChallengeResponse with _$WsChallengeResponse {
  const factory WsChallengeResponse({
    required String type,
    required String signature,
  }) = _WsChallengeResponse;

  factory WsChallengeResponse.fromJson(Map<String, dynamic> json) =>
      _$WsChallengeResponseFromJson(json);
}

@freezed
class WsRegistered with _$WsRegistered {
  const factory WsRegistered({
    required String type,
    @JsonKey(name: 'master_id') String? masterId,
    @JsonKey(name: 'machine_id') String? machineId,
  }) = _WsRegistered;

  factory WsRegistered.fromJson(Map<String, dynamic> json) =>
      _$WsRegisteredFromJson(json);
}

@freezed
class WsSessionInit with _$WsSessionInit {
  const factory WsSessionInit({
    required String type,
    @JsonKey(name: 'machine_id') required String machineId,
    @JsonKey(name: 'machine_token') required String machineToken,
    @JsonKey(name: 'client_ephemeral_pub') required String clientEphemeralPub,
    required String signature,
    @Default(false) bool force,
  }) = _WsSessionInit;

  factory WsSessionInit.fromJson(Map<String, dynamic> json) =>
      _$WsSessionInitFromJson(json);
}

@freezed
class WsSessionAck with _$WsSessionAck {
  const factory WsSessionAck({
    required String type,
    @JsonKey(name: 'machine_id') required String machineId,
    @JsonKey(name: 'machine_ephemeral_pub') required String machineEphemeralPub,
    required String signature,
  }) = _WsSessionAck;

  factory WsSessionAck.fromJson(Map<String, dynamic> json) =>
      _$WsSessionAckFromJson(json);
}

@freezed
class WsSessionEnd with _$WsSessionEnd {
  const factory WsSessionEnd({
    required String type,
    @JsonKey(name: 'machine_id') required String machineId,
  }) = _WsSessionEnd;

  factory WsSessionEnd.fromJson(Map<String, dynamic> json) =>
      _$WsSessionEndFromJson(json);
}

@freezed
class WsEncryptedMessage with _$WsEncryptedMessage {
  const factory WsEncryptedMessage({
    required String type,
    @JsonKey(name: 'machine_id') required String machineId,
    @JsonKey(name: 'msg_id') required String msgId,
    required String nonce,
    required String ciphertext,
  }) = _WsEncryptedMessage;

  factory WsEncryptedMessage.fromJson(Map<String, dynamic> json) =>
      _$WsEncryptedMessageFromJson(json);
}

@freezed
class WsErrorMessage with _$WsErrorMessage {
  const factory WsErrorMessage({required String type, required String error}) =
      _WsErrorMessage;

  factory WsErrorMessage.fromJson(Map<String, dynamic> json) =>
      _$WsErrorMessageFromJson(json);
}

@freezed
class WsMachineStatus with _$WsMachineStatus {
  const factory WsMachineStatus({
    required String type,
    @JsonKey(name: 'machine_id') required String machineId,
    required String hostname,
  }) = _WsMachineStatus;

  factory WsMachineStatus.fromJson(Map<String, dynamic> json) =>
      _$WsMachineStatusFromJson(json);
}

@freezed
class WsEvent with _$WsEvent {
  const factory WsEvent({
    required String type,
    required Map<String, dynamic> payload,
  }) = _WsEvent;

  factory WsEvent.fromJson(Map<String, dynamic> json) =>
      _$WsEventFromJson(json);
}

@freezed
class WsRpcPayload with _$WsRpcPayload {
  const factory WsRpcPayload({
    required String method,
    Map<String, dynamic>? params,
  }) = _WsRpcPayload;

  factory WsRpcPayload.fromJson(Map<String, dynamic> json) =>
      _$WsRpcPayloadFromJson(json);
}
