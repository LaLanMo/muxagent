import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/fonts.dart';
import '../../config/theme.dart';
import '../../domain/enums.dart';
import '../../domain/mode_option.dart';
import '../../domain/paired_machine.dart';
import '../../domain/runtime_option.dart';
import '../common/ui_effect_listener.dart';
import 'new_session_viewmodel.dart';

class NewSessionScreen extends GetView<NewSessionViewModel> {
  const NewSessionScreen({super.key});

  static const _fieldFill = Color(0xFFF0EAE5);
  static const _dropdownFill = AppTheme.surface;
  static const _modeSkipBg = Color(0xFFF5E2DF);
  static const _modeSkipBorder = Color(0xFFE0B2AA);
  static const _modeAcceptBg = Color(0xFFE0ECFA);
  static const _modeAcceptBorder = Color(0xFFB3CFF0);
  static const _modePlanBg = Color(0xFFEDE0FA);
  static const _modePlanBorder = Color(0xFFC9AFF0);

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
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                        'New Session',
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
                        _buildFieldLabel('Runtime'),
                        const SizedBox(height: 8),
                        Obx(() => _buildRuntimeSelector()),
                        const SizedBox(height: 24),

                        _buildFieldLabel('Machine'),
                        const SizedBox(height: 8),
                        Obx(() => _buildMachineSelector()),
                        const SizedBox(height: 24),

                        _buildFieldLabel('Working Directory'),
                        const SizedBox(height: 8),
                        _buildDirectorySection(),
                        const SizedBox(height: 24),

                        _buildFieldLabel('Initial Prompt'),
                        const SizedBox(height: 8),
                        _buildPromptInput(),
                        const SizedBox(height: 24),

