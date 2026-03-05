import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../domain/enums.dart';
import '../../domain/session.dart';
import '../../utils/app_toast.dart';
import 'history_tab_viewmodel.dart';
import 'main_shell_viewmodel.dart';

class HistoryTab extends GetView<HistoryTabViewModel> {
  const HistoryTab({super.key});

  MainShellViewModel get shell => Get.find<MainShellViewModel>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header — height 56, padding [0, 16], alignItems center
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: Text(
            'History',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        // Filter chips
        Obx(() => _buildFilterChips()),
        // Session list — fill_container height, clip true
        Expanded(
          child: Obx(() => _buildBody()),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final machines = shell.machines;
    final selected = controller.selectedMachineFilter.value;

    // padding [0, 16, 8, 16] = top:0, right:16, bottom:8, left:16
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip('All', selected == null, () {
              controller.setMachineFilter(null);
            }),
            const SizedBox(width: 8),
            ...machines.map((m) {
              final name = m.hostname ?? m.machineId;
              final isSelected = selected == m.machineId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(name, isSelected, () {
                  controller.setMachineFilter(m.machineId);
                }),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    // Selected: cornerRadius 16, fill #1D1D1F, padding [6,14], text Inter 13px w500 #FFFFFF
    // Unselected: cornerRadius 16, fill transparent, padding [6,14], border 1px #E0E2E6, text Inter 13px w500 #6B6F76
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? null
              : Border.all(color: AppTheme.chipBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Access reactive machine state so Obx tracks changes
    // (ListView.builder's itemBuilder runs outside Obx context)
    shell.machines.length;
    shell.activeSessionIds.length;
    final groups = controller.sessionGroups;

    if (groups.isEmpty) {
      final hasFilter = controller.selectedMachineFilter.value != null;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasFilter ? 'No sessions found' : 'No completed sessions yet',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 4),
              Text(
                'Try selecting a different machine',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Flatten groups into a list of items (headers + rows)
    final items = <_ListItem>[];
    for (final group in groups) {
      items.add(_ListItem.header(group.label));
      for (final session in group.sessions) {
        items.add(_ListItem.session(session));
      }
    }

    return ListView.builder(
      clipBehavior: Clip.hardEdge,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item.isHeader) {
          // Date Label: padding [12, 16, 4, 16], text Inter 13px w500 #808690
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              item.headerLabel!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary,
              ),
            ),
          );
        }
        return _buildSessionRow(item.session!);
      },
    );
  }

  Widget _buildSessionRow(AgentSession session) {
    final machineId = session.metadata?['machineId'] as String? ?? '';
    final cwd = session.metadata?['cwd'] as String? ?? '';
    final title = session.title.isNotEmpty ? session.title : 'Untitled';

    return GestureDetector(
      onTap: () {
        if (machineId.isNotEmpty && !shell.isMachineConnected(machineId)) {
          AppToast.show('Machine is offline');
          return;
        }
        shell.navigateToChat(session.id, machineId, cwd, title);
      },
      child: Container(
        // Session Row: padding [14, 16], bottom border inside #E5E7EB thickness 1
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.border),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status Dot: 12x12 ellipse
            _buildStatusDot(session.status),
            // gap 12
            const SizedBox(width: 12),
            // Text Stack: vertical layout, gap 2, fill_container width
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Name: Inter 15px w500 #1D1D1F
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Working Directory: Inter 13px normal #808690
                  Text(
                    cwd.isNotEmpty ? cwd : '~',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Machine name: Inter 12px normal #C8CBD0
                  if (machineId.isNotEmpty)
                    Text(
                      shell.machineDisplayName(machineId),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a 12x12 status dot based on session status.
  /// Running: filled #4CB782
  /// Approval: filled #E8B730
  /// Error: filled #E5484D
  /// Idle/Done: stroke only, #C8CBD0 thickness 1.5 (hollow circle)
  Widget _buildStatusDot(SessionStatus status) {
    final bool isHollow =
        status == SessionStatus.idle || status == SessionStatus.done;

    Color dotColor;
    switch (status) {
      case SessionStatus.running:
        dotColor = AppTheme.successText;
      case SessionStatus.waitingApproval:
        dotColor = AppTheme.warning;
      case SessionStatus.error:
        dotColor = AppTheme.errorText;
      case SessionStatus.idle:
      case SessionStatus.done:
        dotColor = AppTheme.textMuted;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isHollow ? null : dotColor,
        shape: BoxShape.circle,
        border: isHollow ? Border.all(color: dotColor, width: 1.5) : null,
      ),
    );
  }

}

class _ListItem {
  final bool isHeader;
  final String? headerLabel;
  final AgentSession? session;

  _ListItem.header(this.headerLabel)
      : isHeader = true,
        session = null;

  _ListItem.session(this.session)
      : isHeader = false,
        headerLabel = null;
}
