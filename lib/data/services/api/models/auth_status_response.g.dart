// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_status_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AuthStatusResponseImpl _$$AuthStatusResponseImplFromJson(
  Map<String, dynamic> json,
) => _$AuthStatusResponseImpl(
  state: json['state'] as String,
  requestId: json['request_id'] as String?,
  machineId: json['machine_id'] as String?,
  machineSignPub: json['machine_sign_pub'] as String?,
  machineEncPub: json['machine_enc_pub'] as String?,
  machineHostname: json['machine_hostname'] as String?,
  relayChallenge: json['relay_challenge'] as String?,
  expiresAt: (json['expires_at'] as num?)?.toInt(),
  approvedAt: (json['approved_at'] as num?)?.toInt(),
  approvedByMasterSignKeyFingerprint:
      json['approved_by_master_sign_key_fingerprint'] as String?,
  approvalSignature: json['approval_signature'] as String?,
  masterId: json['master_id'] as String?,
  keyring: json['keyring'] == null
      ? null
      : KeyringState.fromJson(json['keyring'] as Map<String, dynamic>),
  relayPubKey: json['relay_pub_key'] as String?,
  relaySignature: json['relay_signature'] as String?,
);

Map<String, dynamic> _$$AuthStatusResponseImplToJson(
  _$AuthStatusResponseImpl instance,
) => <String, dynamic>{
  'state': instance.state,
  'request_id': instance.requestId,
  'machine_id': instance.machineId,
  'machine_sign_pub': instance.machineSignPub,
  'machine_enc_pub': instance.machineEncPub,
  'machine_hostname': instance.machineHostname,
  'relay_challenge': instance.relayChallenge,
  'expires_at': instance.expiresAt,
  'approved_at': instance.approvedAt,
  'approved_by_master_sign_key_fingerprint':
      instance.approvedByMasterSignKeyFingerprint,
  'approval_signature': instance.approvalSignature,
  'master_id': instance.masterId,
  'keyring': instance.keyring?.toJson(),
  'relay_pub_key': instance.relayPubKey,
  'relay_signature': instance.relaySignature,
};

_$KeyringStateImpl _$$KeyringStateImplFromJson(Map<String, dynamic> json) =>
    _$KeyringStateImpl(
      masterId: json['master_id'] as String,
      seq: (json['seq'] as num).toInt(),
      headHash: json['head_hash'] as String,
      keys: (json['keys'] as List<dynamic>)
          .map((e) => MasterKeyInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$KeyringStateImplToJson(_$KeyringStateImpl instance) =>
    <String, dynamic>{
      'master_id': instance.masterId,
      'seq': instance.seq,
      'head_hash': instance.headHash,
      'keys': instance.keys.map((e) => e.toJson()).toList(),
    };

_$MasterKeyInfoImpl _$$MasterKeyInfoImplFromJson(Map<String, dynamic> json) =>
    _$MasterKeyInfoImpl(
      masterSignKeyFingerprint: json['master_sign_key_fingerprint'] as String,
      masterSignPub: json['master_sign_pub'] as String,
      masterEncPub: json['master_enc_pub'] as String,
      revokedAt: (json['revoked_at'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$MasterKeyInfoImplToJson(_$MasterKeyInfoImpl instance) =>
    <String, dynamic>{
      'master_sign_key_fingerprint': instance.masterSignKeyFingerprint,
      'master_sign_pub': instance.masterSignPub,
      'master_enc_pub': instance.masterEncPub,
      'revoked_at': instance.revokedAt,
    };
