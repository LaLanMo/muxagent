import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routing/routes.dart';
import '../models/auth_request.dart';

abstract interface class PairingLinkSource {
  Future<Uri?> getInitialUri();
  Stream<Uri> get uriStream;
}

class CompositePairingLinkSource implements PairingLinkSource {
  CompositePairingLinkSource({required List<PairingLinkSource> sources})
    : _sources = List.unmodifiable(sources);

  final List<PairingLinkSource> _sources;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  final List<StreamSubscription<Uri>> _subscriptions = [];

  @override
  Future<Uri?> getInitialUri() async {
    for (final source in _sources) {
      final uri = await source.getInitialUri();
      if (uri != null) {
        return uri;
      }
    }
    return null;
  }

  @override
  Stream<Uri> get uriStream {
    if (_subscriptions.isEmpty) {
      for (final source in _sources) {
        _subscriptions.add(source.uriStream.listen(_controller.add));
      }
    }
    return _controller.stream;
  }
}

class AppLinksPairingLinkSource implements PairingLinkSource {
  AppLinksPairingLinkSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialUri() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get uriStream => _appLinks.uriLinkStream;
}

class NativePreferencePairingLinkSource implements PairingLinkSource {
  NativePreferencePairingLinkSource({
    StringPreferenceStore? preferences,
    Duration pollInterval = const Duration(milliseconds: 300),
    bool? enabled,
  }) : _preferences = preferences,
       _pollInterval = pollInterval,
       _enabled = enabled ?? _defaultEnabled {
    if (_enabled) {
      Timer.periodic(_pollInterval, (_) {
        unawaited(_emitPendingUri());
      });
    }
  }

  static const pendingPairingLinkKey = 'pending_pairing_deeplink_url';

  final StringPreferenceStore? _preferences;
  final Duration _pollInterval;
  final bool _enabled;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  StringPreferenceStore? _preferencesInstance;
  bool _pollInFlight = false;

  static bool get _defaultEnabled => !kIsWeb && Platform.isIOS;

  @override
  Future<Uri?> getInitialUri() => _takePendingUri();

  @override
  Stream<Uri> get uriStream => _controller.stream;

  Future<Uri?> _takePendingUri() async {
    if (!_enabled) {
      return null;
    }

    final preferences = _resolvePreferences();
    final rawUri = await preferences.getString(pendingPairingLinkKey);
    if (rawUri == null || rawUri.isEmpty) {
      return null;
    }

    debugPrint(
      '[NativePreferencePairingLinkSource] consuming pending native link: $rawUri',
    );
    await preferences.remove(pendingPairingLinkKey);
    return Uri.tryParse(rawUri);
  }

  Future<void> _emitPendingUri() async {
    if (_pollInFlight) {
      return;
    }

    _pollInFlight = true;
    try {
      final uri = await _takePendingUri();
      if (uri != null) {
        _controller.add(uri);
      }
    } finally {
      _pollInFlight = false;
    }
  }

  StringPreferenceStore _resolvePreferences() {
    final preferences = _preferences;
    if (preferences != null) {
      return preferences;
    }

    return _preferencesInstance ??= SharedPreferencesAsyncStore();
  }
}

abstract interface class StringPreferenceStore {
  Future<String?> getString(String key);
  Future<void> remove(String key);
}

class SharedPreferencesAsyncStore implements StringPreferenceStore {
  SharedPreferencesAsyncStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

class PairingDeepLinkCoordinator {
  PairingDeepLinkCoordinator({
    required PairingLinkSource source,
    required PairingLinkParser parser,
  }) : _source = source,
       _parser = parser;

  final PairingLinkSource _source;
  final PairingLinkParser _parser;

  StreamSubscription<Uri>? _linkSubscription;
  Timer? _startupObservationTimer;
  AuthRequest? _pendingRequest;
  AuthRequest? _startupRouteRequest;
  String? _pendingRequestKey;
  String? _currentRoute;
  String? _trackedRequestKey;
  bool _navigatorReady = false;
  bool _navigationInFlight = false;
  bool _authRouteOwnedByExternalLink = false;
  bool _startupObservationInProgress = false;
  bool _started = false;
  final ValueNotifier<bool> _welcomeRedirectBlocked = ValueNotifier(false);

  bool get hasPendingPairingNavigation =>
      _pendingRequest != null ||
      _startupRouteRequest != null ||
      _navigationInFlight;
  bool get isBlockingWelcomeRedirect => _welcomeRedirectBlocked.value;
  ValueListenable<bool> get welcomeRedirectBlockedListenable =>
      _welcomeRedirectBlocked;
  AuthRequest? get currentPendingRequest => _pendingRequest;

  bool prepareStartupRoute() {
    if (_navigatorReady ||
        _pendingRequest == null ||
        _pendingRequestKey == null) {
      return false;
    }

    _startupRouteRequest = _pendingRequest;
    _trackedRequestKey = _pendingRequestKey;
    _pendingRequest = null;
    _pendingRequestKey = null;
    _navigationInFlight = false;
    _authRouteOwnedByExternalLink = true;
    _syncWelcomeRedirectBlocked();
    return true;
  }

