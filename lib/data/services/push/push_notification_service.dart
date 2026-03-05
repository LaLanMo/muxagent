import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../repositories/paired_machine_repository.dart';
import '../api/relay_service.dart';
import '../local/crypto_service.dart';
import '../ws/token_service.dart';

class PushNotificationService {
  final RelayService _relay;
  final TokenService _tokens;
  final CryptoService _crypto;
  final PairedMachineRepository _machines;

  String? _currentToken;

  PushNotificationService({
    required RelayService relay,
    required TokenService tokens,
    required CryptoService crypto,
    required PairedMachineRepository machines,
  })  : _relay = relay,
        _tokens = tokens,
        _crypto = crypto,
        _machines = machines;

  Future<void> init() async {
    try {
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

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        try {
          _currentToken = newToken;
          await _registerTokenWithAllRelays(newToken);
        } catch (e) {
          debugPrint('[Push] Token refresh registration failed: $e');
        }
      });

      // Foreground messages: ignore (WS handles real-time delivery)
      FirebaseMessaging.onMessage.listen((_) {});
    } catch (e) {
      debugPrint('[Push] Init failed: $e');
    }
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
