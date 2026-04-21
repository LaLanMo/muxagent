import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'bindings/initial_binding.dart';
import 'config/constant.dart';
import 'config/firebase.dart';
import 'config/theme.dart';
import 'data/repositories/event_repository.dart';
import 'data/repositories/language_preference_repository.dart';
import 'data/repositories/session_chat_cache_repository.dart';
import 'data/services/pairing_deep_link_coordinator.dart';
import 'data/services/push/push_notification_service.dart';
import 'i18n/app_locales.dart';
import 'i18n/app_translations.dart';
import 'routing/router.dart';
import 'routing/routes.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!FirebaseRuntimeConfig.enabled) {
    return;
  }
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (FirebaseRuntimeConfig.enabled) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await Firebase.initializeApp();
  }

  // Eagerly register bindings so we can init the EventRepository.
  InitialBinding().dependencies();
  final pairingDeepLinkCoordinator = Get.find<PairingDeepLinkCoordinator>();
  final initialLocale =
      await Get.find<LanguagePreferenceRepository>().getPreferredLocale() ??
      AppLocales.initialLocale();

  // Load persisted session and chat-cache state before the UI starts.
  await Future.wait([
    Get.find<EventRepository>().init(),
    Get.find<SessionChatCacheRepository>().init(),
    pairingDeepLinkCoordinator.start(),
  ]);

  // Fire-and-forget: don't block app startup for push registration.
  Get.find<PushNotificationService>().init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    MuxAgentApp(initialRoute: Routes.startup, initialLocale: initialLocale),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    pairingDeepLinkCoordinator.onNavigatorReady();
  });
}

class MuxAgentApp extends StatelessWidget {
  const MuxAgentApp({
    required this.initialRoute,
    this.initialLocale,
    super.key,
  });

  final String initialRoute;
  final Locale? initialLocale;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      translations: AppTranslations(),
      locale: initialLocale ?? AppLocales.initialLocale(),
      fallbackLocale: AppLocales.enUS,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: initialRoute,
      getPages: AppRouter.pages,
      routingCallback: (routing) {
        if (!Get.isRegistered<PairingDeepLinkCoordinator>()) {
          return;
        }
        Get.find<PairingDeepLinkCoordinator>().onRouteChanged(routing?.current);
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
