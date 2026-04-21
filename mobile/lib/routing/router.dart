import 'package:get/get.dart';

import '../bindings/auth_binding.dart';
import '../bindings/attach_session_binding.dart';
import '../bindings/chat_binding.dart';
import '../bindings/language_binding.dart';
import '../bindings/main_shell_binding.dart';
import '../bindings/new_session_binding.dart';
import '../bindings/permission_detail_binding.dart';
import '../bindings/scan_binding.dart';
import '../bindings/session_settings_binding.dart';
import '../bindings/startup_binding.dart';
import '../bindings/stt_settings_binding.dart';
import '../bindings/tool_detail_binding.dart';
import '../bindings/welcome_binding.dart';
import '../ui/auth/auth_screen.dart';
import '../ui/attach_session/attach_session_screen.dart';
import '../ui/chat/chat_screen.dart';
import '../ui/language/language_screen.dart';
import '../ui/main/main_shell.dart';
import '../ui/new_session/new_session_screen.dart';
import '../ui/permission_detail/permission_detail_screen.dart';
import '../ui/scan/scan_screen.dart';
import '../ui/session_settings/session_settings_screen.dart';
import '../ui/startup/startup_screen.dart';
import '../ui/stt_settings/stt_settings_page.dart';
import '../ui/tool_detail/tool_detail_screen.dart';
import '../ui/welcome/welcome_screen.dart';
import 'routes.dart';

class AppRouter {
  static final pages = [
    GetPage(
      name: Routes.startup,
      page: () => const StartupScreen(),
      binding: StartupBinding(),
    ),
    GetPage(
      name: Routes.home,
      page: () => const MainShell(),
      binding: MainShellBinding(),
    ),
    GetPage(
      name: Routes.welcome,
      page: () => const WelcomeScreen(),
      binding: WelcomeBinding(),
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
    GetPage(
      name: Routes.chat,
      page: () => const ChatScreen(),
      binding: ChatBinding(),
    ),
    GetPage(
      name: Routes.toolDetail,
      page: () => const ToolDetailScreen(),
      binding: ToolDetailBinding(),
    ),
    GetPage(
      name: Routes.permissionDetail,
      page: () => const PermissionDetailScreen(),
      binding: PermissionDetailBinding(),
    ),
    GetPage(
      name: Routes.newSession,
      page: () => const NewSessionScreen(),
      binding: NewSessionBinding(),
    ),
    GetPage(
      name: Routes.attachSession,
      page: () => const AttachSessionScreen(),
      binding: AttachSessionBinding(),
    ),
    GetPage(
      name: Routes.sttSettings,
      page: () => const SttSettingsPage(),
      binding: SttSettingsBinding(),
    ),
    GetPage(
      name: Routes.language,
      page: () => const LanguageScreen(),
      binding: LanguageBinding(),
    ),
    GetPage(
      name: Routes.sessionSettings,
      page: () => const SessionSettingsScreen(),
      binding: SessionSettingsBinding(),
    ),
  ];
}
