import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import 'auth_viewmodel.dart';

class AuthScreen extends GetView<AuthViewModel> {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Obx(
        () => Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.borderStrong)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: controller.cancel,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(
                    LucideIcons.chevronLeft,
                    size: 20,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pair Machine',
                  style: AppTypography.sans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (controller.state.value) {
      case AuthState.checking:
        return _buildProgressState(
          icon: LucideIcons.loader,
          title: 'Checking Request',
          description: 'Verifying that this pairing request is still valid.',
          spin: true,
        );
      case AuthState.pending:
        return _buildPending();
      case AuthState.approving:
        return _buildProgressState(
          icon: LucideIcons.loader,
          title: 'Pairing Machine',
          description: 'Creating approval keys and registering this machine.',
          spin: true,
        );
      case AuthState.approved:
        return _buildResultState(
          statusTitle: 'Machine Paired',
          statusSubtitle: _machineEndpointLabel,
          cardBackground: AppTheme.successBg,
          statusColor: AppTheme.successText,
          statusIcon: LucideIcons.checkCircle2,
          statusLabel: 'Pairing complete',
          actionLabel: 'Done',
          onAction: controller.done,
        );
      case AuthState.expired:
        return _buildResultState(
          statusTitle: 'Request Expired',
          statusSubtitle: 'Scan a fresh QR code from the CLI to retry.',
          cardBackground: AppTheme.warningBg,
          statusColor: AppTheme.warning,
          statusIcon: LucideIcons.timerOff,
          statusLabel: 'Request expired',
          actionLabel: 'Go Back',
          onAction: controller.cancel,
        );
      case AuthState.error:
        return _buildResultState(
          statusTitle: 'Pairing Failed',
          statusSubtitle: controller.errorMessage.value ?? 'Unknown error',
          cardBackground: AppTheme.errorBg,
          statusColor: AppTheme.errorText,
          statusIcon: LucideIcons.alertTriangle,
          statusLabel: 'Error',
          actionLabel: 'Retry',
          onAction: controller.retry,
          secondaryLabel: 'Cancel',
          onSecondary: controller.cancel,
        );
    }
  }

  Widget _buildPending() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusCard(
          background: AppTheme.successBg,
          icon: LucideIcons.checkCircle2,
          iconColor: AppTheme.successText,
          title: 'Machine Found',
          subtitle: _machineEndpointLabel,
          foreground: AppTheme.successText,
        ),
        const SizedBox(height: 20),
        Text(
          'MACHINE DETAILS',
          style: AppTypography.mono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        _buildDetailRows(
          statusLabel: 'Pending',
          statusColor: AppTheme.warning,
        ),
        const Spacer(),
        _buildBottomActions(
          primaryLabel: 'Pair This Machine',
          onPrimary: controller.approve,
        ),
      ],
    );
  }

  Widget _buildProgressState({
    required IconData icon,
    required String title,
    required String description,
    bool spin = false,
  }) {
    return Column(
      children: [
        const Spacer(),
        _buildStatusCard(
          background: AppTheme.surfaceMuted,
          icon: icon,
          iconColor: AppTheme.textPrimary,
          title: title,
          subtitle: description,
          foreground: AppTheme.textPrimary,
          spinIcon: spin,
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildResultState({
    required String statusTitle,
    required String statusSubtitle,
    required Color cardBackground,
    required Color statusColor,
    required IconData statusIcon,
    required String statusLabel,
    required String actionLabel,
    required VoidCallback onAction,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusCard(
          background: cardBackground,
          icon: statusIcon,
          iconColor: statusColor,
          title: statusTitle,
          subtitle: statusSubtitle,
          foreground: statusColor,
        ),
        const SizedBox(height: 20),
        Text(
          'MACHINE DETAILS',
          style: AppTypography.mono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        _buildDetailRows(
          statusLabel: statusLabel,
          statusColor: statusColor,
        ),
        const Spacer(),
        _buildBottomActions(
          primaryLabel: actionLabel,
          onPrimary: onAction,
          secondaryLabel: secondaryLabel,
          onSecondary: onSecondary,
        ),
      ],
    );
  }

  Widget _buildBottomActions({
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (secondaryLabel != null && onSecondary != null) ...[
            _buildSecondaryButton(label: secondaryLabel, onTap: onSecondary),
            const SizedBox(height: 12),
          ],
          _buildPrimaryButton(label: primaryLabel, onTap: onPrimary),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required Color background,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color foreground,
    bool spinIcon = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: background,
      child: Column(
        children: [
          if (spinIcon)
            SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            )
          else
            Icon(icon, size: 32, color: iconColor),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.sans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.mono(
                fontSize: 12,
                color: foreground,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRows({
    required String statusLabel,
    required Color statusColor,
  }) {
    return Column(
      children: [
        _buildDetailRow('Name', _machineDisplayName),
        _buildDetailRow('Host', _machineHostLabel, monoValue: true),
        _buildDetailRow('Relay', _relayAuthority, monoValue: true),
        _buildDetailRow(
          'Status',
          statusLabel,
          valueColor: statusColor,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool monoValue = false,
    bool isLast = false,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppTheme.border),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.sans(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (monoValue ? AppTypography.mono : AppTypography.sans)(
                fontSize: monoValue ? 13 : 14,
                fontWeight: FontWeight.w400,
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 48,
        color: AppTheme.primary,
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.sans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.surface,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderStrong),
          color: AppTheme.surface,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.sans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  String get _machineHostLabel {
    final hostname = controller.machineHostname.value?.trim();
    if (hostname == null || hostname.isEmpty) {
      return 'Unknown host';
    }
    return hostname;
  }

  String get _machineDisplayName {
    final hostname = controller.machineHostname.value?.trim();
    if (hostname == null || hostname.isEmpty) {
      return 'Unknown Machine';
    }
    final withoutPort = hostname.split(':').first;
    final segment = withoutPort.split('.').first.trim();
    if (segment.isEmpty) {
      return withoutPort;
    }
    return segment;
  }

  String get _relayAuthority {
    final relay = controller.authRequest.relayUrl.trim();
    if (relay.isEmpty) {
      return 'Unknown relay';
    }
    final uri = Uri.tryParse(relay);
    if (uri == null) {
      return relay;
    }
    final host = uri.host.isEmpty ? relay : uri.host;
    if (uri.hasPort) {
      return '$host:${uri.port}';
    }
    return host;
  }

  String get _machineEndpointLabel {
    final hostname = controller.machineHostname.value?.trim();
    if (hostname == null || hostname.isEmpty) {
      return _relayAuthority;
    }
    return hostname;
  }
}
