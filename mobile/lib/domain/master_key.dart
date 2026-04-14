import 'dart:convert';
import 'dart:typed_data';

class MasterKey {
  final String id;
  final Uint8List signPublicKey;
  final Uint8List signPrivateKey;
  final Uint8List encPublicKey;
  final Uint8List encPrivateKey;

  MasterKey({
    required this.id,
    required this.signPublicKey,
    required this.signPrivateKey,
    required this.encPublicKey,
    required this.encPrivateKey,
  });

  String get signPublicKeyBase64 => base64Encode(signPublicKey);
  String get signPrivateKeyBase64 => base64Encode(signPrivateKey);
  String get encPublicKeyBase64 => base64Encode(encPublicKey);
  String get encPrivateKeyBase64 => base64Encode(encPrivateKey);

  factory MasterKey.fromBase64({
    required String id,
    required String signPublicKey,
    required String signPrivateKey,
    required String encPublicKey,
    required String encPrivateKey,
  }) {
    return MasterKey(
      id: id,
      signPublicKey: base64Decode(signPublicKey),
      signPrivateKey: base64Decode(signPrivateKey),
      encPublicKey: base64Decode(encPublicKey),
      encPrivateKey: base64Decode(encPrivateKey),
    );
  }
}
