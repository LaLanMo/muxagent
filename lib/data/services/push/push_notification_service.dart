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
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('[Push] Notification permission denied');
        return;
      }

      final token = await messaging.getToken();
      if (token == null) {
        debugPrint('[Push] Failed to get FCM token');
        return;
      }

      _currentToken = token;
      await _registerTokenWithAllRelays(token);

      final initialMessage = await messaging.getInitialMessage();
      await _handleNotificationOpen(initialMessage);

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        try {
          _currentToken = newToken;
          await _registerTokenWithAllRelays(newToken);
        } catch (e) {
          debugPrint('[Push] Token refresh registration failed: $e');
        }
      });

      FirebaseMessaging.onMessage.listen((message) async {
        await _showForegroundNotification(message);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) async {
        await _handleNotificationOpen(message);
      });
    } catch (e) {
      debugPrint('[Push] Init failed: $e');
    }
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
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: _nextForegroundNotificationId++,
      title: content.$1,
      body: content.$2,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
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

  Future<void> _registerTokenWithAllRelays(String fcmToken) async {
    try {
      final masterKey = await _crypto.loadMasterKey();
      if (masterKey == null) return;

      final machines = await _machines.listMachines();
      if (machines.isEmpty) return;

      final platform = Platform.isIOS ? 'ios' : 'android';

      // Group machines by relay URL to avoid duplicate registrations
      final relayUrls = <String>{};
      for (final machine in machines) {
        relayUrls.add(machine.relayHttpUrl);
      }

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
        } catch (e) {
          debugPrint('[Push] Failed to register with $relayUrl: $e');
        }
      }
    } catch (e) {
      debugPrint('[Push] Register failed: $e');
    }
  }

  /// Re-register the current token (e.g. after pairing a new machine)
  Future<void> refreshRegistration() async {
    if (_currentToken != null) {
      await _registerTokenWithAllRelays(_currentToken!);
    }
  }
}
