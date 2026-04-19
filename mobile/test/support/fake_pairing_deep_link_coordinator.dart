import 'package:flutter/foundation.dart';
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
    : _blockingNotifier = ValueNotifier(blockingWelcomeRedirect),
      super(
        source: _NoopPairingLinkSource(),
        parser: const AuthRequestPairingLinkParser(),
      );

  final ValueNotifier<bool> _blockingNotifier;

  bool blockingWelcomeRedirect;

  @override
  bool get isBlockingWelcomeRedirect => _blockingNotifier.value;

  @override
  ValueListenable<bool> get welcomeRedirectBlockedListenable =>
      _blockingNotifier;

  void setBlockingWelcomeRedirect(bool value) {
    blockingWelcomeRedirect = value;
    _blockingNotifier.value = value;
  }

  @override
  Future<void> dispose() async {
    _blockingNotifier.dispose();
  }
}
