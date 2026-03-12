import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/fonts.dart';
import '../../routing/routes.dart';
import '../../config/theme.dart';
import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/message.dart';
import '../../domain/mode_option.dart';
import '../../domain/plan_entry.dart';
import '../../domain/tool_activity.dart';
import 'chat_viewmodel.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/file_picker_panel.dart';
import 'widgets/permission_card.dart';
import 'widgets/plan_approval_card.dart';
import 'widgets/tool_call_card.dart';

class ChatScreen extends GetView<ChatViewModel> {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Mode dropdown panel
          Obx(() {
            if (!controller.hasModeOptions || !controller.showModeDropdown.value) {
              return const SizedBox.shrink();
            }
            return _buildModeDropdown();
          }),

          // Connection banner
          Obx(() => _buildConnectionBanner(controller.connState.value)),

          // Plan panel
          Obx(() {
            final entries = controller.planEntries;
            if (entries.isEmpty) return const SizedBox.shrink();
            return _PlanPanel(entries: entries);
          }),

          // Messages list
          Expanded(
            child: Stack(
              children: [
                Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  final allMessages = controller.messages;
                  final pendingApprovals = controller.approvals.values.toList();

                  // Track which approvals get rendered inline with their tool card
                  final renderedApprovalIds = <String>{};

                  // Pre-build message widgets so we can count unlinked approvals
                  final isRunning =
                      controller.sessionStatus.value == SessionStatus.running;
                  final messageWidgets = allMessages.asMap().entries.map((
                    entry,
                  ) {
                    final isLast = entry.key == allMessages.length - 1;
                    return _buildMessageItem(
                      entry.value,
                      pendingApprovals,
                      renderedApprovalIds,
                      isStreaming: isLast && isRunning,
                    );
                  }).toList();

                  final unlinkedApprovals = pendingApprovals
                      .where((a) => !renderedApprovalIds.contains(a.id))
                      .toList();
                  final itemCount =
                      messageWidgets.length + unlinkedApprovals.length;

                  if (itemCount == 0) {
                    return Center(
                      child: Text(
                        'Send a message to get started',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: controller.scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index < messageWidgets.length) {
                        return messageWidgets[index];
                      }
                      final approvalIndex = index - messageWidgets.length;
                      final approval = unlinkedApprovals[approvalIndex];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: approval.kind == 'switch_mode'
                            ? PlanApprovalCard(
                                approval: approval,
                                onReply: (optionId) => controller.replyApproval(
                                  approval.id,
                                  optionId,
                                ),
                              )
                            : PermissionCard(
                                approval: approval,
                                onReply: (optionId) => controller.replyApproval(
                                  approval.id,
                                  optionId,
                                ),
                              ),
                      );
                    },
                  );
                }),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Obx(() {
                    final visible = controller.showScrollToBottomButton.value;
                    return IgnorePointer(
                      ignoring: !visible,
                      child: AnimatedSlide(
                        offset: visible ? Offset.zero : const Offset(0, 1),
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: AnimatedOpacity(
                          opacity: visible ? 1 : 0,
                          duration: const Duration(milliseconds: 160),
                          child: Center(
                            child: _ScrollToBottomButton(
                              onTap: controller.animateToBottom,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // File picker panel
          Obx(() {
            if (!controller.showFilePicker.value) {
              return const SizedBox.shrink();
            }
            return FilePickerPanel(
              entries: controller.filePickerEntries.toList(),
              isSearchMode: controller.isFileSearchMode.value,
              isLoading: controller.filePickerLoading.value,
              onTap: controller.onFileEntryTap,
              onDrillDown: controller.onFileEntryDrillDown,
            );
          }),

          // Input bar
          Obx(() {
            final previews = controller.pendingPreviews.toList();
            return ChatInputBar(
              controller: controller.inputController,
              sessionStatus: controller.sessionStatus.value,
              onSend: () =>
                  controller.sendMessage(controller.inputController.text),
              onCancel: controller.cancelSession,
              onAttach: controller.pickImage,
              imagePreviews: previews,
              onRemoveImage: controller.removeImage,
              showMic: controller.hasSttConfig.value,
              isRecording: controller.isVoiceRecording.value,
              isTranscribing: controller.isTranscribing.value,
              onMicStart: controller.startVoiceInput,
              onMicStop: controller.stopVoiceInput,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: const Icon(
                  LucideIcons.chevronLeft,
                  size: 22,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(
                  () => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (controller.cwd.isNotEmpty)
                        Text(
                          controller.cwd,
                          style: AppFonts.code(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _buildStatusPill(controller.sessionStatus.value),
                          if (controller.hasModeOptions &&
                              controller.currentMode.value != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: controller.toggleModeDropdown,
                              child: _buildModePill(
                                controller.currentMode.value!,
                                showChevron: true,
                                isOpen: controller.showModeDropdown.value,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Get.toNamed(Routes.sessionSettings),
                child: const Icon(
                  LucideIcons.settings,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(SessionStatus status) {
    final Color dotColor;
    final Color bgColor;
    final String label;

    switch (status) {
      case SessionStatus.running:
        dotColor = AppTheme.successText;
        bgColor = AppTheme.successBg;
        label = 'running';
      case SessionStatus.waitingApproval:
        dotColor = AppTheme.warning;
        bgColor = AppTheme.warningBg;
        label = 'approval';
      case SessionStatus.error:
        dotColor = AppTheme.errorText;
        bgColor = AppTheme.errorBg;
        label = 'error';
      case SessionStatus.done:
      case SessionStatus.idle:
        dotColor = AppTheme.textSecondary;
        bgColor = AppTheme.idleBg;
        label = 'idle';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModePill(
    ModeOption mode, {
    bool showChevron = false,
    bool isOpen = false,
  }) {
    final dotColor = _modeColor(mode);
    final bgColor = _modeBgColor(mode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            mode.label.toLowerCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: dotColor,
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 4),
            Icon(
              isOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 12,
              color: dotColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeDropdown() {
    final modes = controller.availableModes.toList();
    if (modes.isEmpty) {
      return const SizedBox.shrink();
    }
    final current = controller.currentMode.value ?? modes.first;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: modes
            .map((m) => _buildModeRow(m, m.id == current.id))
            .toList(),
      ),
    );
  }

  Widget _buildModeRow(ModeOption mode, bool isSelected) {
    final bgColor = isSelected ? _modeBgColor(mode) : Colors.transparent;
    final accentColor = _modeColor(mode);
    final textColor = isSelected ? accentColor : AppTheme.textPrimary;

    return GestureDetector(
      onTap: () => controller.changeMode(mode),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              mode.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(LucideIcons.check, size: 14, color: accentColor),
            ],
            const Spacer(),
            Flexible(
              child: Text(
                _modeDescription(mode),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.7)
                      : AppTheme.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _modeColor(ModeOption mode) {
    switch (mode.id) {
      case 'bypassPermissions':
      case 'full-access':
        return AppTheme.errorText;
      case 'acceptEdits':
        return AppTheme.primary;
      case 'plan':
        return const Color(0xFF7C3AED);
      case 'dontAsk':
        return AppTheme.warning;
      case 'read-only':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  static Color _modeBgColor(ModeOption mode) {
    switch (mode.id) {
      case 'bypassPermissions':
      case 'full-access':
        return AppTheme.modeSkipBg;
      case 'plan':
        return AppTheme.modePlanBg;
      case 'acceptEdits':
        return AppTheme.modeAcceptBg;
      case 'read-only':
        return AppTheme.inputFill;
      default:
        return AppTheme.idleBg;
    }
  }

  static String _modeDescription(ModeOption mode) {
    if (mode.description?.isNotEmpty == true) {
      return mode.description!;
    }
    switch (mode.id) {
      case 'bypassPermissions':
      case 'full-access':
        return 'No safety checks';
      case 'default':
      case 'auto':
        return 'Ask for each action';
      case 'acceptEdits':
        return 'Auto-approve edits';
      case 'plan':
        return 'Plan before coding';
      case 'read-only':
        return 'Read only until approved';
      default:
        return '';
    }
  }

  Widget _buildMessageItem(
    Message message,
    List<ApprovalRequest> pendingApprovals,
    Set<String> renderedApprovalIds, {
    bool isStreaming = false,
  }) {
    final isUser = message.role == MessageRole.user;
    final widgets = <Widget>[];

    // For user messages, group all text+media parts into a single bubble
    if (isUser) {
      final contentParts = message.parts
          .where((p) => p.type == PartType.text || p.type == PartType.media)
          .toList();
      if (contentParts.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ChatMessageBubble(parts: contentParts, isUser: true),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: widgets,
      );
    }

    // Agent messages: render per-part with reasoning merging
    final StringBuffer reasoningBuf = StringBuffer();

    void flushReasoning({bool isLastPart = false}) {
      if (reasoningBuf.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _CollapsibleReasoningBlock(
              text: reasoningBuf.toString(),
              isStreaming: isStreaming && isLastPart,
            ),
          ),
        );
        reasoningBuf.clear();
      }
    }

    for (final part in message.parts) {
      switch (part.type) {
        case PartType.reasoning:
          if (part.text != null && part.text!.isNotEmpty) {
            reasoningBuf.write(part.text!);
          }

        case PartType.text:
        case PartType.media:
          flushReasoning();
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ChatMessageBubble(
                parts: [part],
                isUser: false,
                isStreaming: isStreaming,
              ),
            ),
          );

        case PartType.tool:
          flushReasoning();
          if (part.tool != null && !part.tool!.isChildTool) {
            final childTools = controller.chatState.childToolsOf(part.tool!.id);
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ToolCallCard(tool: part.tool!, childTools: childTools),
              ),
            );
            // If this tool has a pending approval, render it inline
            final linkedApproval = pendingApprovals
                .cast<ApprovalRequest?>()
                .firstWhere(
                  (a) => a!.toolCallId != null && a.toolCallId == part.tool!.id,
                  orElse: () => null,
                );
            if (linkedApproval != null) {
              renderedApprovalIds.add(linkedApproval.id);
              widgets.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: linkedApproval.kind == 'switch_mode'
                      ? PlanApprovalCard(
                          approval: linkedApproval,
                          onReply: (optionId) => controller.replyApproval(
                            linkedApproval.id,
                            optionId,
                          ),
                        )
                      : PermissionCard(
                          approval: linkedApproval,
                          onReply: (optionId) => controller.replyApproval(
                            linkedApproval.id,
                            optionId,
                          ),
                        ),
                ),
              );
            }
          }

        default:
          flushReasoning();
          break;
      }
    }
    flushReasoning(isLastPart: true);

    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildConnectionBanner(ConnState state) {
    if (state == ConnState.connected) return const SizedBox.shrink();

    final bool isDisconnected = state == ConnState.disconnected;
    final Color color = isDisconnected
        ? AppTheme.statusDisconnected
        : AppTheme.statusConnecting;
    final Color bg = isDisconnected
        ? AppTheme.disconnectedBg
        : AppTheme.warningBg;
    final IconData icon = isDisconnected
        ? LucideIcons.wifiOff
        : LucideIcons.loader;
    final String label = isDisconnected ? 'Connection lost' : 'Reconnecting...';

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
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScrollToBottomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.chevronsDown,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Jump to latest',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanPanel extends StatefulWidget {
  final List<PlanEntry> entries;
  const _PlanPanel({required this.entries});

  @override
  State<_PlanPanel> createState() => _PlanPanelState();
}

class _PlanPanelState extends State<_PlanPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final completed = widget.entries.where((e) => e.isCompleted).length;
    final total = widget.entries.length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          // Header row
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.listChecks,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Plan',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completed / $total',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 14,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
          ),

          // Entries list
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: widget.entries.map((e) => _buildEntry(e)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntry(PlanEntry entry) {
    final Widget icon;
    final Color textColor;
    final FontWeight fontWeight;

    if (entry.isCompleted) {
      icon = const Icon(
        LucideIcons.checkCircle2,
        size: 14,
        color: AppTheme.successText,
      );
      textColor = AppTheme.textTertiary;
      fontWeight = FontWeight.normal;
    } else if (entry.isInProgress) {
      icon = const Icon(
        LucideIcons.loader,
        size: 14,
        color: AppTheme.statusConnecting,
      );
      textColor = AppTheme.textPrimary;
      fontWeight = FontWeight.w500;
    } else {
      icon = Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.textTertiary, width: 1.5),
        ),
      );
      textColor = AppTheme.textSecondary;
      fontWeight = FontWeight.normal;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.content,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: fontWeight,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsibleReasoningBlock extends StatefulWidget {
  final String text;
  final bool isStreaming;

  const _CollapsibleReasoningBlock({
    required this.text,
    required this.isStreaming,
  });

  @override
  State<_CollapsibleReasoningBlock> createState() =>
      _CollapsibleReasoningBlockState();
}

class _CollapsibleReasoningBlockState
    extends State<_CollapsibleReasoningBlock> {
  bool _expanded = false;

  String get _lastLine {
    final trimmed = widget.text.trimRight();
    final idx = trimmed.lastIndexOf('\n');
    if (idx == -1) return trimmed;
    return trimmed.substring(idx + 1);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.inter(
      fontSize: 13,
      color: AppTheme.textTertiary,
      height: 1.5,
    );

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.border, width: 2)),
        ),
        child: _expanded
            ? Text(widget.text, style: textStyle)
            : Row(
                children: [
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _lastLine,
                      style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
