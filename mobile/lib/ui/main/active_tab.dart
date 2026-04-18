import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../domain/enums.dart';
import '../../config/theme.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../domain/paired_machine.dart';
import '../../domain/session.dart';
import '../common/relay_status_pill.dart';
import '../common/status_indicator.dart';
import '../common/pill_tab_bar.dart';
import 'active_tab_viewmodel.dart';
import 'main_shell_viewmodel.dart';

class ActiveTab extends GetView<ActiveTabViewModel> {
  const ActiveTab({super.key});

  MainShellViewModel get shell => Get.find<MainShellViewModel>();
  WsSessionRepository get wsRepo => Get.find<WsSessionRepository>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Active',
                style: AppTypography.sans(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const RelayStatusPill(),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<PairedMachine>>(
            valueListenable: shell.machinesListenable,
            builder: (context, machines, _) {
              return Obx(() {
                controller.activeSessions.length;

                if (controller.activeSessions.isEmpty) {
                  return _buildEmptyState(machines);
                }
                return _buildSessionList(context, machines);
              });
            },
          ),
        ),
      ],
    );
  }

  // --- Empty State ---

  Widget _buildEmptyState(List<PairedMachine> machines) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle2, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'All clear',
              style: AppTypography.sans(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 280,
              child: Text(
                'No sessions need your attention right now.',
                style: AppTypography.mono(
                  fontSize: 12,
                  color: AppTheme.textMetadata,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<Set<String>>(
              valueListenable: wsRepo.activeSessionIdsListenable,
              builder: (context, activeSessionIds, _) => _buildMachineCard(
                machines: machines,
                activeSessionIds: activeSessionIds,
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              label: 'Start New Session',
              button: true,
              child: GestureDetector(
                onTap: shell.navigateToNewSession,
                child: Text(
                  'Start New Session',
                  style: AppTypography.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMachineCard({
    required List<PairedMachine> machines,
    required Set<String> activeSessionIds,
  }) {
    if (machines.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < machines.length; i++) ...[
            _buildMachineRow(
              machines[i],
              connected: activeSessionIds.contains(machines[i].machineId),
            ),
            if (i < machines.length - 1)
              const Divider(height: 0, thickness: 1, color: AppTheme.border),
          ],
        ],
      ),
    );
  }

  Widget _buildMachineRow(PairedMachine machine, {required bool connected}) {
    return GestureDetector(
      onTap: connected ? null : () => shell.connectMachine(machine),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(LucideIcons.monitor, size: 18, color: AppTheme.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                machine.hostname ?? machine.machineId,
                style: AppTypography.sans(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildStatusPill(connected),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(bool connected) {
    if (connected) return const StatusIndicator.online();
    return const StatusIndicator.offline();
  }

  // --- Session List (grouped by status sections) ---

  Widget _buildSessionList(BuildContext context, List<PairedMachine> machines) {
    final sessions = controller.activeSessions;

    final approvalSessions = sessions
        .where((s) => s.status == SessionStatus.waitingApproval)
        .toList();
    final runningSessions = sessions
        .where((s) => s.status == SessionStatus.running)
        .toList();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        PillTabBar.reservedHeightFor(context),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (approvalSessions.isNotEmpty)
            _buildSection('APPROVAL', approvalSessions, machines),
          if (runningSessions.isNotEmpty)
            _buildSection('RUNNING', runningSessions, machines),
        ],
      ),
    );
  }

  Widget _buildSection(
    String label,
    List<AgentSession> sessions,
    List<PairedMachine> machines,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              label,
              style: AppTypography.mono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
          ...sessions.map((session) => _buildSessionRow(session, machines)),
        ],
      ),
    );
  }

  Widget _buildSessionRow(AgentSession session, List<PairedMachine> machines) {
    final machineId = session.machineId;
    final cwd = session.cwd;
    final title = session.title.isNotEmpty ? session.title : 'Untitled';

    return GestureDetector(
      onTap: () {
        shell.navigateToChat(
          session.id,
          machineId,
          session.runtime,
          cwd,
          title,
        );
      },
      child: Container(
        // padding [14, 0], alignItems center, gap 12
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          // Bottom border: stroke inside #E5E7EB, thickness bottom 1
          border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StatusIndicator.sessionStatus(session.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.sans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (cwd.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      cwd,
                      style: AppTypography.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  // Machine + Duration: system sans 12px normal #C8CBD0
                  Text(
                    _buildMachineDurationText(machineId, session, machines),
                    style: AppTypography.mono(
                      fontSize: 11,
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

  String _buildMachineDurationText(
    String machineId,
    AgentSession session,
    List<PairedMachine> machines,
  ) {
    final machineName = machineId.isNotEmpty
        ? _machineDisplayName(machines, machineId)
        : '';
    final duration = _formatDuration(session.updatedAt);

    if (machineName.isNotEmpty && duration.isNotEmpty) {
      return '$machineName \u00B7 $duration';
    }
    if (machineName.isNotEmpty) return machineName;
    if (duration.isNotEmpty) return duration;
    return '';
  }

  String _machineDisplayName(List<PairedMachine> machines, String machineId) {
    for (final machine in machines) {
      if (machine.machineId == machineId) {
        return machine.hostname ?? machineId;
      }
    }
    return machineId;
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
