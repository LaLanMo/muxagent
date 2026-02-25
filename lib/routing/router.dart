import 'package:get/get.dart';

import '../bindings/auth_binding.dart';
import '../bindings/home_binding.dart';
import '../bindings/scan_binding.dart';
import '../ui/auth/auth_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/scan/scan_screen.dart';
import 'routes.dart';

class AppRouter {
  static final pages = [
    GetPage(
      name: Routes.home,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.scan,
      page: () => const ScanScreen(),
      binding: ScanBinding(),
    ),
    GetPage(
      name: Routes.auth,
      page: () => const AuthScreen(),
      binding: AuthBinding(),
    ),
  ];
}
