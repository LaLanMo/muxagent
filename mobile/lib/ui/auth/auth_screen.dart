import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import '../../i18n/tx.dart';
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
                  Tx.authPairMachine.tr,
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
          title: Tx.authCheckingRequest.tr,
          description: Tx.authCheckingRequestBody.tr,
          spin: true,
        );
      case AuthState.pending:
        return _buildPending();
      case AuthState.approving:
        return _buildProgressState(
          icon: LucideIcons.loader,
          title: Tx.authPairingMachine.tr,
          description: Tx.authPairingMachineBody.tr,
          spin: true,
        );
      case AuthState.approved:
        return _buildResultState(
          statusTitle: Tx.authMachinePaired.tr,
          statusSubtitle: _machineEndpointLabel,
          cardBackground: AppTheme.successBg,
          statusColor: AppTheme.successText,
          statusIcon: LucideIcons.checkCircle2,
          statusLabel: Tx.authPairingComplete.tr,
          actionLabel: Tx.commonDone.tr,
          onAction: controller.done,
        );
      case AuthState.expired:
        return _buildResultState(
          statusTitle: Tx.authRequestExpired.tr,
          statusSubtitle: Tx.authRequestExpiredBody.tr,
          cardBackground: AppTheme.warningBg,
          statusColor: AppTheme.warning,
          statusIcon: LucideIcons.timerOff,
          statusLabel: Tx.authRequestExpiredStatus.tr,
          actionLabel: Tx.authGoBack.tr,
          onAction: controller.cancel,
        );
      case AuthState.error:
        return _buildResultState(
          statusTitle: Tx.authPairingFailed.tr,
          statusSubtitle:
              controller.errorMessage.value ?? Tx.authUnknownError.tr,
          cardBackground: AppTheme.errorBg,
          statusColor: AppTheme.errorText,
          statusIcon: LucideIcons.alertTriangle,
          statusLabel: Tx.commonError.tr,
          actionLabel: Tx.commonRetry.tr,
          onAction: controller.retry,
          secondaryLabel: Tx.commonCancel.tr,
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
          title: Tx.authMachineFound.tr,
          subtitle: _machineEndpointLabel,
          foreground: AppTheme.successText,
        ),
        const SizedBox(height: 20),
        Text(
          Tx.authMachineDetails.tr.toUpperCase(),
          style: AppTypography.mono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        _buildDetailRows(
          statusLabel: Tx.statusPending.tr,
          statusColor: AppTheme.warning,
        ),
        const Spacer(),
        _buildBottomActions(
          primaryLabel: Tx.authPairThisMachine.tr,
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
          Tx.authMachineDetails.tr.toUpperCase(),
          style: AppTypography.mono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        _buildDetailRows(statusLabel: statusLabel, statusColor: statusColor),
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
              style: AppTypography.mono(fontSize: 12, color: foreground),
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
        _buildDetailRow(Tx.authName.tr, _machineDisplayName),
        _buildDetailRow(Tx.authHost.tr, _machineHostLabel, monoValue: true),
        _buildDetailRow(Tx.authRelay.tr, _relayAuthority, monoValue: true),
        _buildDetailRow(
          Tx.authStatus.tr,
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
            : const Border(bottom: BorderSide(color: AppTheme.border)),
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
      return Tx.commonUnknownHost.tr;
    }
    return hostname;
  }

  String get _machineDisplayName {
    final hostname = controller.machineHostname.value?.trim();
    if (hostname == null || hostname.isEmpty) {
      return Tx.commonUnknownMachine.tr;
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
      return Tx.commonUnknownRelay.tr;
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
