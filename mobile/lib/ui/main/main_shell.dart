import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme.dart';
import '../common/pill_tab_bar.dart';
import 'active_tab.dart';
import 'history_tab.dart';
import 'main_shell_viewmodel.dart';
import 'settings_tab.dart';

class MainShell extends GetView<MainShellViewModel> {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            bottom: false,
            child: ColoredBox(
              color: AppTheme.background,
              child: Obx(
                () => IndexedStack(
                  index: controller.tabIndex.value,
                  children: const [ActiveTab(), HistoryTab(), SettingsTab()],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Obx(
              () => PillTabBar(
                currentIndex: controller.tabIndex.value,
                activeBadgeCount: controller.pendingApprovalCount,
                onTap: controller.switchTab,
                onCreateTap: controller.navigateToNewSession,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
