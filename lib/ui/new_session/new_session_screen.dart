import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/fonts.dart';
import '../../config/theme.dart';
import '../../domain/permission_mode.dart';
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
                border: Border(
                  bottom: BorderSide(color: AppTheme.border),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // X icon 24x24 #6B6F76
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(LucideIcons.x,
                        size: 24, color: AppTheme.textSecondary),
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

                            // Permission Mode Section: gap 8, vertical
                            _buildFieldLabel('Permission Mode'),
                            const SizedBox(height: 8),
                            Obx(() => _buildPermissionModeGrid()),
                            const SizedBox(height: 24),

                            // Prompt Section: gap 8, vertical
                            _buildFieldLabel('Initial Prompt'),
                            const SizedBox(height: 8),
                            _buildPromptInput(),
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
            const Icon(LucideIcons.monitor,
                size: 16, color: AppTheme.textTertiary),
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
            const Icon(LucideIcons.chevronRight,
                size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  // Permission mode 2x2 grid
  Widget _buildPermissionModeGrid() {
    const modes = [
      PermissionMode.bypassPermissions,
      PermissionMode.defaultMode,
      PermissionMode.acceptEdits,
      PermissionMode.plan,
    ];

    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Padding(
            padding: EdgeInsets.only(top: row > 0 ? 8 : 0),
            child: Row(
              children: [
                for (var col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _buildModeChip(modes[row * 2 + col]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildModeChip(PermissionMode mode) {
    final isSelected = controller.selectedMode.value == mode;
    return GestureDetector(
      onTap: () => controller.selectMode(mode),
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
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: mode.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              mode.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
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
              final isOnline =
                  controller.isMachineConnected(machine.machineId);
              final name = machine.hostname ?? 'Unknown host';
              return ListTile(
                enabled: isOnline,
                leading: const Icon(LucideIcons.monitor,
                    size: 20, color: AppTheme.textSecondary),
                title: Text(
                  name,
                  style: GoogleFonts.inter(
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
        color: online
            ? AppTheme.successText
            : AppTheme.textTertiary,
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
          border: isOpen
              ? Border.all(color: AppTheme.primary, width: 2)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Input row — always at index 0 to preserve focus
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.folder,
                      size: 16, color: AppTheme.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller.cwdController,
                      focusNode: controller.cwdFocusNode,
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
                ],
              ),
            ),
            // Dropdown — conditionally shown below the input
            if (isOpen) ...[
              const Divider(
                  height: 1, thickness: 1, color: AppTheme.border),
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
                          padding:
                              const EdgeInsets.fromLTRB(12, 4, 12, 6),
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
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.folder,
                                  size: 14,
                                  color: Color(0xFF9CA0A8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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

  // Prompt input: cornerRadius 8, fill #EDEEF1, height 80, padding [10, 12]
  Widget _buildPromptInput() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller.promptController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        autocorrect: false,
        enableSuggestions: false,
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
          // Placeholder: "Describe what you want to do...", Inter 14 normal #C8CBD0
          hintText: 'Describe what you want to do...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  // Create Button: cornerRadius 8, fill #1D1D1F, height 48, center
  // Text: "Start Session", Inter 15 w600 #FFFFFF
  Widget _buildCreateButton() {
    return Obx(() => GestureDetector(
      onTap: controller.selectedMachine.value != null &&
              !controller.isLoading.value
          ? controller.startSession
          : null,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: controller.selectedMachine.value != null &&
                  !controller.isLoading.value
              ? AppTheme.primary
              : AppTheme.border,
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
                  color: controller.selectedMachine.value != null
                      ? Colors.white
                      : AppTheme.textTertiary,
                ),
              ),
      ),
    ));
  }
}
