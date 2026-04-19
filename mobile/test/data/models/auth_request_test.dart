import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/models/auth_request.dart';

void main() {
  const parser = AuthRequestPairingLinkParser();

  group('AuthRequestPairingLinkParser', () {
    test('parses a valid muxagent auth link', () {
      final result = parser.parseText(
        'muxagent://auth?id=req-123&relay=https%3A%2F%2Frelay.test',
      );

      expect(result.isSuccess, isTrue);
      expect(result.authRequest?.id, 'req-123');
      expect(result.authRequest?.relayUrl, 'https://relay.test');
    });

    test('rejects non-auth targets', () {
      final result = parser.parseText(
        'muxagent://welcome?id=req-123&relay=https%3A%2F%2Frelay.test',
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, PairingLinkParseFailure.invalidTarget);
    });

    test('rejects links missing required query params', () {
      final result = parser.parseText('muxagent://auth?id=req-123');

      expect(result.isSuccess, isFalse);
      expect(result.failure, PairingLinkParseFailure.missingRelay);
    });
  });
}
