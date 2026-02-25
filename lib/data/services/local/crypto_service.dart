import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../domain/master_key.dart';

class CryptoService {
  static const _masterId = 'master_id';
  static const _masterSignPublicKey = 'master_sign_public_key';
  static const _masterSignPrivateKey = 'master_sign_private_key';
  static const _masterEncPublicKey = 'master_enc_public_key';
  static const _masterEncPrivateKey = 'master_enc_private_key';

  final FlutterSecureStorage _storage;
  final Ed25519 _ed25519 = Ed25519();
  final X25519 _x25519 = X25519();
  final Sha256 _sha256 = Sha256();

  MasterKey? _cachedKey;

  CryptoService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Generate a new master identity (sign + enc keys)
  Future<MasterKey> generateMasterKey() async {
    final masterId = _generateUuidV4();

    final signKeyPair = await _ed25519.newKeyPair();
    final signPublicKey = await signKeyPair.extractPublicKey();
    final signPrivateKeyBytes = await signKeyPair.extractPrivateKeyBytes();

    final encKeyPair = await _x25519.newKeyPair();
    final encPublicKey = await encKeyPair.extractPublicKey();
    final encPrivateKeyBytes = await encKeyPair.extractPrivateKeyBytes();

    final masterKey = MasterKey(
      id: masterId,
      signPublicKey: Uint8List.fromList(signPublicKey.bytes),
      signPrivateKey: Uint8List.fromList(signPrivateKeyBytes),
      encPublicKey: Uint8List.fromList(encPublicKey.bytes),
      encPrivateKey: Uint8List.fromList(encPrivateKeyBytes),
    );

    await _saveMasterKey(masterKey);
    _cachedKey = masterKey;

    return masterKey;
  }

  /// Load existing master key from secure storage
  Future<MasterKey?> loadMasterKey() async {
    if (_cachedKey != null) return _cachedKey;

    final masterId = await _storage.read(key: _masterId);
    final signPublicKey = await _storage.read(key: _masterSignPublicKey);
    final signPrivateKey = await _storage.read(key: _masterSignPrivateKey);
    final encPublicKey = await _storage.read(key: _masterEncPublicKey);
    final encPrivateKey = await _storage.read(key: _masterEncPrivateKey);

    if (masterId == null ||
        signPublicKey == null ||
        signPrivateKey == null ||
        encPublicKey == null ||
        encPrivateKey == null) {
      return null;
    }

    _cachedKey = MasterKey.fromBase64(
      id: masterId,
      signPublicKey: signPublicKey,
      signPrivateKey: signPrivateKey,
      encPublicKey: encPublicKey,
      encPrivateKey: encPrivateKey,
    );

    return _cachedKey;
  }

  /// Get or create master key
  Future<MasterKey> getOrCreateMasterKey() async {
    final existing = await loadMasterKey();
    if (existing != null) return existing;
    return generateMasterKey();
  }

  Future<void> _saveMasterKey(MasterKey key) async {
    await _storage.write(key: _masterId, value: key.id);
    await _storage.write(
      key: _masterSignPublicKey,
      value: key.signPublicKeyBase64,
    );
    await _storage.write(
      key: _masterSignPrivateKey,
      value: key.signPrivateKeyBase64,
    );
    await _storage.write(
      key: _masterEncPublicKey,
      value: key.encPublicKeyBase64,
    );
    await _storage.write(
      key: _masterEncPrivateKey,
      value: key.encPrivateKeyBase64,
    );
  }

  /// Clear stored keys (for testing/reset)
  Future<void> clearKeys() async {
    await _storage.delete(key: _masterId);
    await _storage.delete(key: _masterSignPublicKey);
    await _storage.delete(key: _masterSignPrivateKey);
    await _storage.delete(key: _masterEncPublicKey);
    await _storage.delete(key: _masterEncPrivateKey);
    _cachedKey = null;
  }

  /// Check if master key exists
  Future<bool> hasMasterKey() async {
    final key = await loadMasterKey();
    return key != null;
  }

  /// Sign a UTF-8 message with the master signing key.
  Future<String> signMessage(String message, MasterKey key) async {
    final keyPair = SimpleKeyPairData(
      key.signPrivateKey,
      publicKey: SimplePublicKey(key.signPublicKey, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );
    final signature = await _ed25519.sign(
      utf8.encode(message),
      keyPair: keyPair,
    );
    return base64Encode(signature.bytes);
  }

  /// Compute the key id (SHA-256 base64url without padding).
  Future<String> computeKeyId(Uint8List publicKey) async {
    final digest = await _sha256.hash(publicKey);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String toHex(int value) => value.toRadixString(16).padLeft(2, '0');
    final hex = bytes.map(toHex).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
