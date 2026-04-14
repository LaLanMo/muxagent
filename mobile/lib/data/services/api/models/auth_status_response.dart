import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_status_response.freezed.dart';
part 'auth_status_response.g.dart';

@freezed
class AuthStatusResponse with _$AuthStatusResponse {
  const factory AuthStatusResponse({
    required String state,
    String? requestId,
    String? machineId,
    String? machineSignPub,
    String? machineEncPub,
    String? machineHostname,
    String? relayChallenge,
    int? expiresAt,
    int? approvedAt,
    String? approvedByMasterSignKeyFingerprint,
    String? approvalSignature,
    String? masterId,
    KeyringState? keyring,
    String? relayPubKey,
    String? relaySignature,
  }) = _AuthStatusResponse;

  const AuthStatusResponse._();

  factory AuthStatusResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthStatusResponseFromJson(json);

  bool get isPending => state == 'pending';
  bool get isApproved => state == 'approved';
  bool get isExpired => state == 'expired';
}

@freezed
class KeyringState with _$KeyringState {
  const factory KeyringState({
    required String masterId,
    required int seq,
    required String headHash,
    required List<MasterKeyInfo> keys,
  }) = _KeyringState;

  const KeyringState._();

  factory KeyringState.fromJson(Map<String, dynamic> json) =>
      _$KeyringStateFromJson(json);
}

@freezed
class MasterKeyInfo with _$MasterKeyInfo {
  const factory MasterKeyInfo({
    required String masterSignKeyFingerprint,
    required String masterSignPub,
    required String masterEncPub,
    int? revokedAt,
  }) = _MasterKeyInfo;

  const MasterKeyInfo._();

  factory MasterKeyInfo.fromJson(Map<String, dynamic> json) =>
      _$MasterKeyInfoFromJson(json);
}
