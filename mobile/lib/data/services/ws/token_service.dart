import 'dart:convert';
import '../../../domain/master_key.dart';
import '../local/crypto_service.dart';

class TokenService {
  final CryptoService _crypto;

  TokenService({required CryptoService crypto}) : _crypto = crypto;

  Future<String> buildConnectToken({
    required MasterKey key,
    required DateTime expiresAt,
  }) async {
    final fingerprint = await _crypto.computeKeyId(key.signPublicKey);
    final payload =
        'muxagent-connect-token-v1|${key.id}|$fingerprint|${_toUnix(expiresAt)}';
    return _signToken(payload, key);
  }

  Future<String> buildMachineToken({
    required MasterKey key,
    required String machineId,
    required DateTime expiresAt,
  }) async {
    final fingerprint = await _crypto.computeKeyId(key.signPublicKey);
    final payload =
        'muxagent-machine-token-v1|${key.id}|$machineId|$fingerprint|${_toUnix(expiresAt)}';
    return _signToken(payload, key);
  }

  Future<String> _signToken(String payload, MasterKey key) async {
    final signatureB64 = await _crypto.signMessage(payload, key);
    final payloadBytes = utf8.encode(payload);
    final signatureBytes = base64Decode(signatureB64);
    final payloadEnc = base64UrlEncode(payloadBytes).replaceAll('=', '');
    final sigEnc = base64UrlEncode(signatureBytes).replaceAll('=', '');
    return '$payloadEnc.$sigEnc';
  }

  int _toUnix(DateTime time) => time.toUtc().millisecondsSinceEpoch ~/ 1000;
}
