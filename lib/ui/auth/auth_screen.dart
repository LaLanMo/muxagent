import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import 'auth_viewmodel.dart';

class AuthScreen extends GetView<AuthViewModel> {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Authorize Device',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: controller.cancel,
        ),
      ),
      body: Obx(() => _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (controller.state.value) {
      case AuthState.checking:
        return _buildChecking();
      case AuthState.pending:
        return _buildPending();
      case AuthState.approving:
        return _buildApproving();
      case AuthState.approved:
        return _buildApproved();
      case AuthState.expired:
        return _buildExpired();
      case AuthState.error:
        return _buildError();
    }
  }

  Widget _buildChecking() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(
            'Checking request...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPending() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.computer,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'New Device',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _infoRow(
                    'Hostname',
                    controller.machineHostname.value ?? 'Unknown host',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Do you want to authorize this device to connect?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.cancel,
                    child: const Text('Deny'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: controller.approve,
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApproving() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(
            'Approving...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApproved() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppTheme.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 40,
              color: AppTheme.successText,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Device Authorized',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'The device can now connect to the relay',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ElevatedButton(
              onPressed: controller.done,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.warningBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_off,
              size: 40,
              color: AppTheme.warning,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Request Expired',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Please scan a new QR code from the CLI',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ElevatedButton(
              onPressed: controller.cancel,
              child: const Text('Go Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              controller.errorMessage.value ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.cancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: controller.retry,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
