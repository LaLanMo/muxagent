import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'bindings/initial_binding.dart';
import 'config/constant.dart';
import 'config/theme.dart';
import 'routing/router.dart';
import 'routing/routes.dart';

void main() {
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
      initialBinding: InitialBinding(),
      initialRoute: Routes.home,
      getPages: AppRouter.pages,
      debugShowCheckedModeBanner: false,
    );
  }
}
