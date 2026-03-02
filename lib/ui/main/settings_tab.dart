import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../domain/paired_machine.dart';
import '../common/ui_effect_listener.dart';
import 'main_shell_viewmodel.dart';
import 'settings_tab_viewmodel.dart';

class SettingsTab extends GetView<SettingsTabViewModel> {
  const SettingsTab({super.key});

  MainShellViewModel get shell => Get.find<MainShellViewModel>();

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
          alignment: Alignment.centerLeft,
          child: Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1D1D1F),
            ),
          ),
        ),
        // Body – vertical, clip, fill_container height
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              child: Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('MACHINES'),
                  ..._buildMachineRows(),
                  _buildSectionLabel('PAIRING'),
                  _buildSettingsRow(
                    icon: LucideIcons.qrCode,
                    label: 'Scan QR',
                    trailing: Icon(LucideIcons.chevronRight,
                        size: 16, color: const Color(0xFFC8CBD0)),
                    onTap: controller.navigateToScan,
                    hasBorder: true,
                  ),
                  _buildSettingsRow(
                    icon: LucideIcons.link,
                    label: 'Enter URL',
                    trailing: Icon(LucideIcons.chevronRight,
                        size: 16, color: const Color(0xFFC8CBD0)),
                    onTap: controller.showPasteUrlDialog,
                  ),
                  _buildSectionLabel('ABOUT'),
                  _buildSettingsRow(
                    icon: LucideIcons.info,
                    label: 'Version',
                    trailing: Text(
                      '1.0.0',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF808690),
                      ),
                    ),
                    hasBorder: true,
                  ),
                  // _buildSettingsRow(
                  //   icon: LucideIcons.zap,
                  //   label: "What's New",
                  //   trailing: Icon(LucideIcons.chevronRight,
                  //       size: 16, color: const Color(0xFFC8CBD0)),
                  // ),
                  const SizedBox(height: 24),
                ],
              )),
            ),
          ),
        ),
      ],
      ),
    );
  }

  // Section label: padding [20, 16, 8, 16], Inter 13 w500 #808690 letterSpacing 1
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
          color: const Color(0xFF808690),
        ),
      ),
    );
  }

  // Build all machine rows from shell.machines
  List<Widget> _buildMachineRows() {
    final machines = shell.machines;
    // Force reactivity
    machines.length;
    if (machines.isEmpty) return const [];

    return machines.map((machine) => _buildMachineRow(machine)).toList();
  }

  // Machine row: padding [14, 16], gap 12, alignItems center, bottom border #E5E7EB
  Widget _buildMachineRow(PairedMachine machine) {
    final connected = shell.isMachineConnected(machine.machineId);
    final connecting = controller.connectingMachines.contains(machine.machineId);
    final hostname = machine.hostname ?? 'Unknown host';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (connected || connecting) ? null : () => controller.connectMachine(machine),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Monitor icon 20x20 #6B6F76
            Icon(LucideIcons.monitor,
                size: 20, color: const Color(0xFF6B6F76)),
            const SizedBox(width: 12),
            // Machine name: Inter 15 normal #1D1D1F, fill_container
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hostname,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      color: const Color(0xFF1D1D1F),
                    ),
                  ),
                  if (!connected && !connecting)
                    Text(
                      'Tap to reconnect',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF808690),
                      ),
                    ),
                ],
              ),
            ),
            // Status pill
            _buildStatusPill(connected, connecting: connecting),
          ],
        ),
      ),
    );
  }

  // Status pill: cornerRadius 8, gap 5, padding [3, 8]
  Widget _buildStatusPill(bool online, {bool connecting = false}) {
    final Color pillColor;
    final Color dotColor;
    final String textStr;

    if (connecting) {
      pillColor = const Color(0xFFFFF8E1);
      dotColor = const Color(0xFFE07B54);
      textStr = 'connecting';
    } else if (online) {
      pillColor = const Color(0xFFECFDF5);
      dotColor = const Color(0xFF4CB782);
      textStr = 'online';
    } else {
      pillColor = const Color(0xFFF5F5F5);
      dotColor = const Color(0xFF808690);
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
          if (connecting)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFFE07B54),
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
            style: GoogleFonts.inter(
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
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left icon 20x20 #6B6F76
            Icon(icon, size: 20, color: const Color(0xFF6B6F76)),
            const SizedBox(width: 12),
            // Label: Inter 15 normal #1D1D1F, fill_container
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                  color: const Color(0xFF1D1D1F),
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