  AuthRequest? consumeStartupRouteRequest() {
    final request = _startupRouteRequest;
    _startupRouteRequest = null;
    _syncWelcomeRedirectBlocked();
    return request;
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    debugPrint('[PairingDeepLinkCoordinator] start()');

    final initialUri = await _source.getInitialUri();
    if (initialUri != null) {
      debugPrint(
        '[PairingDeepLinkCoordinator] received initial URI from source: $initialUri',
      );
      _acceptUri(initialUri);
    }

    _linkSubscription = _source.uriStream.listen(_acceptUri);
    _beginStartupObservationWindow();
  }

  void onNavigatorReady() {
    _navigatorReady = true;
    debugPrint('[PairingDeepLinkCoordinator] navigator ready');
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      _navigatePendingIfPossible();
    });
  }

  void onRouteChanged(String? route) {
    _currentRoute = _normalizeObservedRoute(route);
    if (_currentRoute == Routes.auth) {
      _navigationInFlight = false;
      _authRouteOwnedByExternalLink = _trackedRequestKey != null;
      _syncWelcomeRedirectBlocked();
      return;
    }

    if (_authRouteOwnedByExternalLink) {
      _authRouteOwnedByExternalLink = false;
      _trackedRequestKey = null;
    }

    _syncWelcomeRedirectBlocked();
    _navigatePendingIfPossible();
  }

  Future<void> dispose() async {
    _startupObservationTimer?.cancel();
    _startupObservationInProgress = false;
    _syncWelcomeRedirectBlocked();
    await _linkSubscription?.cancel();
  }

  void _acceptUri(Uri uri) {
    final result = _parser.parseUri(uri);
    if (!result.isSuccess) {
      debugPrint('[PairingDeepLinkCoordinator] ignoring invalid link: $uri');
      return;
    }

    final request = result.authRequest!;
    final requestKey = _requestKeyFor(request);
    if (_shouldIgnoreRequest(requestKey)) {
      return;
    }

    _pendingRequest = request;
    _pendingRequestKey = requestKey;
    _trackedRequestKey = requestKey;
    _authRouteOwnedByExternalLink = false;
    _syncWelcomeRedirectBlocked();
    debugPrint(
      '[PairingDeepLinkCoordinator] accepted request $requestKey, navigatorReady=$_navigatorReady',
    );
    _navigatePendingIfPossible();
  }

  void _navigatePendingIfPossible() {
    if (!_navigatorReady ||
        _pendingRequest == null ||
        Get.key.currentState == null ||
        _currentRoute == null) {
      debugPrint(
        '[PairingDeepLinkCoordinator] navigation deferred '
        'navigatorReady=$_navigatorReady pending=${_pendingRequest != null} '
        'navigatorState=${Get.key.currentState != null} '
        'currentRoute=$_currentRoute',
      );
      return;
    }

    final request = _pendingRequest!;
    final requestKey = _pendingRequestKey!;
    _pendingRequest = null;
    _pendingRequestKey = null;
    _navigationInFlight = true;
    _trackedRequestKey = requestKey;
    _syncWelcomeRedirectBlocked();
    debugPrint(
      '[PairingDeepLinkCoordinator] navigating to auth for request $requestKey',
    );

    Get.offAllNamed(Routes.auth, arguments: request);
  }

  String _requestKeyFor(AuthRequest request) {
    return '${request.id}|${request.relayUrl}';
  }

  void _beginStartupObservationWindow() {
    if (!NativePreferencePairingLinkSource._defaultEnabled) {
      _startupObservationInProgress = false;
      return;
    }

    _startupObservationInProgress = true;
    _syncWelcomeRedirectBlocked();
    _startupObservationTimer?.cancel();
    _startupObservationTimer = Timer(const Duration(seconds: 2), () {
      _startupObservationInProgress = false;
      _syncWelcomeRedirectBlocked();
    });
  }

  void _syncWelcomeRedirectBlocked() {
    final next =
        _startupObservationInProgress ||
        _pendingRequest != null ||
        _startupRouteRequest != null ||
        _navigationInFlight ||
        _authRouteOwnedByExternalLink;
    if (_welcomeRedirectBlocked.value != next) {
      _welcomeRedirectBlocked.value = next;
    }
  }

  bool _shouldIgnoreRequest(String requestKey) {
    if (_trackedRequestKey != requestKey) {
      return false;
    }

    return _pendingRequestKey == requestKey ||
        _startupRouteRequest != null ||
        _navigationInFlight ||
        _authRouteOwnedByExternalLink ||
        _currentRoute == Routes.auth;
  }

  @visibleForTesting
  String? debugNormalizeObservedRoute(String? route) =>
      _normalizeObservedRoute(route);

  String? _normalizeObservedRoute(String? route) {
    if (route == null || route.isEmpty) {
      return route;
    }

    if (route == Routes.auth) {
      return route;
    }

    final routeUri = Uri.tryParse(route);
    if (routeUri == null) {
      return route;
    }

    if (routeUri.path == Routes.auth) {
      return Routes.auth;
    }

    if (routeUri.path == Routes.home && routeUri.hasQuery) {
      final deepLinkUri = Uri(
        scheme: 'muxagent',
        host: 'auth',
        queryParameters: routeUri.queryParameters,
      );
      if (_parser.parseUri(deepLinkUri).isSuccess) {
        return Routes.auth;
      }
    }

    return route;
  }
}
