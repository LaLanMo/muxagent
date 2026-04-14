import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import '../../data/repositories/event_repository.dart';
import '../../domain/enums.dart';
import '../../domain/paired_machine.dart';
import '../../domain/session.dart';
import '../common/relay_status_pill.dart';
import '../common/status_indicator.dart';
import '../common/pill_tab_bar.dart';
import 'history_tab_viewmodel.dart';
import 'main_shell_viewmodel.dart';

class HistoryTab extends GetView<HistoryTabViewModel> {
  const HistoryTab({super.key});

  MainShellViewModel get shell => Get.find<MainShellViewModel>();

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
                'History',
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
        ValueListenableBuilder<List<PairedMachine>>(
          valueListenable: controller.machinesListenable,
          builder: (context, machines, _) {
            return Obx(
              () => _buildFilterChips(
                machines: machines,
                selected: controller.selectedMachineFilter.value,
              ),
            );
          },
        ),
        Expanded(
          child: ValueListenableBuilder<List<PairedMachine>>(
            valueListenable: controller.machinesListenable,
            builder: (context, machines, _) {
              return Obx(() => _buildBody(context, machines));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips({
    required List<PairedMachine> machines,
    required String? selected,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - 32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.selectedBg : Colors.transparent,
          border: selected ? null : Border.all(color: AppTheme.chipBorder),
        ),
        child: Text(
          label,
          style: AppTypography.mono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? AppTheme.surface : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<PairedMachine> machines) {
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
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 4),
              Text(
                'Try selecting a different machine',
                style: AppTypography.mono(
                  fontSize: 12,
                  color: AppTheme.textMetadata,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final items = <_ListItem>[];
    for (final group in groups) {
      items.add(_ListItem.header(group.label));
      for (final session in group.sessions) {
        items.add(_ListItem.session(session));
      }
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: PillTabBar.reservedHeightFor(context)),
      clipBehavior: Clip.hardEdge,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              item.headerLabel!.toUpperCase(),
              style: AppTypography.mono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: AppTheme.textTertiary,
              ),
            ),
          );
        }
        return _buildSessionRow(item.session!, machines);
      },
    );
  }

  Widget _buildSessionRow(AgentSession session, List<PairedMachine> machines) {
    final title = session.title.isNotEmpty ? session.title : 'Untitled';
    final isEmphasized =
        session.status == SessionStatus.waitingApproval ||
        session.status == SessionStatus.running ||
        !session.isRead;

    return GestureDetector(
      onTap: () {
        Get.find<EventRepository>().markAsRead(session.id);
        shell.navigateToChat(session.id, session.machineId, session.cwd, title);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
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
                      fontWeight: isEmphasized
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(children: _buildMetaSpans(session, machines)),
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

  List<InlineSpan> _buildMetaSpans(
    AgentSession session,
    List<PairedMachine> machines,
  ) {
    final spans = <InlineSpan>[
      TextSpan(
        text: session.cwd.isNotEmpty ? session.cwd : '~',
        style: AppTypography.mono(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppTheme.textTertiary,
        ),
      ),
    ];

    final machineName = session.machineId.isNotEmpty
        ? _machineDisplayName(machines, session.machineId)
        : null;
    if (machineName != null && machineName.isNotEmpty) {
      spans.addAll([
        _separatorSpan(),
        TextSpan(
          text: machineName,
          style: AppTypography.mono(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppTheme.textMuted,
          ),
        ),
      ]);
    }

    final relativeAge = _relativeAge(session.createdAt);
    if (relativeAge != null) {
      spans.addAll([
        _separatorSpan(),
        TextSpan(
          text: relativeAge,
          style: AppTypography.mono(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppTheme.textMuted,
          ),
        ),
      ]);
    }

    return spans;
  }

  String _machineDisplayName(List<PairedMachine> machines, String machineId) {
    for (final machine in machines) {
      if (machine.machineId == machineId) {
        return machine.hostname ?? machineId;
      }
    }
    return machineId;
  }

  InlineSpan _separatorSpan() {
    return TextSpan(
      text: ' · ',
      style: AppTypography.sans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppTheme.textMuted,
      ),
    );
  }

  String? _relativeAge(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays == 0) {
      return null;
    }
    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h';
    }
    final minutes = diff.inMinutes.clamp(1, 59);
    return '${minutes}m';
  }
}

class _ListItem {
  final bool isHeader;
  final String? headerLabel;
  final AgentSession? session;

  _ListItem.header(this.headerLabel) : isHeader = true, session = null;

  _ListItem.session(this.session) : isHeader = false, headerLabel = null;
}
