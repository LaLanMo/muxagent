// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WsRegisterImpl _$$WsRegisterImplFromJson(Map<String, dynamic> json) =>
    _$WsRegisterImpl(
      type: json['type'] as String,
      role: json['role'] as String,
      machineId: json['machine_id'] as String?,
      hostname: json['hostname'] as String?,
      connectToken: json['connect_token'] as String?,
    );

Map<String, dynamic> _$$WsRegisterImplToJson(_$WsRegisterImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'role': instance.role,
      'machine_id': instance.machineId,
      'hostname': instance.hostname,
      'connect_token': instance.connectToken,
    };

_$WsChallengeImpl _$$WsChallengeImplFromJson(Map<String, dynamic> json) =>
    _$WsChallengeImpl(
      type: json['type'] as String,
      nonce: json['nonce'] as String,
    );

Map<String, dynamic> _$$WsChallengeImplToJson(_$WsChallengeImpl instance) =>
    <String, dynamic>{'type': instance.type, 'nonce': instance.nonce};

_$WsChallengeResponseImpl _$$WsChallengeResponseImplFromJson(
  Map<String, dynamic> json,
) => _$WsChallengeResponseImpl(
  type: json['type'] as String,
  signature: json['signature'] as String,
);

Map<String, dynamic> _$$WsChallengeResponseImplToJson(
  _$WsChallengeResponseImpl instance,
) => <String, dynamic>{'type': instance.type, 'signature': instance.signature};

_$WsRegisteredImpl _$$WsRegisteredImplFromJson(Map<String, dynamic> json) =>
    _$WsRegisteredImpl(
      type: json['type'] as String,
      masterId: json['master_id'] as String?,
      machineId: json['machine_id'] as String?,
    );

Map<String, dynamic> _$$WsRegisteredImplToJson(_$WsRegisteredImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'master_id': instance.masterId,
      'machine_id': instance.machineId,
    };

_$WsSessionInitImpl _$$WsSessionInitImplFromJson(Map<String, dynamic> json) =>
    _$WsSessionInitImpl(
      type: json['type'] as String,
      machineId: json['machine_id'] as String,
      machineToken: json['machine_token'] as String,
      clientEphemeralPub: json['client_ephemeral_pub'] as String,
      signature: json['signature'] as String,
      force: json['force'] as bool? ?? false,
    );

Map<String, dynamic> _$$WsSessionInitImplToJson(_$WsSessionInitImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'machine_id': instance.machineId,
      'machine_token': instance.machineToken,
      'client_ephemeral_pub': instance.clientEphemeralPub,
      'signature': instance.signature,
      'force': instance.force,
    };

_$WsSessionAckImpl _$$WsSessionAckImplFromJson(Map<String, dynamic> json) =>
    _$WsSessionAckImpl(
      type: json['type'] as String,
      machineId: json['machine_id'] as String,
      machineEphemeralPub: json['machine_ephemeral_pub'] as String,
      signature: json['signature'] as String,
    );

Map<String, dynamic> _$$WsSessionAckImplToJson(_$WsSessionAckImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'machine_id': instance.machineId,
      'machine_ephemeral_pub': instance.machineEphemeralPub,
      'signature': instance.signature,
    };

_$WsSessionEndImpl _$$WsSessionEndImplFromJson(Map<String, dynamic> json) =>
    _$WsSessionEndImpl(
      type: json['type'] as String,
      machineId: json['machine_id'] as String,
    );

Map<String, dynamic> _$$WsSessionEndImplToJson(_$WsSessionEndImpl instance) =>
    <String, dynamic>{'type': instance.type, 'machine_id': instance.machineId};

_$WsEncryptedMessageImpl _$$WsEncryptedMessageImplFromJson(
  Map<String, dynamic> json,
) => _$WsEncryptedMessageImpl(
  type: json['type'] as String,
  machineId: json['machine_id'] as String,
  msgId: json['msg_id'] as String,
  nonce: json['nonce'] as String,
  ciphertext: json['ciphertext'] as String,
);

Map<String, dynamic> _$$WsEncryptedMessageImplToJson(
  _$WsEncryptedMessageImpl instance,
) => <String, dynamic>{
  'type': instance.type,
  'machine_id': instance.machineId,
  'msg_id': instance.msgId,
  'nonce': instance.nonce,
  'ciphertext': instance.ciphertext,
};

_$WsErrorMessageImpl _$$WsErrorMessageImplFromJson(Map<String, dynamic> json) =>
    _$WsErrorMessageImpl(
      type: json['type'] as String,
      error: json['error'] as String,
    );

Map<String, dynamic> _$$WsErrorMessageImplToJson(
  _$WsErrorMessageImpl instance,
) => <String, dynamic>{'type': instance.type, 'error': instance.error};

_$WsMachineStatusImpl _$$WsMachineStatusImplFromJson(
  Map<String, dynamic> json,
) => _$WsMachineStatusImpl(
  type: json['type'] as String,
  machineId: json['machine_id'] as String,
  hostname: json['hostname'] as String,
);

Map<String, dynamic> _$$WsMachineStatusImplToJson(
  _$WsMachineStatusImpl instance,
) => <String, dynamic>{
  'type': instance.type,
  'machine_id': instance.machineId,
  'hostname': instance.hostname,
};

_$WsEventImpl _$$WsEventImplFromJson(Map<String, dynamic> json) =>
    _$WsEventImpl(
      type: json['type'] as String,
      payload: json['payload'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$$WsEventImplToJson(_$WsEventImpl instance) =>
    <String, dynamic>{'type': instance.type, 'payload': instance.payload};

_$WsRpcPayloadImpl _$$WsRpcPayloadImplFromJson(Map<String, dynamic> json) =>
    _$WsRpcPayloadImpl(
      method: json['method'] as String,
      params: json['params'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$WsRpcPayloadImplToJson(_$WsRpcPayloadImpl instance) =>
    <String, dynamic>{'method': instance.method, 'params': instance.params};
