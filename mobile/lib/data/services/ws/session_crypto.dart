import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const _sessionInfo = 'muxagent-session-v1';
const _aadPrefix = 'muxagent-aad-v1';

class EncryptedPayload {
  final String nonceB64;
  final String ciphertextB64;

  EncryptedPayload({required this.nonceB64, required this.ciphertextB64});
}

class SessionCrypto {
  final String machineId;
  final SecretKey _key;
  final Xchacha20 _aead = Xchacha20.poly1305Aead();

  SessionCrypto({required this.machineId, required SecretKey key}) : _key = key;

  static Future<SecretKey> deriveSessionKey(
    Uint8List sharedSecret,
    String transcript,
  ) async {
    final salt = await Sha256().hash(utf8.encode(transcript));
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    return hkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      nonce: salt.bytes,
      info: utf8.encode(_sessionInfo),
    );
  }

  Future<EncryptedPayload> encrypt(
    String msgType,
    String msgId,
    Uint8List plaintext,
  ) async {
    final nonce = _randomBytes(_aead.nonceLength);
    final aad = utf8.encode(_buildAad(machineId, msgType, msgId));
    final secretBox = await _aead.encrypt(
      plaintext,
      secretKey: _key,
      nonce: nonce,
      aad: aad,
    );
    final cipherWithMac = secretBox.concatenation(nonce: false);
    return EncryptedPayload(
      nonceB64: base64Encode(secretBox.nonce),
      ciphertextB64: base64Encode(cipherWithMac),
    );
  }

  Future<Uint8List> decrypt(
    String msgType,
    String msgId,
    String nonceB64,
    String ciphertextB64,
  ) async {
    final nonce = base64Decode(nonceB64);
    final ciphertext = base64Decode(ciphertextB64);
    final aad = utf8.encode(_buildAad(machineId, msgType, msgId));
    final macLength = _aead.macAlgorithm.macLength;
    if (ciphertext.length < macLength) {
      throw ArgumentError('ciphertext too short');
    }
    final cipherText = ciphertext.sublist(0, ciphertext.length - macLength);
    final macBytes = ciphertext.sublist(ciphertext.length - macLength);
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    final decrypted = await _aead.decrypt(
      secretBox,
      secretKey: _key,
      aad: aad,
    );
    return Uint8List.fromList(decrypted);
  }

  String _buildAad(String machineId, String msgType, String msgId) {
    return '$_aadPrefix|$machineId|$msgType|$msgId';
  }

  Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rand.nextInt(256);
    }
    return bytes;
  }
}
