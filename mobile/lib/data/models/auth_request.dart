class AuthRequest {
  final String id;
  final String relayUrl;
  final DateTime scannedAt;

  AuthRequest({required this.id, required this.relayUrl, DateTime? scannedAt})
    : scannedAt = scannedAt ?? DateTime.now();

  factory AuthRequest.fromQrUrl(String qrUrl) {
    final result = const AuthRequestPairingLinkParser().parseText(qrUrl);
    return result.authRequest ?? AuthRequest(id: '', relayUrl: '');
  }

  bool get isValid => id.isNotEmpty && relayUrl.isNotEmpty;
}

enum PairingLinkParseFailure {
  emptyInput,
  malformedUri,
  invalidScheme,
  invalidTarget,
  missingId,
  missingRelay,
}

class PairingLinkParseResult {
  final AuthRequest? authRequest;
  final PairingLinkParseFailure? failure;

  const PairingLinkParseResult._({this.authRequest, this.failure});

  const PairingLinkParseResult.success(AuthRequest authRequest)
    : this._(authRequest: authRequest);

  const PairingLinkParseResult.failure(PairingLinkParseFailure failure)
    : this._(failure: failure);

  bool get isSuccess => authRequest != null;
}

abstract interface class PairingLinkParser {
  PairingLinkParseResult parseText(String rawValue);
  PairingLinkParseResult parseUri(Uri uri);
}

class AuthRequestPairingLinkParser implements PairingLinkParser {
  const AuthRequestPairingLinkParser();

  @override
  PairingLinkParseResult parseText(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return const PairingLinkParseResult.failure(
        PairingLinkParseFailure.emptyInput,
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return const PairingLinkParseResult.failure(
        PairingLinkParseFailure.malformedUri,
      );
    }

    return parseUri(uri);
  }

  @override
  PairingLinkParseResult parseUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'muxagent') {
      return const PairingLinkParseResult.failure(
        PairingLinkParseFailure.invalidScheme,
      );
    }

    if (!_isAuthTarget(uri)) {
      return const PairingLinkParseResult.failure(
        PairingLinkParseFailure.invalidTarget,
      );
    }

    final id = uri.queryParameters['id']?.trim() ?? '';
    if (id.isEmpty) {
      return const PairingLinkParseResult.failure(
        PairingLinkParseFailure.missingId,
      );
    }

    final relay = uri.queryParameters['relay']?.trim() ?? '';
    if (relay.isEmpty) {
      return const PairingLinkParseResult.failure(
        PairingLinkParseFailure.missingRelay,
      );
    }

    return PairingLinkParseResult.success(AuthRequest(id: id, relayUrl: relay));
  }

  bool _isAuthTarget(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return (host == 'auth' && (path.isEmpty || path == '/')) ||
        (host.isEmpty && path == '/auth');
  }
}
