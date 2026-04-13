import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
import 'widgets/run_diff_summary_card.dart';
import 'widgets/tool_call_card.dart';
import 'widgets/tool_group_card.dart';

class ChatScreen extends GetView<ChatViewModel> {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await controller.prepareForClose()) {
          Get.back(result: result);
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            // Header
            _buildHeader(),

            // Mode dropdown panel
            Obx(() {
              if (!controller.hasModeOptions ||
                  !controller.showModeDropdown.value) {
                return const SizedBox.shrink();
              }
              return _buildModeDropdown();
            }),

            // Connection banner
            Obx(() => _buildConnectionBanner(controller.connState.value)),
            Obx(() => _buildUiModeBanner(controller.uiMode.value)),

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
                    final uiMode = controller.uiMode.value;
                    if (uiMode == ChatUiMode.initialLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      );
                    }
                    if (uiMode == ChatUiMode.unsupported) {
                      return Center(
                        child: Text(
                          'This session cannot be restored on this device yet.',
                          style: AppTypography.sans(
                            fontSize: 14,
                            color: AppTheme.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final allMessages = controller.messages;
                    final pendingApprovals = controller.approvals.values
                        .toList();

                    // Track which approvals get rendered inline with their tool card
                    final renderedApprovalIds = <String>{};

                    // Pre-build message widgets with run diff summary cards
                    // inserted at run boundaries.
                    final isRunning =
                        controller.sessionStatus.value == SessionStatus.running;
                    final messageWidgets = <Widget>[];
                    String? lastUserMessageId;

                    // Pre-compute which runs have a diff summary so we can
                    // fold inline diffs on their edit tool cards.
                    final runsWithSummary = <String>{};
                    {
                      String? prevUserId;
                      for (final msg in allMessages) {
                        if (msg.role == MessageRole.user) {
                          if (prevUserId != null &&
                              controller.chatState.runDiffSummaryAfter(
                                    prevUserId,
                                  ) !=
                                  null) {
                            runsWithSummary.add(prevUserId);
                          }
                          prevUserId = msg.id;
                        }
                      }
                      if (prevUserId != null &&
                          !isRunning &&
                          controller.chatState.runDiffSummaryAfter(
                                prevUserId,
                              ) !=
                              null) {
                        runsWithSummary.add(prevUserId);
                      }
                    }

                    for (var i = 0; i < allMessages.length; i++) {
                      final msg = allMessages[i];
                      final isLast = i == allMessages.length - 1;

                      // Before each user message (except the first), insert a
                      // diff summary card for the preceding run if it had edits.
                      if (msg.role == MessageRole.user &&
                          lastUserMessageId != null) {
                        final summary = controller.chatState
                            .runDiffSummaryAfter(lastUserMessageId);
                        if (summary != null) {
                          messageWidgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: RunDiffSummaryCard(summary: summary),
                            ),
                          );
                        }
                      }

                      if (msg.role == MessageRole.user) {
                        lastUserMessageId = msg.id;
                      }

                      messageWidgets.add(
                        _buildMessageItem(
                          msg,
                          pendingApprovals,
                          renderedApprovalIds,
                          isStreaming: isLast && isRunning,
                          foldEditDiffs:
                              msg.role != MessageRole.user &&
                              lastUserMessageId != null &&
                              runsWithSummary.contains(lastUserMessageId),
                        ),
                      );
                    }

                    // Trailing run: show diff summary after the last user
                    // message if the session is idle (run completed).
                    if (lastUserMessageId != null && !isRunning) {
                      final summary = controller.chatState.runDiffSummaryAfter(
                        lastUserMessageId,
                      );
                      if (summary != null) {
                        messageWidgets.add(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: RunDiffSummaryCard(summary: summary),
                          ),
                        );
                      }
                    }

                    final unlinkedApprovals = pendingApprovals
                        .where((a) => !renderedApprovalIds.contains(a.id))
                        .toList();
                    final itemCount =
                        messageWidgets.length + unlinkedApprovals.length;

                    if (itemCount == 0) {
                      return const SizedBox.expand();
                    }

                    return ListView.builder(
                      controller: controller.scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        final forwardIndex = itemCount - 1 - index;
                        if (forwardIndex < messageWidgets.length) {
                          return messageWidgets[forwardIndex];
                        }
                        final approvalIndex =
                            forwardIndex - messageWidgets.length;
                        final approval = unlinkedApprovals[approvalIndex];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: approval.kind == 'switch_mode'
                              ? PlanApprovalCard(
                                  approval: approval,
                                  enabled: controller.canReplyApprovals,
                                  onReply: (optionId) => controller
                                      .replyApproval(approval.id, optionId),
                                )
                              : PermissionCard(
                                  approval: approval,
                                  enabled: controller.canReplyApprovals,
                                  onReply: (optionId) => controller
                                      .replyApproval(approval.id, optionId),
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
                composerEnabled: controller.canPrompt,
                canCancel: controller.canCancelRun,
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
            border: Border(bottom: BorderSide(color: AppTheme.borderStrong)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (await controller.prepareForClose()) {
                      Get.back();
                    }
                  },
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      LucideIcons.chevronLeft,
                      size: 20,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Obx(
                  () => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (controller.cwd.isNotEmpty)
                        Text(
                          _formatHeaderPath(controller.cwd),
                          style: AppTypography.mono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            height: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (controller.cwd.isNotEmpty) const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildStatusPill(controller.sessionStatus.value),
                          if (controller.hasModeOptions &&
                              controller.currentMode.value != null)
                            GestureDetector(
                              onTap: controller.canOpenModeDropdown
                                  ? controller.toggleModeDropdown
                                  : null,
                              child: _buildModePill(
                                controller.currentMode.value!,
                                showChevron: controller.canOpenModeDropdown,
                                isOpen: controller.showModeDropdown.value,
                                isLoading: controller.isChangingMode.value,
                              ),
                            ),
                          if (!controller.showModeDropdown.value &&
                              controller.currentModel.value
                                      ?.trim()
                                      .isNotEmpty ==
                                  true)
                            _buildModelPill(controller.currentModel.value!),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Get.toNamed(Routes.sessionSettings),
                  child: const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      LucideIcons.settings,
                      size: 18,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(SessionStatus status) {
    final (dotColor, bgColor, label) = switch (status) {
      SessionStatus.running => (
        AppTheme.successText,
        AppTheme.successBg,
        'running',
      ),
      SessionStatus.waitingApproval => (
        const Color(0xFF8B6D24),
        AppTheme.warningBg,
        'approval',
      ),
      SessionStatus.error => (AppTheme.errorText, AppTheme.errorBg, 'error'),
      SessionStatus.done ||
      SessionStatus.idle => (AppTheme.textSecondary, AppTheme.idleBg, 'idle'),
    };

    return _buildInfoPill(
      label: label,
      dotColor: dotColor,
      background: bgColor,
    );
  }

  Widget _buildUiModeBanner(ChatUiMode mode) {
    if (mode == ChatUiMode.normal || mode == ChatUiMode.initialLoading) {
      return const SizedBox.shrink();
    }

    final (background, foreground, text) = switch (mode) {
      ChatUiMode.rebuildingReadonly => (
        AppTheme.warningBg,
        AppTheme.warning,
        'Refreshing chat history. Actions are temporarily disabled.',
      ),
      ChatUiMode.viewOnly => (
        AppTheme.idleBg,
        AppTheme.textSecondary,
        'Showing cached history. Reconnect to continue this conversation.',
      ),
      ChatUiMode.unsupported => (
        AppTheme.errorBg,
        AppTheme.errorText,
        'This session cannot be restored from daemon state here.',
      ),
      ChatUiMode.initialLoading ||
      ChatUiMode.normal => (Colors.transparent, Colors.transparent, ''),
    };

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: background,
        child: Text(
          text,
          style: AppTypography.sans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: foreground,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildModePill(
    ModeOption mode, {
    bool showChevron = false,
    bool isOpen = false,
    bool isLoading = false,
  }) {
    return _buildModeTagPill(
      label: mode.label,
      dotColor: _modeTagColor(mode),
      foreground: _modeTagColor(mode),
      background: _modeBgColor(mode),
      showChevron: showChevron,
      isOpen: isOpen,
      isLoading: isLoading,
    );
  }

  Widget _buildModelPill(String value) {
    final label = _resolveModelLabel(value);
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return _buildTextPill(
      label: label,
      foreground: AppTheme.accent,
      background: const Color(0xFFFEE8D6),
    );
  }

  Widget _buildModeDropdown() {
    if (!controller.canOpenModeDropdown) {
      return const SizedBox.shrink();
    }
    final modes = controller.availableModes.toList();
    if (modes.isEmpty) {
      return const SizedBox.shrink();
    }
    final current = controller.currentMode.value ?? modes.first;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(
          left: BorderSide(color: AppTheme.borderStrong),
          right: BorderSide(color: AppTheme.borderStrong),
          bottom: BorderSide(color: AppTheme.borderStrong),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < modes.length; i++)
            _buildModeRow(modes[i], modes[i].id == current.id, isFirst: i == 0),
        ],
      ),
    );
  }

  Widget _buildModeRow(
    ModeOption mode,
    bool isSelected, {
    bool isFirst = false,
  }) {
    final isBusy = controller.isChangingMode.value;
    final dotColor = _modeDropdownDotColor(mode);

    return GestureDetector(
      onTap: isBusy ? null : () => controller.changeMode(mode),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isBusy && !isSelected ? 0.65 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: isFirst
                ? null
                : const Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: AppTypography.sans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    if ((mode.description?.trim() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        mode.description!.trim(),
                        style: AppTypography.sans(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textTertiary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isBusy && isSelected)
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.textPrimary,
                    ),
                  ),
                )
              else if (isSelected)
                const Icon(
                  LucideIcons.check,
                  size: 14,
                  color: AppTheme.textPrimary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _modeTagColor(ModeOption mode) {
    switch (mode.id) {
      case 'bypassPermissions':
      case 'full-access':
        return AppTheme.accent;
      case 'acceptEdits':
      case 'autoEdit':
        return AppTheme.successText;
      case 'yolo':
      case 'dontAsk':
        return AppTheme.accent;
      case 'plan':
        return const Color(0xFF7C3AED);
      case 'read-only':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  static Color _modeDropdownDotColor(ModeOption mode) {
    switch (mode.id) {
      case 'bypassPermissions':
      case 'full-access':
        return const Color(0xFFD46F61);
      case 'default':
      case 'auto':
        return AppTheme.textPrimary;
      case 'acceptEdits':
        return const Color(0xFF2563EB);
      case 'autoEdit':
        return AppTheme.successText;
      case 'plan':
        return const Color(0xFF7C3AED);
      case 'read-only':
        return AppTheme.textSecondary;
      case 'yolo':
      case 'dontAsk':
        return AppTheme.accent;
      default:
        return AppTheme.textSecondary;
    }
  }

  static Color _modeBgColor(ModeOption mode) {
    switch (mode.id) {
      case 'bypassPermissions':
      case 'full-access':
        return const Color(0xFFFEE8D6);
      case 'plan':
        return const Color(0xFFEDE0FA);
      case 'acceptEdits':
      case 'autoEdit':
        return AppTheme.modeAcceptBg;
      case 'yolo':
      case 'dontAsk':
        return AppTheme.modeSkipBg;
      case 'read-only':
        return AppTheme.inputFill;
      default:
        return AppTheme.idleBg;
    }
  }

  Widget _buildMessageItem(
    Message message,
    List<ApprovalRequest> pendingApprovals,
    Set<String> renderedApprovalIds, {
    bool isStreaming = false,
    bool foldEditDiffs = false,
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

    // Agent messages: render per-part with reasoning merging + tool grouping
    final StringBuffer reasoningBuf = StringBuffer();
    final toolBuffer = <ToolActivity>[];

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

    // Track remaining parts to determine if a tool group is the last content
    int partsRemaining = message.parts.length;

    void flushToolGroup() {
      if (toolBuffer.isEmpty) return;
      if (toolBuffer.length < 2) {
        // Single tool: render as normal ToolCallCard
        final tool = toolBuffer.first;
        final childTools = controller.chatState.childToolsOf(tool.id);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ToolCallCard(
              key: ValueKey('tc-${tool.id}'),
              tool: tool,
              childTools: childTools,
              foldDiff: foldEditDiffs,
            ),
          ),
        );
      } else {
        // 2+ tools: render as collapsed/expandable ToolGroupCard
        final isLastContent = partsRemaining == 0;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ToolGroupCard(
              key: ValueKey('tg-${toolBuffer.first.id}'),
              tools: List.of(toolBuffer),
              initiallyExpanded: isStreaming && isLastContent,
            ),
          ),
        );
      }
      toolBuffer.clear();
    }

    void renderLinkedApproval(ToolActivity tool) {
      final linkedApproval = pendingApprovals
          .cast<ApprovalRequest?>()
          .firstWhere(
            (a) => a!.toolCallId != null && a.toolCallId == tool.id,
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
                    enabled: controller.canReplyApprovals,
                    onReply: (optionId) =>
                        controller.replyApproval(linkedApproval.id, optionId),
                  )
                : PermissionCard(
                    approval: linkedApproval,
                    enabled: controller.canReplyApprovals,
                    onReply: (optionId) =>
                        controller.replyApproval(linkedApproval.id, optionId),
                  ),
          ),
        );
      }
    }

    bool shouldBreakGroup(ToolActivity tool) {
      // Edit tools always standalone (preserve inline diff preview)
      if (tool.effectiveKind == ToolKind.edit) return true;
      // Tools with pending approval must be visible
      if (pendingApprovals.any(
        (a) => a.toolCallId != null && a.toolCallId == tool.id,
      )) {
        return true;
      }
      // Subagent parent tools already have their own aggregation
      if (controller.chatState.childToolsOf(tool.id).isNotEmpty) return true;
      return false;
    }

    for (final part in message.parts) {
      partsRemaining--;
      switch (part.type) {
        case PartType.reasoning:
          flushToolGroup();
          if (part.text != null && part.text!.isNotEmpty) {
            reasoningBuf.write(part.text!);
          }

        case PartType.text:
        case PartType.media:
          flushToolGroup();
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
            if (shouldBreakGroup(part.tool!)) {
              // Flush any accumulated group, then render standalone
              flushToolGroup();
              final childTools = controller.chatState.childToolsOf(
                part.tool!.id,
              );
              widgets.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ToolCallCard(
                    key: ValueKey('tc-${part.tool!.id}'),
                    tool: part.tool!,
                    childTools: childTools,
                    foldDiff: foldEditDiffs,
                  ),
                ),
              );
              renderLinkedApproval(part.tool!);
            } else {
              // Groupable tool: accumulate into buffer
              toolBuffer.add(part.tool!);
            }
          }

        default:
          flushToolGroup();
          flushReasoning();
          break;
      }
    }
    flushToolGroup();
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

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Container(
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
              style: AppTypography.sans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required String label,
    required Color dotColor,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: background,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.mono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPill({
    required String label,
    required Color foreground,
    required Color background,
    bool showChevron = false,
    bool isOpen = false,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: background,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.mono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: foreground,
            ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 6),
            SizedBox.square(
              dimension: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            ),
          ],
          if (showChevron) ...[
            const SizedBox(width: 4),
            Icon(
              isOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 11,
              color: foreground,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeTagPill({
    required String label,
    required Color dotColor,
    required Color foreground,
    required Color background,
    bool showChevron = false,
    bool isOpen = false,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: background,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.mono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: foreground,
            ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 6),
            SizedBox.square(
              dimension: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            ),
          ],
          if (showChevron) ...[
            const SizedBox(width: 4),
            Icon(
              isOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 10,
              color: foreground,
            ),
          ],
        ],
      ),
    );
  }

  String _formatHeaderPath(String cwd) {
    final trimmed = cwd.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final homeMatch = RegExp(r'^/(Users|home)/[^/]+').firstMatch(trimmed);
    final replaced = homeMatch == null
        ? trimmed
        : trimmed.replaceRange(0, homeMatch.group(0)!.length, '~');
    final segments = replaced.split('/').where((segment) => segment.isNotEmpty);
    final segmentList = segments.toList();
    if (!replaced.startsWith('~/') && segmentList.length > 4) {
      return '\u2026/${segmentList.sublist(segmentList.length - 3).join('/')}';
    }
    return replaced;
  }

  String _resolveModelLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    for (final model in controller.availableModels) {
      if (model.value == trimmed) {
        final name = model.name.trim();
        if (name.isNotEmpty) {
          return name;
        }
      }
    }
    return trimmed;
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
            color: AppTheme.surface,
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
                style: AppTypography.sans(
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
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.borderStrong)),
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
                    style: AppTypography.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completed / $total',
                    style: AppTypography.sans(
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
              style: AppTypography.sans(
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
    final textStyle = AppTypography.sans(
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
