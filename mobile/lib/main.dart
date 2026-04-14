import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'bindings/initial_binding.dart';
import 'config/constant.dart';
import 'config/firebase.dart';
import 'config/theme.dart';
import 'data/repositories/event_repository.dart';
import 'data/repositories/session_chat_cache_repository.dart';
import 'data/services/push/push_notification_service.dart';
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

  // Load persisted session and chat-cache state before the UI starts.
  await Future.wait([
    Get.find<EventRepository>().init(),
    Get.find<SessionChatCacheRepository>().init(),
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

  runApp(const MuxAgentApp());
}

class MuxAgentApp extends StatelessWidget {
  const MuxAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      initialRoute: Routes.home,
      getPages: AppRouter.pages,
      debugShowCheckedModeBanner: false,
    );
  }
}
