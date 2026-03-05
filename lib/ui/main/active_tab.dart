import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../domain/enums.dart';
import '../../config/theme.dart';
import '../../domain/session.dart';
import '../../utils/app_toast.dart';
import 'active_tab_viewmodel.dart';
import 'main_shell_viewmodel.dart';

class ActiveTab extends GetView<ActiveTabViewModel> {
  const ActiveTab({super.key});

  MainShellViewModel get shell => Get.find<MainShellViewModel>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header: height 56, padding [0, 16], spaceBetween
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Active',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: Obx(() {
            // Force reactivity tracking
            controller.activeSessions.length;
            shell.machines.length;
            shell.activeSessionIds.length;

            if (controller.activeSessions.isEmpty) {
              return _buildEmptyState();
            }
            return _buildSessionList();
          }),
        ),
      ],
    );
  }

  // --- Empty State ---

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Check icon: lucide circle-check, 48x48, #C8CBD0
            Icon(
              LucideIcons.checkCircle,
              size: 48,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            // Title: "All clear", Inter 20px w500 #6B6F76
            Text(
              'All clear',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Description: Inter 14px #808690, textAlign center, width 260
            SizedBox(
              width: 260,
              child: Text(
                'No sessions need your attention right now.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Machine section card
            Obx(() => _buildMachineCard()),
            const SizedBox(height: 16),
            // "Start New Session" text: Inter 15px w600 #1D1D1F (tappable text)
            GestureDetector(
              onTap: shell.navigateToNewSession,
              child: Text(
                'Start New Session',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMachineCard() {
    final machines = shell.machines;
    if (machines.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < machines.length; i++) ...[
            _buildMachineRow(machines[i]),
            if (i < machines.length - 1)
              const Divider(height: 0, thickness: 1, color: Color(0xFFEBEBEB)),
          ],
        ],
      ),
    );
  }

  Widget _buildMachineRow(dynamic machine) {
    final connected = shell.isMachineConnected(machine.machineId);
    return GestureDetector(
      onTap: connected ? null : () => shell.connectMachine(machine),
      child: Padding(
        // padding [14, 16], gap 10, alignItems center
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Monitor icon: lucide monitor, 18x18, #6B6F76
            const Icon(
              LucideIcons.monitor,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            // Machine name: Inter 14px normal #1D1D1F, fill_container
            Expanded(
              child: Text(
                machine.hostname ?? machine.machineId,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Status pill
            _buildStatusPill(connected),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(bool connected) {
    final dotColor =
        connected ? AppTheme.successText : AppTheme.textTertiary;
    final bgColor =
        connected ? AppTheme.successBg : AppTheme.idleBg;
    final label = connected ? 'online' : 'offline';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot 6x6
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          // Text: Inter 11px w500
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- Session List (grouped by status sections) ---

  Widget _buildSessionList() {
    final sessions = controller.activeSessions;

    // Group sessions by status
    final approvalSessions = sessions
        .where((s) => s.status == SessionStatus.waitingApproval)
        .toList();
    final runningSessions =
        sessions.where((s) => s.status == SessionStatus.running).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (approvalSessions.isNotEmpty)
            _buildSection('Approval', AppTheme.warning, approvalSessions),
          if (runningSessions.isNotEmpty)
            _buildSection('Running', AppTheme.successText, runningSessions),
        ],
      ),
    );
  }

  Widget _buildSection(
      String label, Color statusColor, List<AgentSession> sessions) {
    return Padding(
      // 32px top padding before each section
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header: padding [0, 0, 14, 0], justifyContent spaceBetween
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Label: Inter 15px w500, color = status color
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          // Session rows
          ...sessions.map((session) => _buildSessionRow(session, statusColor)),
        ],
      ),
    );
  }

  Widget _buildSessionRow(AgentSession session, Color statusColor) {
    final machineId = session.metadata?['machineId'] as String? ?? '';
    final cwd = session.metadata?['cwd'] as String? ?? '';
    final title = session.title.isNotEmpty ? session.title : 'Untitled';
    final isIdle = session.status == SessionStatus.idle;

    return GestureDetector(
      onTap: () {
        if (machineId.isNotEmpty && !shell.isMachineConnected(machineId)) {
          AppToast.show('Machine is offline');
          return;
        }
        shell.navigateToChat(session.id, machineId, cwd, title);
      },
      child: Container(
        // padding [14, 0], alignItems center, gap 12
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          // Bottom border: stroke inside #E5E7EB, thickness bottom 1
          border: Border(
            bottom: BorderSide(color: AppTheme.border, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status Dot: 12x12 ellipse
            _buildStatusDot(statusColor, isIdle),
            const SizedBox(width: 12),
            // Text Stack: vertical layout, gap 2
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
                  if (cwd.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    // Working Directory: Inter 13px normal #808690
                    Text(
                      cwd,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                        color: AppTheme.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  // Machine + Duration: Inter 12px normal #C8CBD0
                  Text(
                    _buildMachineDurationText(machineId, session),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
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

  Widget _buildStatusDot(Color color, bool isIdle) {
    if (isIdle) {
      // Idle = stroke-only (hollow circle), #C8CBD0, thickness 1.5
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.textMuted,
            width: 1.5,
          ),
        ),
      );
    }
    // Running/Approval = filled ellipse
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  String _buildMachineDurationText(String machineId, AgentSession session) {
    final machineName =
        machineId.isNotEmpty ? shell.machineDisplayName(machineId) : '';
    final duration = _formatDuration(session.updatedAt);

    if (machineName.isNotEmpty && duration.isNotEmpty) {
      return '$machineName \u00B7 $duration';
    }
    if (machineName.isNotEmpty) return machineName;
    if (duration.isNotEmpty) return duration;
    return '';
  }

  String _formatDuration(DateTime updatedAt) {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);

    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    }
    return 'now';
  }
}
