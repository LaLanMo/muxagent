import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../repositories/paired_machine_repository.dart';
import '../../../routing/routes.dart';
import '../api/relay_service.dart';
import '../local/crypto_service.dart';
import '../ws/token_service.dart';

class PushNotificationService {
  final RelayService _relay;
  final TokenService _tokens;
  final CryptoService _crypto;
  final PairedMachineRepository _machines;

  String? _currentToken;
  String? _lastRegisteredToken;
  String? _activeRegistrationToken;
  Future<bool>? _activeRegistrationFuture;

  PushNotificationService({
    required RelayService relay,
    required TokenService tokens,
    required CryptoService crypto,
    required PairedMachineRepository machines,
  }) : _relay = relay,
       _tokens = tokens,
       _crypto = crypto,
       _machines = machines;

  Future<void> init() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      debugPrint(
        '[Push] Notification permission status=${settings.authorizationStatus.name}',
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('[Push] Notification permission denied');
        return;
      }
      await _configureForegroundPresentation(messaging);

      final initialMessage = await messaging.getInitialMessage();
      await _handleNotificationOpen(initialMessage);

      // Listen for token refresh before the initial token fetch so late APNs
      // registration can still complete without another app launch.
      messaging.onTokenRefresh.listen((newToken) async {
        try {
          _currentToken = newToken;
          debugPrint('[Push] Token refresh received ${_maskToken(newToken)}');
          await _registerTokenWithAllRelays(newToken);
        } catch (e) {
          debugPrint('[Push] Token refresh registration failed: $e');
        }
      });

      FirebaseMessaging.onMessage.listen((message) async {
        debugPrint(
          '[Push] Foreground message received event=${message.data['event'] ?? 'unknown'} title=${message.notification?.title ?? ''}',
        );
        debugPrint('[Push] Foreground notification UI suppressed');
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) async {
        debugPrint(
          '[Push] Notification opened event=${message.data['event'] ?? 'unknown'}',
        );
        await _handleNotificationOpen(message);
      });

      final token = await _loadInitialFcmToken(messaging);
      if (token == null) {
        debugPrint('[Push] FCM token unavailable during init');
        return;
      }

      _currentToken = token;
      debugPrint('[Push] Initial FCM token ready ${_maskToken(token)}');
      await _registerTokenWithAllRelays(token);
    } catch (e) {
      debugPrint('[Push] Init failed: $e');
    }
  }

  Future<String?> _loadInitialFcmToken(FirebaseMessaging messaging) async {
    if (!Platform.isIOS) {
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('[Push] Non-iOS FCM token ready ${_maskToken(token)}');
      }
      return token;
    }

    final apnsToken = await _waitForApnsToken(messaging);
    if (apnsToken == null) {
      debugPrint(
        '[Push] APNs token unavailable after waiting; deferring FCM token fetch',
      );
      return null;
    }

    debugPrint('[Push] APNs token ready ${_maskToken(apnsToken)}');
    return messaging.getToken();
  }

  Future<void> _configureForegroundPresentation(
    FirebaseMessaging messaging,
  ) async {
    if (!Platform.isIOS) {
      return;
    }

    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
  }

  Future<String?> _waitForApnsToken(FirebaseMessaging messaging) async {
    String? token = await messaging.getAPNSToken();
    if (token != null && token.isNotEmpty) {
      return token;
    }

    for (var attempt = 0; attempt < 12; attempt++) {
      await Future.delayed(const Duration(milliseconds: 500));
      token = await messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) {
        return token;
      }
    }

    return null;
  }

  Future<void> _handleNotificationOpen(RemoteMessage? message) async {
    if (message == null) return;
    await _navigateToHomeIfPossible();
  }

  Future<void> _navigateToHomeIfPossible() async {
    final machines = await _machines.listMachines();
    if (machines.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute != Routes.home) {
        Get.offAllNamed(Routes.home);
      }
    });
  }

  Future<void> _registerTokenWithAllRelays(
    String fcmToken, {
    bool force = false,
  }) async {
    if (!force && _lastRegisteredToken == fcmToken) {
      debugPrint('[Push] Token already registered ${_maskToken(fcmToken)}');
      return;
    }

    if (!force && _activeRegistrationToken == fcmToken) {
      debugPrint(
        '[Push] Registration already in progress for ${_maskToken(fcmToken)}',
      );
      final pending = _activeRegistrationFuture;
      if (pending != null) {
        await pending;
      }
      return;
    }

    if (force && _activeRegistrationToken == fcmToken) {
      final pending = _activeRegistrationFuture;
      if (pending != null) {
        await pending;
      }
    }

    final registration = _performRelayRegistration(fcmToken);
    _activeRegistrationToken = fcmToken;
    _activeRegistrationFuture = registration;

    try {
      final registeredAnyRelay = await registration;
      if (registeredAnyRelay) {
        _lastRegisteredToken = fcmToken;
      }
    } finally {
      if (identical(_activeRegistrationFuture, registration)) {
        _activeRegistrationFuture = null;
        _activeRegistrationToken = null;
      }
    }
  }

  Future<bool> _performRelayRegistration(String fcmToken) async {
    try {
      final masterKey = await _crypto.loadMasterKey();
      if (masterKey == null) {
        debugPrint('[Push] Relay registration skipped: no master key');
        return false;
      }

      final machines = await _machines.listMachines();
      if (machines.isEmpty) {
        debugPrint(
          '[Push] Relay registration skipped: no paired machines for ${_maskToken(fcmToken)}',
        );
        return false;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';
      debugPrint(
        '[Push] Registering ${_maskToken(fcmToken)} with ${machines.length} machine(s) on $platform',
      );

      // Group machines by relay URL to avoid duplicate registrations
      final relayUrls = <String>{};
      for (final machine in machines) {
        relayUrls.add(machine.relayHttpUrl);
      }

      var registeredAnyRelay = false;
      for (final relayUrl in relayUrls) {
        try {
          final connectToken = await _tokens.buildConnectToken(
            key: masterKey,
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          );
          await _relay.registerDeviceToken(
            relayUrl,
            connectToken,
            fcmToken,
            platform,
          );
          registeredAnyRelay = true;
          debugPrint(
            '[Push] Relay registration succeeded for $relayUrl with ${_maskToken(fcmToken)}',
          );
        } catch (e) {
          debugPrint('[Push] Failed to register with $relayUrl: $e');
        }
      }
      return registeredAnyRelay;
    } catch (e) {
      debugPrint('[Push] Register failed: $e');
      return false;
    }
  }

  /// Re-register the current token (e.g. after pairing a new machine)
  Future<void> refreshRegistration() async {
    if (_currentToken != null) {
      await _registerTokenWithAllRelays(_currentToken!, force: true);
    }
  }

  String _maskToken(String token) {
    if (token.length <= 12) {
      return token;
    }
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }
}
