import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../domain/paired_machine.dart';
import '../common/relay_status_pill.dart';
import '../common/ui_effect_listener.dart';
import 'settings_tab_viewmodel.dart';

class SettingsTab extends GetView<SettingsTabViewModel> {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return UiEffectListener(
      effects: controller.uiEffect,
      child: Column(
        children: [
          // Header – height 56, padding [0, 16], alignItems center
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Settings',
                  style: AppTypography.sans(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const RelayStatusPill(),
              ],
            ),
          ),
          // Body – vertical, clip, fill_container height
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                child: Obx(() {
                  controller.machines.length;
                  controller.activeSessionIds.toSet();
                  controller.connectingMachines.length;
                  controller.relayConnected.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('MACHINES'),
                      ..._buildMachineRows(),
                      _buildSectionLabel('PAIRING'),
                      _buildSettingsRow(
                        icon: LucideIcons.qrCode,
                        label: 'Scan QR',
                        trailing: Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        onTap: controller.navigateToScan,
                        hasBorder: true,
                      ),
                      _buildSettingsRow(
                        icon: LucideIcons.link,
                        label: 'Enter URL',
                        trailing: Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        onTap: controller.showPasteUrlDialog,
                      ),
                      _buildSectionLabel('VOICE'),
                      _buildSettingsRow(
                        icon: LucideIcons.mic,
                        label: 'Speech to Text',
                        trailing: Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        onTap: controller.navigateToSttSettings,
                      ),
                      _buildSectionLabel('ABOUT'),
                      _buildSettingsRow(
                        icon: LucideIcons.info,
                        label: 'Version',
                        trailing: Text(
                          controller.appVersion.value.isEmpty
                              ? 'Loading...'
                              : controller.appVersion.value,
                          style: AppTypography.sans(
                            fontSize: 15,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        hasBorder: true,
                      ),
                      _buildSettingsRow(
                        icon: LucideIcons.shield,
                        label: 'Privacy Policy',
                        trailing: Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        onTap: controller.openPrivacyPolicy,
                        hasBorder: true,
                      ),
                      _buildSettingsRow(
                        icon: LucideIcons.fileText,
                        label: 'Terms of Use',
                        trailing: Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        onTap: controller.openTermsOfUse,
                      ),
                      // _buildSettingsRow(
                      //   icon: LucideIcons.zap,
                      //   label: "What's New",
                      //   trailing: Icon(LucideIcons.chevronRight,
                      //       size: 16, color: AppTheme.textMuted),
                      // ),
                      const SizedBox(height: 24),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section label: padding [20, 16, 8, 16], system sans 13 w500 #808690 letterSpacing 1
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: AppTypography.sans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
          color: AppTheme.textTertiary,
        ),
      ),
    );
  }

  // Build all machine rows from controller.machines
  List<Widget> _buildMachineRows() {
    final machines = controller.machines;
    // Force reactivity
    machines.length;
    if (machines.isEmpty) return const [];

    return machines.map((machine) => _buildMachineRow(machine)).toList();
  }

  // Machine row: padding [14, 16], gap 12, alignItems center, bottom border #E5E7EB
  Widget _buildMachineRow(PairedMachine machine) {
    final status = controller.machineConnectionState(machine.machineId);
    final connected = status == MachineConnectionDisplayState.online;
    final connecting = status == MachineConnectionDisplayState.connecting;
    final hostname = machine.hostname ?? 'Unknown host';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (connected || connecting)
          ? null
          : () => controller.connectMachine(machine),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Monitor icon 20x20 #6B6F76
            Icon(LucideIcons.monitor, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            // Machine name: system sans 15 normal #1D1D1F, fill_container
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hostname,
                    style: AppTypography.sans(
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (!connected && !connecting)
                    Text(
                      'Tap to reconnect',
                      style: AppTypography.sans(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            // Status pill
            _buildStatusPill(status),
          ],
        ),
      ),
    );
  }

  // Status pill: cornerRadius 8, gap 5, padding [3, 8]
  Widget _buildStatusPill(MachineConnectionDisplayState status) {
    final Color pillColor;
    final Color dotColor;
    final String textStr;

    switch (status) {
      case MachineConnectionDisplayState.online:
        pillColor = AppTheme.successBg;
        dotColor = AppTheme.successText;
        textStr = 'online';
      case MachineConnectionDisplayState.connecting:
        pillColor = AppTheme.warningBg;
        dotColor = AppTheme.statusConnecting;
        textStr = 'connecting';
      case MachineConnectionDisplayState.serverLost:
        pillColor = AppTheme.serverLostBg;
        dotColor = AppTheme.serverLostText;
        textStr = 'server lost';
      case MachineConnectionDisplayState.offline:
        pillColor = AppTheme.idleBg;
        dotColor = AppTheme.textTertiary;
        textStr = 'offline';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == MachineConnectionDisplayState.connecting)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppTheme.statusConnecting,
              ),
            )
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 5),
          Text(
            textStr,
            style: AppTypography.sans(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }

  // Settings row: padding [14, 16], gap 12, alignItems center, bottom border #E5E7EB
  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
    bool hasBorder = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: hasBorder
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left icon 20x20 #6B6F76
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            // Label: system sans 15 normal #1D1D1F, fill_container
            Expanded(
              child: Text(
                label,
                style: AppTypography.sans(
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
