import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

import '../../domain/master_key.dart';
import '../../domain/paired_machine.dart';
import '../models/auth_request.dart';
import '../services/push/push_notification_service.dart';
import 'paired_machine_repository.dart';
import '../services/api/relay_service.dart';
import '../services/local/crypto_service.dart';

class AuthRepository {
  final RelayService _api;
  final CryptoService _crypto;
  final PairedMachineRepository _machines;

  AuthRepository({
    required RelayService api,
    required CryptoService crypto,
    required PairedMachineRepository machines,
  }) : _api = api,
       _crypto = crypto,
       _machines = machines;

  /// Check if auth request is still pending
  Future<AuthStatusResponse> checkStatus(AuthRequest request) async {
    return _api.getAuthStatus(request.relayUrl, request.id);
  }

  /// Approve an auth request - sends our master public key to the relay
  Future<void> approve(AuthRequest request) async {
    debugPrint('[AuthRepo] approve start request=${request.id}');
    final masterKey = await _crypto.getOrCreateMasterKey();
    debugPrint('[AuthRepo] master key ready id=${masterKey.id}');
    final status = await _api.getAuthStatus(request.relayUrl, request.id);
    debugPrint(
      '[AuthRepo] auth status loaded machineId=${status.machineId} hostname=${status.machineHostname}',
    );

    if (status.machineSignPub == null ||
        status.machineEncPub == null ||
        status.relayChallenge == null ||
        status.expiresAt == null ||
        status.machineId == null) {
      throw Exception('Auth request missing required fields');
    }

    final approvalMessage = _buildApprovalMessage(
      request.id,
      status.machineSignPub!,
      status.machineEncPub!,
      status.relayChallenge!,
      status.expiresAt!,
    );

    final approvalSignature = await _crypto.signMessage(
      approvalMessage,
      masterKey,
    );
    debugPrint('[AuthRepo] approval signature ready');
    final signerMasterSignKeyFingerprint = await _crypto.computeKeyId(
      masterKey.signPublicKey,
    );

    final keyringUpdate = _buildKeyringUpdate(
      masterKey,
      signerMasterSignKeyFingerprint,
    );
    final keyringSignature = await _crypto.signMessage(
      keyringUpdate['message'] as String,
      masterKey,
    );
    debugPrint('[AuthRepo] keyring signature ready');

    await _api.approveAuthRequest(
      request.relayUrl,
      request.id,
      masterId: masterKey.id,
      masterSignPub: masterKey.signPublicKeyBase64,
      masterEncPub: masterKey.encPublicKeyBase64,
      approvalSignature: approvalSignature,
      keyringUpdate: {
        'master_id': masterKey.id,
        'seq': keyringUpdate['seq'],
        'prev_hash': keyringUpdate['prev_hash'],
        'action': keyringUpdate['action'],
        'target_master_sign_pub': masterKey.signPublicKeyBase64,
        'target_master_enc_pub': masterKey.encPublicKeyBase64,
        'signer_master_sign_key_fingerprint': signerMasterSignKeyFingerprint,
        'signature': keyringSignature,
      },
    );
    debugPrint('[AuthRepo] relay approve request completed');

    await _machines.saveMachine(
      PairedMachine(
        machineId: status.machineId!,
        relayHttpUrl: request.relayUrl,
        machineSignPubB64: status.machineSignPub!,
        machineEncPubB64: status.machineEncPub!,
        hostname: status.machineHostname,
      ),
    );
    debugPrint('[AuthRepo] paired machine saved machineId=${status.machineId}');

    // Register push token with the new machine's relay.
    try {
      await Get.find<PushNotificationService>().refreshRegistration();
    } catch (_) {}
  }

  String _buildApprovalMessage(
    String requestId,
    String machineSignPub,
    String machineEncPub,
    String relayChallenge,
    int expiresAt,
  ) {
    return 'muxagent-approve-v1|$requestId|$machineSignPub|$machineEncPub|$relayChallenge|$expiresAt';
  }

  Map<String, dynamic> _buildKeyringUpdate(
    MasterKey masterKey,
    String signerMasterSignKeyFingerprint,
  ) {
    const seq = 1;
    const prevHash = '';
    const action = 'add';
    final message =
        'muxagent-keyring-update-v1|${masterKey.id}|$seq|$prevHash|$action|${masterKey.signPublicKeyBase64}|${masterKey.encPublicKeyBase64}|$signerMasterSignKeyFingerprint';
    return {
      'seq': seq,
      'prev_hash': prevHash,
      'action': action,
      'message': message,
    };
  }
}
