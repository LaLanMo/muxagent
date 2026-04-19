import 'package:muxagent/data/models/auth_request.dart';
import 'package:muxagent/data/services/pairing_deep_link_coordinator.dart';

class _NoopPairingLinkSource implements PairingLinkSource {
  @override
  Future<Uri?> getInitialUri() async => null;

  @override
  Stream<Uri> get uriStream => const Stream.empty();
}

class FakePairingDeepLinkCoordinator extends PairingDeepLinkCoordinator {
  FakePairingDeepLinkCoordinator({required this.blockingWelcomeRedirect})
    : super(
        source: _NoopPairingLinkSource(),
        parser: const AuthRequestPairingLinkParser(),
      );

  bool blockingWelcomeRedirect;

  @override
  bool get isBlockingWelcomeRedirect => blockingWelcomeRedirect;
}
