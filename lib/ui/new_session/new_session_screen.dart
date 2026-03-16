import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/fonts.dart';
import '../../config/theme.dart';
import '../../domain/mode_option.dart';
import '../../domain/runtime_option.dart';
import '../common/ui_effect_listener.dart';
import 'new_session_viewmodel.dart';

class NewSessionScreen extends GetView<NewSessionViewModel> {
  const NewSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: UiEffectListener(
        effects: controller.uiEffect,
        child: SafeArea(
          child: Column(
            children: [
              // Header: height 56, padding [0, 16], gap 12, alignItems center,
              // bottom border #E5E7EB
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // X icon 24x24 #6B6F76
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: const Icon(
                        LucideIcons.x,
                        size: 24,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title: Inter 17 w600 #1D1D1F
                    Text(
                      'New Session',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // Body: padding [24, 16], gap 24, vertical, fill_container
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Runtime Section
                              _buildFieldLabel('Runtime'),
                              const SizedBox(height: 8),
                              Obx(() => _buildRuntimeSelector()),
                              const SizedBox(height: 24),

                              // Machine Section: gap 8, vertical
                              _buildFieldLabel('Machine'),
                              const SizedBox(height: 8),
                              Obx(() => _buildMachineSelector()),
                              const SizedBox(height: 24),

                              // Directory Section: gap 8, vertical
                              _buildFieldLabel('Working Directory'),
                              const SizedBox(height: 8),
                              _buildDirectorySection(),
                              const SizedBox(height: 24),

                              // Prompt Section: gap 8, vertical
                              _buildFieldLabel('Initial Prompt'),
                              const SizedBox(height: 8),
                              _buildPromptInput(),
                              const SizedBox(height: 24),

                              // Mode Section
                              _buildFieldLabel('Permission Mode'),
                              const SizedBox(height: 8),
                              Obx(() => _buildModeSelector()),
                              const SizedBox(height: 24),

                              // Git Worktree Section
                              _buildFieldLabel('Git Worktree'),
                              const SizedBox(height: 8),
                              Obx(() => _buildWorktreeToggle()),
                            ],
                          ),
                        ),
                      ),

                      // Create Button: pinned at bottom
                      Padding(
                        padding: EdgeInsets.only(
                          top: 16,
                          bottom: MediaQuery.of(Get.context!).padding.bottom > 0
                              ? 16
                              : 24,
                        ),
                        child: _buildCreateButton(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Label: Inter 13 w500 #6B6F76
  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondary,
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
      onTap: _showMachinePicker,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Monitor icon 16x16 #808690
            const Icon(
              LucideIcons.monitor,
              size: 16,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(width: 8),
            // Machine name: Inter 14 normal #1D1D1F
            Expanded(
              child: Text(
                hostname,
                style: GoogleFonts.inter(
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
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(8),
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
              style: GoogleFonts.inter(
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
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No runtimes available',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
        ),
      );
    }

    final selectionEnabled = options.length > 1;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(8),
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
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Use runtime default mode',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
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
        onTap: canTap ? () => controller.selectRuntime(runtime) : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              _buildRuntimeIcon(runtime.id),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  runtime.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
              _buildRuntimeRadio(isSelected: isSelected, enabled: enabled),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuntimeIcon(String runtimeId) {
    final assetPath = switch (runtimeId) {
      'claude-code' => 'assets/anthropic-icon.png',
      'codex' => 'assets/openai-icon.png',
      _ => '',
    };

    if (assetPath.isEmpty) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(
          LucideIcons.cpu,
          size: 14,
          color: AppTheme.textSecondary,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Image.asset(assetPath, width: 20, height: 20, fit: BoxFit.cover),
    );
  }

  Widget _buildRuntimeRadio({required bool isSelected, required bool enabled}) {
    if (isSelected) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: enabled ? AppTheme.textMuted : AppTheme.border,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildModeCard({required ModeOption mode, required bool isSelected}) {
    final accent = _modeAccent(mode.id);
    return Semantics(
      label: mode.label,
      button: true,
      selected: isSelected,
      container: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => controller.selectMode(mode),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.inputFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  mode.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _modeAccent(String modeId) {
    switch (modeId) {
      case 'bypassPermissions':
      case 'dontAsk':
      case 'full-access':
        return const Color(0xFFF87171);
      case 'acceptEdits':
        return const Color(0xFF2563EB);
      case 'plan':
        return const Color(0xFF7C3AED);
      case 'default':
      case 'auto':
      case 'read-only':
      default:
        return const Color(0xFF9DA1A8);
    }
  }

  void _showMachinePicker() {
    if (controller.machines.isEmpty) return;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Select Machine',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1),
            ...controller.machines.map((machine) {
              final isOnline = controller.isMachineConnected(machine.machineId);
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
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: isOnline ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
                trailing: isOnline ? _statusDot(true) : _statusDot(false),
                onTap: isOnline
                    ? () {
                        controller.selectMachine(machine);
                        Get.back();
                      }
                    : null,
              );
            }),
          ],
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
  // The outer Obx only tracks isCwdDropdownOpen (for the border & showing the
  // dropdown). The inner Obx tracks filteredCwds so that typing to filter the
  // list does NOT rebuild the TextField — which would disconnect the IME and
  // close the keyboard on Android.
  Widget _buildDirectorySection() {
    return Obx(() {
      final isOpen = controller.isCwdDropdownOpen.value;

      return Container(
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(8),
          border: isOpen ? Border.all(color: AppTheme.primary, width: 2) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Input row — always at index 0 to preserve focus
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      onTap: () => controller.cwdFocusNode.requestFocus(),
                      child: TextField(
                        controller: controller.cwdController,
                        focusNode: controller.cwdFocusNode,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            controller.commitCwdAndFocusPrompt(),
                        onTapOutside: (_) => controller.cwdFocusNode.unfocus(),
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
            // Dropdown — conditionally shown below the input
            if (isOpen) ...[
              const Divider(height: 1, thickness: 1, color: AppTheme.border),
              // Nested Obx: only this rebuilds when filteredCwds changes,
              // keeping the TextField above stable.
              Obx(() {
                final filtered = controller.filteredCwds;
                return Container(
                  color: Colors.white,
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
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF9CA0A8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }
                      final cwd = filtered[index - 1];
                      final isFirst = index == 1;
                      return GestureDetector(
                        onTap: () => controller.selectCwd(cwd),
                        child: Container(
                          color: isFirst
                              ? AppTheme.hoverBg
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.folder,
                                size: 14,
                                color: Color(0xFF9CA0A8),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cwd.path,
                                      style: AppFonts.code(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _relativeTime(cwd.lastUsed),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF9CA0A8),
                                      ),
                                    ),
                                  ],
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

  Widget _buildWorktreeToggle() {
    final isOn = controller.useWorktree.value;
    return GestureDetector(
      onTap: controller.toggleWorktree,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isOn ? AppTheme.selectedBg : AppTheme.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOn ? AppTheme.primary : Colors.transparent,
            width: 1.5,
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
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isOn ? FontWeight.w600 : FontWeight.w500,
                      color: isOn
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Agent works on an isolated branch',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isOn
                          ? AppTheme.textSecondary
                          : AppTheme.textTertiary,
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

  // Prompt input: cornerRadius 8, fill #EDEEF1, height 80 (108 with mic)
  Widget _buildPromptInput() {
    return Obx(() {
      final showMic = controller.hasSttConfig.value;
      return Container(
        height: showMic ? 108 : 80,
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Semantics(
                  textField: true,
                  label: 'Initial prompt',
                  onTap: () => controller.promptFocusNode.requestFocus(),
                  child: TextField(
                    controller: controller.promptController,
                    focusNode: controller.promptFocusNode,
                    textInputAction: TextInputAction.done,
                    onTapOutside: (_) => controller.promptFocusNode.unfocus(),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    autocorrect: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Describe what you want to do...',
                      hintStyle: GoogleFonts.inter(
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
          width: 32,
          height: 32,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textSecondary),
            ),
          ),
        );
      }

      if (recording) {
        return GestureDetector(
          onTap: controller.stopVoiceInput,
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppTheme.recordRed,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),
        );
      }

      return GestureDetector(
        onTap: controller.startVoiceInput,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.mic, size: 16, color: Colors.white),
        ),
      );
    });
  }

  // Create Button: cornerRadius 8, fill #1D1D1F, height 48, center
  // Text: "Start Session", Inter 15 w600 #FFFFFF
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
        onTap: canCreate ? controller.startSession : null,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: canCreate ? AppTheme.primary : AppTheme.border,
            borderRadius: BorderRadius.circular(8),
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
                  style: GoogleFonts.inter(
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
