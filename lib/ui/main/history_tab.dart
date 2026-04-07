import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import '../../data/repositories/event_repository.dart';
import '../../domain/enums.dart';
import '../../domain/session.dart';
import '../common/relay_status_pill.dart';
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'History',
                style: AppTypography.sans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const RelayStatusPill(),
            ],
          ),
        ),
        // Filter chips
        Obx(() => _buildFilterChips()),
        // Session list — fill_container height, clip true
        Expanded(child: Obx(() => _buildBody())),
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
    // Selected: cornerRadius 16, fill #1D1D1F, padding [6,14], text system sans 13px w500 #FFFFFF
    // Unselected: cornerRadius 16, fill transparent, padding [6,14], border 1px #E0E2E6, text system sans 13px w500 #6B6F76
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: selected ? null : Border.all(color: AppTheme.chipBorder),
        ),
        child: Text(
          label,
          style: AppTypography.sans(
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
    final groups = controller.sessionGroups;

    if (groups.isEmpty) {
      final hasFilter = controller.selectedMachineFilter.value != null;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasFilter ? 'No sessions found' : 'No completed sessions yet',
              style: AppTypography.sans(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 4),
              Text(
                'Try selecting a different machine',
                style: AppTypography.sans(
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
          // Date Label: padding [12, 16, 4, 16], text system sans 13px w500 #808690
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              item.headerLabel!,
              style: AppTypography.sans(
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
    final machineId = session.machineId;
    final cwd = session.cwd;
    final title = session.title.isNotEmpty ? session.title : 'Untitled';

    return GestureDetector(
      onTap: () {
        Get.find<EventRepository>().markAsRead(session.id);
        shell.navigateToChat(session.id, machineId, cwd, title);
      },
      child: Container(
        // Session Row: padding [14, 16], bottom border inside #E5E7EB thickness 1
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Priority dot: 8x8
            _buildStatusDot(session),
            // gap 12
            const SizedBox(width: 12),
            // Text Stack: vertical layout, gap 2, fill_container width
            Expanded(
              child: Builder(
                builder: (_) {
                  final hasIndicator =
                      session.status == SessionStatus.waitingApproval ||
                      session.status == SessionStatus.running ||
                      !session.isRead;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.sans(
                          fontSize: 15,
                          fontWeight: hasIndicator
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: hasIndicator
                              ? AppTheme.textPrimary
                              : AppTheme.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cwd.isNotEmpty ? cwd : '~',
                        style: AppTypography.sans(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: hasIndicator
                              ? AppTheme.textTertiary
                              : const Color(0xFFAEB3BB),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (machineId.isNotEmpty)
                        Text(
                          shell.machineDisplayName(machineId),
                          style: AppTypography.sans(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: hasIndicator
                                ? AppTheme.textMuted
                                : const Color(0xFFD1D5DB),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Priority dot: approval (orange) > running (green) > unread (blue) > read (hidden).
  Widget _buildStatusDot(AgentSession session) {
    Color? dotColor;
    switch (session.status) {
      case SessionStatus.waitingApproval:
        dotColor = AppTheme.warning;
      case SessionStatus.running:
        dotColor = AppTheme.successText;
      case SessionStatus.error:
      case SessionStatus.idle:
      case SessionStatus.done:
        dotColor = session.isRead ? null : AppTheme.unreadDot;
    }

    return SizedBox(
      width: 8,
      height: 8,
      child: dotColor != null
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _ListItem {
  final bool isHeader;
  final String? headerLabel;
  final AgentSession? session;

  _ListItem.header(this.headerLabel) : isHeader = true, session = null;

  _ListItem.session(this.session) : isHeader = false, headerLabel = null;
}
