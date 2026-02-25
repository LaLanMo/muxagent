import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import 'settings_viewmodel.dart';

class SettingsScreen extends GetView<SettingsViewModel> {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device section
            _buildSectionLabel('DEVICE'),
            const SizedBox(height: 12),
            _buildDeviceCard(),
            const SizedBox(height: 24),

            // Pairing section
            _buildSectionLabel('PAIRING'),
            const SizedBox(height: 12),
            _buildPairingCard(),
            const SizedBox(height: 24),

            // About section
            _buildSectionLabel('ABOUT'),
            const SizedBox(height: 12),
            _buildAboutCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildRow(
            icon: Icons.phone_iphone,
            label: 'Device Name',
            trailing: Text(
              GetPlatform.isIOS ? 'iPhone' : 'Android',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            showDivider: true,
          ),
          Obx(
            () => _buildRow(
              icon: Icons.key,
              label: 'Master Key',
              trailing: controller.hasMasterKey.value
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppTheme.successText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Configured',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.successText,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Not configured',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textTertiary,
                      ),
                    ),
              showDivider: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildTappableRow(
            icon: Icons.qr_code_scanner,
            label: 'Scan QR Code',
            onTap: controller.navigateToScan,
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.border,
            indent: 16,
            endIndent: 16,
          ),
          _buildTappableRow(
            icon: Icons.link,
            label: 'Paste Connection URL',
            onTap: controller.showPasteUrlDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _buildRow(
        icon: Icons.info_outline,
        label: 'Version',
        trailing: Text(
          '1.0.0',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        showDivider: false,
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String label,
    required Widget trailing,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.border,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }

  Widget _buildTappableRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
