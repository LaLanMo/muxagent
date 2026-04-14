class AuthRequest {
  final String id;
  final String relayUrl;
  final DateTime scannedAt;

  AuthRequest({
    required this.id,
    required this.relayUrl,
    DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();

  factory AuthRequest.fromQrUrl(String qrUrl) {
    // Parse: muxagent://auth?id=xxx&relay=yyy
    final uri = Uri.parse(qrUrl);
    final id = uri.queryParameters['id'] ?? '';
    final relay = uri.queryParameters['relay'] ?? '';

    return AuthRequest(id: id, relayUrl: relay);
  }

  bool get isValid => id.isNotEmpty && relayUrl.isNotEmpty;
}
