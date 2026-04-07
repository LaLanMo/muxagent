import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../../repositories/paired_machine_repository.dart';
import '../../../routing/routes.dart';
import '../api/relay_service.dart';
import '../local/crypto_service.dart';
import '../ws/token_service.dart';

class PushNotificationService {
  static const AndroidNotificationChannel _foregroundChannel =
      AndroidNotificationChannel(
        'muxagent_foreground_updates',
        'Foreground Agent Updates',
        description: 'Important agent updates while the app is open',
        importance: Importance.high,
      );

  final RelayService _relay;
  final TokenService _tokens;
  final CryptoService _crypto;
  final PairedMachineRepository _machines;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _currentToken;
  String? _lastRegisteredToken;
  String? _activeRegistrationToken;
  Future<bool>? _activeRegistrationFuture;
  bool _localNotificationsReady = false;
  int _nextForegroundNotificationId = 1;

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
      await _initLocalNotifications();
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
        if (_shouldPresentForegroundWithSystemUi(message)) {
          debugPrint(
            '[Push] iOS system UI will present this foreground notification',
          );
          return;
        }
        await _showForegroundNotification(message);
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
      alert: true,
      badge: true,
      sound: true,
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

  Future<void> _handleLocalNotificationOpen(String? payload) async {
    if (payload == null || payload.isEmpty) return;
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

  Future<void> _initLocalNotifications() async {
    if (_localNotificationsReady) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        await _handleLocalNotificationOpen(response.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_foregroundChannel);

    _localNotificationsReady = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsReady) return;

    final content = _notificationContent(message);
    if (content.$1.isEmpty && content.$2.isEmpty) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _foregroundChannel.id,
        _foregroundChannel.name,
        channelDescription: _foregroundChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
      iOS: const DarwinNotificationDetails(
        presentBanner: true,
        presentList: true,
        presentSound: true,
        presentBadge: true,
      ),
    );

    await _localNotifications.show(
      id: _nextForegroundNotificationId++,
      title: content.$1,
      body: content.$2,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  bool _shouldPresentForegroundWithSystemUi(RemoteMessage message) {
    return Platform.isIOS && message.notification != null;
  }

  (String, String) _notificationContent(RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title != null && title.isNotEmpty && body != null && body.isNotEmpty) {
      return (title, body);
    }

    return switch (message.data['event']) {
      'approval.requested' => (
        'Approval Needed',
        'An agent is waiting for your approval',
      ),
      'run.failed' => ('Run Failed', 'An agent run has failed'),
      'run.finished' => ('Run Completed', 'An agent run has completed'),
      _ => ('Agent Update', 'Your agent has an update'),
    };
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
