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
        Obx(() => _buildFilterChips()),
        Expanded(child: Obx(() => _buildBody())),
      ],
    );
  }

  Widget _buildFilterChips() {
    final machines = shell.machines;
    final selected = controller.selectedMachineFilter.value;

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

  Widget _buildBody() {
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
        return _buildSessionRow(item.session!);
      },
    );
  }

  Widget _buildSessionRow(AgentSession session) {
    final title = session.title.isNotEmpty ? session.title : 'Untitled';
    final isEmphasized =
        session.status == SessionStatus.waitingApproval ||
        session.status == SessionStatus.running ||
        !session.isRead;
    final statusStyle = _statusStyle(session);

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
            Container(
              width: 58,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: statusStyle.backgroundColor,
              child: Text(
                statusStyle.label,
                style: AppTypography.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusStyle.foregroundColor,
                ),
              ),
            ),
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
                    TextSpan(children: _buildMetaSpans(session)),
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

  List<InlineSpan> _buildMetaSpans(AgentSession session) {
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
        ? shell.machineDisplayName(session.machineId)
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

  _HistoryStatusStyle _statusStyle(AgentSession session) {
    switch (session.status) {
      case SessionStatus.waitingApproval:
        return const _HistoryStatusStyle(
          label: 'awaiting',
          foregroundColor: AppTheme.warning,
          backgroundColor: AppTheme.warningBg,
        );
      case SessionStatus.running:
        return const _HistoryStatusStyle(
          label: 'running',
          foregroundColor: AppTheme.successText,
          backgroundColor: AppTheme.successBg,
        );
      case SessionStatus.error:
        return const _HistoryStatusStyle(
          label: 'failed',
          foregroundColor: AppTheme.errorText,
          backgroundColor: AppTheme.errorBg,
        );
      case SessionStatus.idle:
      case SessionStatus.done:
        return const _HistoryStatusStyle(
          label: 'done',
          foregroundColor: AppTheme.statusNeutralText,
          backgroundColor: AppTheme.statusNeutralBg,
        );
    }
  }
}

class _ListItem {
  final bool isHeader;
  final String? headerLabel;
  final AgentSession? session;

  _ListItem.header(this.headerLabel) : isHeader = true, session = null;

  _ListItem.session(this.session) : isHeader = false, headerLabel = null;
}

class _HistoryStatusStyle {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _HistoryStatusStyle({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}
