import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import '../../domain/enums.dart';
import '../../domain/paired_machine.dart';
import '../../domain/runtime_option.dart';
import '../common/ui_effect_listener.dart';
import 'attach_session_viewmodel.dart';

class AttachSessionScreen extends GetView<AttachSessionViewModel> {
  const AttachSessionScreen({super.key});

  static const _fieldFill = Color(0xFFF0EAE5);
  static const _dropdownFill = AppTheme.surface;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: controller.dismissTransientInputs,
        child: UiEffectListener(
          effects: controller.uiEffect,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.borderStrong),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          controller.dismissTransientInputs();
                          Get.back();
                        },
                        child: const Icon(
                          LucideIcons.x,
                          size: 20,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Attach Session',
                        style: AppTypography.sans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Obx(
                  () => _buildRelayConnectionBanner(
                    connected: controller.relayConnected.value,
                    state: controller.relayConnectionState.value,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset + 34),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildExplanationCard(),
                        const SizedBox(height: 24),
                        _buildFieldLabel('Session ID'),
                        const SizedBox(height: 8),
                        _buildSessionIdInput(),
                        const SizedBox(height: 24),
                        _buildFieldLabel('Runtime'),
                        const SizedBox(height: 8),
                        Obx(() => _buildRuntimeSelector()),
                        const SizedBox(height: 24),
                        _buildFieldLabel('Machine'),
                        const SizedBox(height: 8),
                        Obx(() => _buildMachineSelector()),
                        const SizedBox(height: 24),
                        _buildAttachButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.mono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: AppTheme.textTertiary,
      ),
    );
  }

  Widget _buildRelayConnectionBanner({
    required bool connected,
    required ConnState state,
  }) {
    if (connected) return const SizedBox.shrink();

    final isReconnecting = state == ConnState.reconnecting;
    final color = isReconnecting
        ? AppTheme.statusConnecting
        : AppTheme.statusDisconnected;
    final bg = isReconnecting ? AppTheme.warningBg : AppTheme.disconnectedBg;
    final icon = isReconnecting ? LucideIcons.refreshCw : LucideIcons.cloudOff;
    final label = isReconnecting ? 'Reconnecting...' : 'Server unreachable';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.sans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(color: _fieldFill),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue a session you started in your machine',
            style: AppTypography.sans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the session ID from your runtime',
            style: AppTypography.sans(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionIdInput() {
    return Container(
      decoration: const BoxDecoration(
        color: _fieldFill,
        border: Border(
          top: BorderSide(color: AppTheme.textPrimary, width: 2),
          left: BorderSide(color: AppTheme.chipBorder),
          right: BorderSide(color: AppTheme.chipBorder),
          bottom: BorderSide(color: AppTheme.chipBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(LucideIcons.link2, size: 16, color: AppTheme.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller.sessionIdController,
              focusNode: controller.sessionIdFocusNode,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              onTap: controller.focusSessionIdInput,
              style: AppTypography.sans(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'session-123',
                hintStyle: AppTypography.sans(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeSelector() {
    if (controller.isLoadingRuntimes.value) {
      return _buildLoadingSelector(label: 'Loading runtimes...');
    }

    final options = controller.availableRuntimes;
    if (options.isEmpty) {
      return _buildEmptySelector(label: 'No runtimes available');
    }

    final selected = controller.selectedRuntime.value;
    return Column(
      children: [
        GestureDetector(
          onTap: controller.toggleRuntimeDropdown,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _fieldFill,
              border: Border.all(color: AppTheme.chipBorder),
            ),
            child: Row(
              children: [
                _buildRuntimeLeadingIcon(selected?.id ?? '', enabled: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected?.label ?? 'Select a runtime',
                    style: AppTypography.sans(
                      fontSize: 14,
                      color: selected != null
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (controller.isRuntimeDropdownOpen.value)
          Container(
            decoration: BoxDecoration(
              color: _dropdownFill,
              border: Border.all(color: AppTheme.borderStrong),
            ),
            child: Column(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  _buildRuntimeOption(
                    runtime: options[i],
                    isSelected: selected?.id == options[i].id,
                  ),
                  if (i != options.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppTheme.border,
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMachineSelector() {
    final selected = controller.selectedMachine.value;
    final hostname = selected?.hostname?.isNotEmpty == true
        ? selected!.hostname!
        : (selected != null ? 'Unknown host' : 'Select a machine');

    return ValueListenableBuilder<List<PairedMachine>>(
      valueListenable: controller.machinesListenable,
      builder: (context, machines, _) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: controller.activeSessionIdsListenable,
          builder: (context, activeSessionIds, _) {
            return Obx(() {
              final isOpen = controller.isMachineDropdownOpen.value;
              final selectedMachineId =
                  controller.selectedMachine.value?.machineId;

              return Column(
                children: [
                  GestureDetector(
                    onTap: controller.toggleMachineDropdown,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _fieldFill,
                        border: Border.all(color: AppTheme.chipBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.monitor,
                            size: 16,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hostname,
                              style: AppTypography.sans(
                                fontSize: 14,
                                color: selected != null
                                    ? AppTheme.textPrimary
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            LucideIcons.chevronDown,
                            size: 16,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isOpen)
                    Container(
                      decoration: BoxDecoration(
                        color: _dropdownFill,
                        border: Border.all(color: AppTheme.borderStrong),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < machines.length; i++) ...[
                            _buildMachineOption(
                              machine: machines[i],
                              isOnline: activeSessionIds.contains(
                                machines[i].machineId,
                              ),
                              isSelected:
                                  selectedMachineId == machines[i].machineId,
                            ),
                            if (i != machines.length - 1)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: AppTheme.border,
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            });
          },
        );
      },
    );
  }

  Widget _buildRuntimeOption({
    required RuntimeOption runtime,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: runtime.ready
          ? () {
              controller.dismissTransientInputs();
              controller.selectRuntime(runtime);
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            _buildRuntimeLeadingIcon(runtime.id, enabled: runtime.ready),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                runtime.label,
                style: AppTypography.sans(
                  fontSize: 14,
                  color: runtime.ready
                      ? AppTheme.textPrimary
                      : AppTheme.textMuted,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                LucideIcons.check,
                size: 16,
                color: AppTheme.textPrimary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMachineOption({
    required PairedMachine machine,
    required bool isOnline,
    required bool isSelected,
  }) {
    final label = machine.hostname?.isNotEmpty == true
        ? machine.hostname!
        : 'Unknown host';
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(
            LucideIcons.monitor,
            size: 16,
            color: isOnline ? AppTheme.textTertiary : AppTheme.textMetadata,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTypography.sans(
                fontSize: 14,
                color: isOnline ? AppTheme.textPrimary : AppTheme.textMuted,
              ),
            ),
          ),
          if (isSelected)
            const Icon(LucideIcons.check, size: 16, color: AppTheme.textPrimary)
          else
            _statusDot(isOnline),
        ],
      ),
    );

    return GestureDetector(
      onTap: isOnline
          ? () {
              controller.dismissTransientInputs();
              controller.selectMachine(machine);
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(opacity: isOnline ? 1 : 0.55, child: row),
    );
  }

  Widget _buildRuntimeLeadingIcon(String runtimeId, {required bool enabled}) {
    final assetPath = switch (runtimeId) {
      'claude-code' => 'assets/anthropic-icon.png',
      'codex' => 'assets/openai-icon.png',
      'copilot' => 'assets/github-copilot-icon.png',
      'gemini' => 'assets/gemini-icon.png',
      'goose' => 'assets/goose-icon.png',
      'opencode' => 'assets/opencode-icon.png',
      _ => null,
    };

    if (assetPath == null) {
      return Icon(
        LucideIcons.cpu,
        size: 18,
        color: enabled ? AppTheme.textTertiary : AppTheme.textMuted,
      );
    }

    final image = Image.asset(
      assetPath,
      width: 20,
      height: 20,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    return enabled ? image : Opacity(opacity: 0.45, child: image);
  }

  Widget _buildAttachButton() {
    return Obx(() {
      final canSubmit =
          controller.selectedMachine.value != null &&
          controller.selectedRuntime.value != null &&
          controller.sessionIdText.value.isNotEmpty &&
          !controller.isLoading.value;

      return GestureDetector(
        onTap: canSubmit
            ? () {
                controller.dismissTransientInputs();
                controller.attachSession();
              }
            : null,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: canSubmit ? AppTheme.primary : AppTheme.borderStrong,
          ),
          alignment: Alignment.center,
          child: controller.isLoading.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Attach Session',
                  style: AppTypography.sans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: canSubmit ? Colors.white : AppTheme.textTertiary,
                  ),
                ),
        ),
      );
    });
  }

  Widget _buildLoadingSelector({required String label}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldFill,
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTypography.sans(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySelector({required String label}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldFill,
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Text(
        label,
        style: AppTypography.sans(fontSize: 14, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _statusDot(bool online) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: online ? AppTheme.successText : AppTheme.textMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}
