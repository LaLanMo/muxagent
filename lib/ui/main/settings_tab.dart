import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../domain/paired_machine.dart';
import '../common/relay_status_pill.dart';
import '../common/status_indicator.dart';
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
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const RelayStatusPill(),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                child: Obx(() {
                  final machines = controller.machines.toList(growable: false);
                  final activeSessionIds = controller.activeSessionIds.toSet();
                  final connectingMachines = controller.connectingMachines
                      .toSet();
                  controller.relayConnected.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('MACHINES'),
                      ..._buildMachineRows(
                        machines: machines,
                        activeSessionIds: activeSessionIds,
                        connectingMachines: connectingMachines,
                        relayConnected: controller.relayConnected.value,
                      ),
                      _buildSectionLabel('PAIRING'),
                      _buildSettingsRow(
                        icon: LucideIcons.qrCode,
                        label: 'Scan QR Code',
                        trailing: Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        onTap: controller.navigateToScan,
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
                      _buildSectionLabel('CONFIGURATION'),
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

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: AppTypography.mono(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: AppTheme.textTertiary,
        ),
      ),
    );
  }

  List<Widget> _buildMachineRows({
    required List<PairedMachine> machines,
    required Set<String> activeSessionIds,
    required Set<String> connectingMachines,
    required bool relayConnected,
  }) {
    if (machines.isEmpty) return const [];

    return machines
        .map(
          (machine) => _buildMachineRow(
            machine,
            status: _machineConnectionState(
              machineId: machine.machineId,
              activeSessionIds: activeSessionIds,
              connectingMachines: connectingMachines,
              relayConnected: relayConnected,
            ),
          ),
        )
        .toList();
  }

  MachineConnectionDisplayState _machineConnectionState({
    required String machineId,
    required Set<String> activeSessionIds,
    required Set<String> connectingMachines,
    required bool relayConnected,
  }) {
    if (activeSessionIds.contains(machineId)) {
      return MachineConnectionDisplayState.online;
    }
    if (connectingMachines.contains(machineId)) {
      return MachineConnectionDisplayState.connecting;
    }
    if (!relayConnected) {
      return MachineConnectionDisplayState.serverLost;
    }
    return MachineConnectionDisplayState.offline;
  }

  Widget _buildMachineRow(
    PairedMachine machine, {
    required MachineConnectionDisplayState status,
  }) {
    final connected = status == MachineConnectionDisplayState.online;
    final connecting = status == MachineConnectionDisplayState.connecting;
    final hostname = machine.hostname ?? 'Unknown host';
    final helperText = !connected && !connecting ? 'Tap to reconnect' : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (connected || connecting)
          ? null
          : () => controller.connectMachine(machine),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(LucideIcons.monitor, size: 20, color: AppTheme.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hostname,
                    style: AppTypography.sans(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (helperText != null)
                    Text(
                      helperText,
                      style: AppTypography.mono(
                        fontSize: 12,
                        color: AppTheme.textMetadata,
                      ),
                    ),
                ],
              ),
            ),
            _buildStatusPill(status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(MachineConnectionDisplayState status) {
    switch (status) {
      case MachineConnectionDisplayState.online:
        return const StatusIndicator.online();
      case MachineConnectionDisplayState.connecting:
        return const StatusIndicator.connecting();
      case MachineConnectionDisplayState.serverLost:
        return const StatusIndicator.serverLost();
      case MachineConnectionDisplayState.offline:
        return const StatusIndicator.offline();
    }
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppTheme.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.sans(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
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
