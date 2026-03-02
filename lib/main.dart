import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'bindings/initial_binding.dart';
import 'config/constant.dart';
import 'config/theme.dart';
import 'data/repositories/event_repository.dart';
import 'routing/router.dart';
import 'routing/routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Eagerly register bindings so we can init the EventRepository.
  InitialBinding().dependencies();

  // Load persisted sessions from SQLite before the UI starts.
  await Get.find<EventRepository>().init();

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
      themeMode: ThemeMode.system,
      initialRoute: Routes.home,
      getPages: AppRouter.pages,
      debugShowCheckedModeBanner: false,
    );
  }
}
