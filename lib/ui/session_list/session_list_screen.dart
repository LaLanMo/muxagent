import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../domain/session.dart';
import '../common/empty_state.dart';
import '../common/status_indicator.dart';
import 'session_list_viewmodel.dart';

class SessionListScreen extends GetView<SessionListViewModel> {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'MuxAgent',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppTheme.textPrimary),
            onPressed: controller.navigateToNewSession,
            tooltip: 'New session',
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            onPressed: controller.navigateToSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Obx(() => _buildBody()),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sessions section
          _buildSectionLabel('SESSIONS'),
          const SizedBox(height: 12),
          _buildSessionsSection(),
          const SizedBox(height: 24),
          Divider(color: AppTheme.border),
          const SizedBox(height: 24),
          // Machines section
          _buildSectionLabel('MACHINES'),
          const SizedBox(height: 12),
          _buildMachinesSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildSessionsSection() {
    if (controller.sessions.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        message: 'No sessions yet',
        subtitle: 'Tap + to start a new session',
      );
    }

    return Column(
      children: controller.sessions
          .map((session) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildSessionCard(session),
              ))
          .toList(),
    );
  }

  Widget _buildSessionCard(AgentSession session) {
    // Try to find the machine for this session from metadata
    final machineId = session.metadata?['machineId'] as String? ?? '';

    return GestureDetector(
      onTap: () => controller.navigateToChat(session.id, machineId),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.title.isNotEmpty ? session.title : 'Untitled',
                    style: GoogleFonts.newsreader(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusIndicator.sessionStatus(session.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (machineId.isNotEmpty) ...[
                  Icon(
                    Icons.computer,
                    size: 12,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _machineDisplayName(machineId),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(session.updatedAt),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _machineDisplayName(String machineId) {
    for (final machine in controller.machines) {
      if (machine.machineId == machineId) {
        return machine.hostname ?? machineId;
      }
    }
    return machineId;
  }

  Widget _buildMachinesSection() {
    if (controller.machines.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Get.toNamed('/scan'),
          icon: Icon(Icons.add, color: AppTheme.textPrimary),
          label: Text(
            'Add machine',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppTheme.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    }

    return Column(
      children: controller.machines
          .map((machine) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMachineCard(machine),
              ))
          .toList(),
    );
  }

  Widget _buildMachineCard(dynamic machine) {
    final isConnected =
        controller.isMachineConnected(machine.machineId as String);
    final hostname = machine.hostname as String?;
    final machineId = machine.machineId as String;

    return GestureDetector(
      onTap: () {
        if (!isConnected) {
          controller.connectMachine(machine);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isConnected ? AppTheme.primary : AppTheme.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (hostname != null && hostname.isNotEmpty)
                        ? hostname
                        : 'Unknown host',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    machineId,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