                        Obx(
                          () => _buildFieldLabel(
                            _modeSectionLabel(
                              controller.selectedRuntime.value?.id,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Obx(() => _buildModeSelector()),
                        const SizedBox(height: 24),

                        _buildFieldLabel('Git Worktree'),
                        const SizedBox(height: 8),
                        Obx(() => _buildWorktreeToggle()),
                        const SizedBox(height: 24),
                        _buildCreateButton(),
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

    final bool isReconnecting = state == ConnState.reconnecting;
    final Color color = isReconnecting
        ? AppTheme.statusConnecting
        : AppTheme.statusDisconnected;
    final Color bg = isReconnecting
        ? AppTheme.warningBg
        : AppTheme.disconnectedBg;
    final IconData icon = isReconnecting
        ? LucideIcons.refreshCw
        : LucideIcons.cloudOff;
    final String label = isReconnecting
        ? 'Reconnecting...'
        : 'Server unreachable';

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

  // Machine selector: cornerRadius 8, fill #EDEEF1, padding 12, gap 8, alignItems center
  Widget _buildMachineSelector() {
    final selected = controller.selectedMachine.value;
    final hostname = selected != null
        ? (selected.hostname?.isNotEmpty == true
              ? selected.hostname!
              : 'Unknown host')
        : 'Select a machine';

    return GestureDetector(
      onTap: () {
        controller.dismissTransientInputs();
        _showMachinePicker();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _fieldFill,
          border: Border.all(color: AppTheme.chipBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                  fontWeight: FontWeight.normal,
                  color: selected != null
                      ? AppTheme.textPrimary
                      : AppTheme.textMuted,
                ),
              ),
            ),
            // Chevron-right 16x16 #C8CBD0
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuntimeSelector() {
    if (controller.isLoadingRuntimes.value) {
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
              'Loading runtimes...',
              style: AppTypography.sans(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final options = controller.availableRuntimes;
    if (options.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _fieldFill,
          border: Border.all(color: AppTheme.borderStrong),
        ),
        child: Text(
          'No runtimes available',
          style: AppTypography.sans(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    final selectionEnabled = options.length > 1;
    return Container(
      decoration: BoxDecoration(
        color: _fieldFill,
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _buildRuntimeRow(
              runtime: options[i],
              isSelected: controller.selectedRuntime.value?.id == options[i].id,
              enabled: selectionEnabled,
            ),
            if (i != options.length - 1)
              const Divider(height: 1, thickness: 1, color: AppTheme.border),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final options = controller.availableModes;
    if (options.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _fieldFill,
          border: Border.all(color: AppTheme.chipBorder),
        ),
        child: Text(
          'Use runtime default mode',
          style: AppTypography.mono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    final selected = controller.selectedMode.value;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final halfWidth = (constraints.maxWidth - gap) / 2;
        final children = <Widget>[];

        for (var i = 0; i < options.length; i++) {
          final mode = options[i];
          children.add(
            SizedBox(
              width: halfWidth,
              child: _buildModeCard(
                mode: mode,
                isSelected: selected?.id == mode.id,
              ),
            ),
          );
        }

        return Wrap(spacing: gap, runSpacing: gap, children: children);
      },
    );
  }

  Widget _buildRuntimeRow({
    required RuntimeOption runtime,
    required bool isSelected,
    required bool enabled,
  }) {
    final canTap = enabled && runtime.ready;
    final labelColor = canTap ? AppTheme.textPrimary : AppTheme.textSecondary;

    return Semantics(
      label: runtime.label,
      button: true,
      enabled: canTap,
      selected: isSelected,
      container: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: canTap
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
              _buildRuntimeLeadingIcon(runtime.id, enabled: canTap),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  runtime.label,
                  style: AppTypography.sans(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    color: labelColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildRuntimeRadio(isSelected: isSelected, enabled: enabled),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuntimeLeadingIcon(String runtimeId, {required bool enabled}) {
    final assetPath = _runtimeAssetPath(runtimeId);
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
    if (enabled) {
      return image;
    }
    return Opacity(opacity: 0.45, child: image);
  }

  String? _runtimeAssetPath(String runtimeId) {
    switch (runtimeId) {
      case 'claude-code':
        return 'assets/anthropic-icon.png';
      case 'codex':
        return 'assets/openai-icon.png';
      case 'copilot':
        return 'assets/github-copilot-icon.png';
      case 'gemini':
        return 'assets/gemini-icon.png';
      case 'goose':
        return 'assets/goose-icon.png';
      case 'opencode':
        return 'assets/opencode-icon.png';
      default:
        return null;
    }
  }

  String _modeSectionLabel(String? runtimeId) {
    return 'Mode';
  }

  Widget _buildRuntimeRadio({required bool isSelected, required bool enabled}) {
    if (isSelected) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primary, width: 2),
        ),
      );
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: enabled ? AppTheme.chipBorder : AppTheme.border,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildModeCard({required ModeOption mode, required bool isSelected}) {
    return Semantics(
      label: mode.label,
      button: true,
      selected: isSelected,
      container: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          controller.dismissTransientInputs();
          controller.selectMode(mode);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _modeFill(mode.id),
            border: Border.all(
              color: _modeBorder(mode.id, isSelected),
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            mode.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.mono(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: _modeText(mode.id),
            ),
          ),
        ),
      ),
    );
  }

  Color _modeFill(String modeId) {
    switch (modeId) {
      case 'bypassPermissions':
      case 'dontAsk':
      case 'full-access':
        return _modeSkipBg;
      case 'acceptEdits':
      case 'https://agentclientprotocol.com/protocol/session-modes#agent':
        return _modeAcceptBg;
      case 'https://agentclientprotocol.com/protocol/session-modes#autopilot':
        return _fieldFill;
      case 'plan':
      case 'https://agentclientprotocol.com/protocol/session-modes#plan':
        return _modePlanBg;
      case 'default':
      case 'auto':
      case 'read-only':
      default:
        return AppTheme.surfaceMuted;
    }
  }

  Color _modeBorder(String modeId, bool isSelected) {
    if (isSelected) return AppTheme.textPrimary;
    switch (modeId) {
      case 'bypassPermissions':
      case 'dontAsk':
      case 'full-access':
        return _modeSkipBorder;
      case 'acceptEdits':
      case 'https://agentclientprotocol.com/protocol/session-modes#agent':
        return _modeAcceptBorder;
      case 'plan':
      case 'https://agentclientprotocol.com/protocol/session-modes#plan':
        return _modePlanBorder;
      default:
        return AppTheme.chipBorder;
    }
  }

  Color _modeText(String modeId) {
    switch (modeId) {
      case 'bypassPermissions':
      case 'dontAsk':
      case 'full-access':
        return AppTheme.errorText;
      case 'acceptEdits':
      case 'https://agentclientprotocol.com/protocol/session-modes#agent':
        return const Color(0xFF2563EB);
      case 'plan':
      case 'https://agentclientprotocol.com/protocol/session-modes#plan':
        return const Color(0xFF7C3AED);
      default:
        return AppTheme.textPrimary;
    }
  }

  void _showMachinePicker() {
    if (controller.machines.isEmpty) return;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        color: AppTheme.surface,
        child: ValueListenableBuilder<List<PairedMachine>>(
          valueListenable: controller.machinesListenable,
          builder: (context, machines, _) {
            return ValueListenableBuilder<Set<String>>(
              valueListenable: controller.activeSessionIdsListenable,
              builder: (context, activeSessionIds, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Select Machine',
                        style: AppTypography.sans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ...machines.map((machine) {
                      final isOnline = activeSessionIds.contains(
                        machine.machineId,
                      );
                      final name = machine.hostname ?? 'Unknown host';
                      return ListTile(
                        enabled: isOnline,
                        leading: const Icon(
                          LucideIcons.monitor,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                        title: Text(
                          name,
                          style: AppTypography.sans(
                            fontSize: 15,
                            color: isOnline
                                ? AppTheme.textPrimary
                                : AppTheme.textMuted,
                          ),
                        ),
                        trailing: isOnline
                            ? _statusDot(true)
                            : _statusDot(false),
                        onTap: isOnline
                            ? () {
                                controller.dismissTransientInputs();
                                controller.selectMachine(machine);
                                Get.back();
                              }
                            : null,
                      );
                    }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _statusDot(bool online) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: online ? AppTheme.successText : AppTheme.textTertiary,
        shape: BoxShape.circle,
      ),
    );
  }

  // Directory input with recent-cwd dropdown.
  // Visibility is explicit: tapping the field opens it, and only an outside
  // tap closes it. The inner Obx tracks filteredCwds so that typing to filter
  // the list does NOT rebuild the TextField — which would disconnect the IME
  // and close the keyboard on Android.
  Widget _buildDirectorySection() {
    return Obx(() {
      final isOpen = controller.isCwdDropdownOpen.value;

      return Container(
        decoration: BoxDecoration(
          color: _fieldFill,
          border: Border(
            top: const BorderSide(color: AppTheme.textPrimary, width: 2),
            left: isOpen
                ? BorderSide.none
                : const BorderSide(color: AppTheme.chipBorder),
            right: isOpen
                ? BorderSide.none
                : const BorderSide(color: AppTheme.chipBorder),
            bottom: isOpen
                ? BorderSide.none
                : const BorderSide(color: AppTheme.chipBorder),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: controller.openCwdDropdown,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.folder,
                      size: 16,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        textField: true,
                        label: 'Working directory',
                        onTap: controller.openCwdDropdown,
                        child: TextField(
                          controller: controller.cwdController,
                          focusNode: controller.cwdFocusNode,
                          textInputAction: TextInputAction.next,
                          onTap: controller.openCwdDropdown,
                          onSubmitted: (_) =>
                              controller.commitCwdAndFocusPrompt(),
                          autocorrect: false,
                          enableSuggestions: false,
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          style: AppFonts.code(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
                            hintText: '~/project',
                            hintStyle: AppFonts.code(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isOpen) ...[
              Container(height: 1, color: AppTheme.borderStrong),
              Obx(() {
                final filtered = controller.filteredCwds;
                final highlightFirstMatch = controller.cwdController.text
                    .trim()
                    .isNotEmpty;
                if (filtered.isEmpty) {
                  return Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: _dropdownFill,
                      border: Border(
                        left: BorderSide(color: AppTheme.borderStrong),
                        right: BorderSide(color: AppTheme.borderStrong),
                        bottom: BorderSide(color: AppTheme.borderStrong),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Text(
                      'No recent directories',
                      style: AppTypography.mono(
                        fontSize: 10,
                        color: AppTheme.textMetadata,
                      ),
                    ),
                  );
                }
                return Container(
                  decoration: const BoxDecoration(
                    color: _dropdownFill,
                    border: Border(
                      left: BorderSide(color: AppTheme.borderStrong),
                      right: BorderSide(color: AppTheme.borderStrong),
                      bottom: BorderSide(color: AppTheme.borderStrong),
                    ),
                  ),
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length + 1, // +1 for header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                          child: Text(
                            'RECENT',
                            style: AppTypography.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMetadata,
                              letterSpacing: 1,
                            ),
                          ),
                        );
                      }
                      final cwd = filtered[index - 1];
                      final isHighlighted = highlightFirstMatch && index == 1;
                      final displayPath = _formatCwdDisplayPath(cwd.path);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => controller.selectCwd(cwd),
                        child: Container(
                          color: isHighlighted
                              ? AppTheme.surfaceMuted
                              : _dropdownFill,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.folder,
                                size: 14,
                                color: AppTheme.textTertiary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  displayPath,
                                  style: AppFonts.code(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: isHighlighted
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _relativeTime(cwd.lastUsed).toLowerCase(),
                                style: AppFonts.code(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ],
        ),
      );
    });
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 14) return 'Last week';
    if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    }
    return 'Last month';
  }

  String _formatCwdDisplayPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final homeMatch = RegExp(r'^/(Users|home)/[^/]+').firstMatch(trimmed);
    if (homeMatch == null) {
      return trimmed;
    }
    return trimmed.replaceRange(0, homeMatch.group(0)!.length, '~');
  }

  Widget _buildWorktreeToggle() {
    final isOn = controller.useWorktree.value;
    return GestureDetector(
      onTap: () {
        controller.dismissTransientInputs();
        controller.toggleWorktree();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          border: Border.all(
            color: isOn ? AppTheme.textPrimary : AppTheme.chipBorder,
            width: isOn ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.gitBranch,
              size: 14,
              color: isOn ? AppTheme.textPrimary : AppTheme.textTertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use Worktree',
                    style: AppTypography.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Agent works on an isolated branch',
                    style: AppTypography.sans(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptInput() {
    return Obx(() {
      final showMic = controller.hasSttConfig.value;
      return Container(
        height: showMic ? 88 : 72,
        decoration: BoxDecoration(
          color: _fieldFill,
          border: Border.all(color: AppTheme.chipBorder),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Semantics(
                  textField: true,
                  label: 'Initial prompt',
                  onTap: controller.focusPromptInput,
                  child: TextField(
                    controller: controller.promptController,
                    focusNode: controller.promptFocusNode,
                    textInputAction: TextInputAction.done,
                    onTap: controller.focusPromptInput,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    autocorrect: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
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
                      hintText: 'Describe what you want to do...',
                      hintStyle: AppTypography.sans(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showMic)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_buildMicButton()],
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildMicButton() {
    return Obx(() {
      final recording = controller.isVoiceRecording.value;
      final transcribing = controller.isTranscribing.value;

      if (transcribing) {
        return const SizedBox(
          width: 18,
          height: 18,
          child: Padding(
            padding: EdgeInsets.all(1),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textSecondary),
            ),
          ),
        );
      }

      if (recording) {
        return GestureDetector(
          onTap: () {
            controller.dismissTransientInputs();
            controller.stopVoiceInput();
          },
          child: const Icon(
            LucideIcons.stopCircle,
            size: 18,
            color: AppTheme.recordRed,
          ),
        );
      }

      return GestureDetector(
        onTap: () {
          controller.dismissTransientInputs();
          controller.startVoiceInput();
        },
        child: const Icon(
          LucideIcons.mic,
          size: 18,
          color: AppTheme.textTertiary,
        ),
      );
    });
  }

  Widget _buildCreateButton() {
    return Obx(() {
      final hasMachine = controller.selectedMachine.value != null;
      final runtimes = controller.availableRuntimes;
      final hasRuntimeSelection =
          runtimes.isNotEmpty &&
          ((runtimes.length == 1) ||
              (controller.selectedRuntime.value != null));
      final canCreate =
          hasMachine && hasRuntimeSelection && !controller.isLoading.value;

      return GestureDetector(
        onTap: canCreate
            ? () {
                controller.dismissTransientInputs();
                controller.startSession();
              }
            : null,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: canCreate ? AppTheme.primary : AppTheme.borderStrong,
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
                  'Start Session',
                  style: AppTypography.sans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: canCreate ? Colors.white : AppTheme.textTertiary,
                  ),
                ),
        ),
      );
    });
  }
}
