import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../models/auth_request.dart';
import '../../../routing/routes.dart';

typedef AuthLinkHandler = void Function(AuthRequest request);

abstract class AppLinkSource {
  Future<Uri?> getInitialLink();

  Stream<Uri> get uriLinkStream;
}

class PlatformAppLinkSource implements AppLinkSource {
  PlatformAppLinkSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}

class AuthDeepLinkService extends GetxService {
  AuthDeepLinkService({
    AppLinkSource? linkSource,
    AuthLinkHandler? onAuthRequest,
  }) : _linkSource = linkSource ?? PlatformAppLinkSource(),
       _onAuthRequest = onAuthRequest ?? _navigateToAuthRequest;

  final AppLinkSource _linkSource;
  final AuthLinkHandler _onAuthRequest;

  StreamSubscription<Uri>? _linkSubscription;
  String? _lastHandledLink;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _handleLink(await _linkSource.getInitialLink());
    _linkSubscription = _linkSource.uriLinkStream.listen(
      (uri) => unawaited(_handleLink(uri)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[AuthDeepLink] stream error: $error');
      },
    );
  }

  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }

  Future<void> _handleLink(Uri? uri) async {
    if (uri == null || !_isAuthUri(uri)) {
      return;
    }

    final request = AuthRequest.fromQrUrl(uri.toString());
    if (!request.isValid) {
      debugPrint('[AuthDeepLink] ignored invalid auth link: $uri');
      return;
    }

    final raw = uri.toString();
    if (_lastHandledLink == raw) {
      return;
    }
    _lastHandledLink = raw;
    _onAuthRequest(request);
  }

  bool _isAuthUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return uri.scheme.toLowerCase() == 'muxagent' &&
        (host == 'auth' || path == '/auth' || path == 'auth');
  }

  static void _navigateToAuthRequest(AuthRequest request) {
    void navigate() {
      if (Get.currentRoute == Routes.auth) {
        Get.offNamed(Routes.auth, arguments: request);
        return;
      }
      Get.toNamed(Routes.auth, arguments: request);
    }

    if (Get.key.currentState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => navigate());
      return;
    }

    navigate();
  }
}
