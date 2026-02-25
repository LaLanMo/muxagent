import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../domain/enums.dart';
import '../../domain/message.dart';
import '../common/status_indicator.dart';
import 'chat_viewmodel.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/permission_card.dart';
import 'widgets/tool_call_card.dart';

class ChatScreen extends GetView<ChatViewModel> {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Get.back(),
        ),
        title: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.sessionTitle.value.isNotEmpty
                      ? controller.sessionTitle.value
                      : 'Chat',
                  style: GoogleFonts.newsreader(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )),
        actions: [
          Obx(() => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: StatusIndicator.sessionStatus(
                  controller.sessionStatus.value,
                ),
              )),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                );
              }

              final allMessages = controller.messages;
              final pendingApprovals = controller.approvals.values.toList();
              final itemCount = allMessages.length + pendingApprovals.length;

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index < allMessages.length) {
                    return _buildMessageItem(allMessages[index]);
                  }
                  final approvalIndex = index - allMessages.length;
                  final approval = pendingApprovals[approvalIndex];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PermissionCard(
                      approval: approval,
                      onReply: (optionId) =>
                          controller.replyApproval(approval.id, optionId),
                    ),
                  );
                },
              );
            }),
          ),

          // Input bar
          Obx(() => ChatInputBar(
                controller: controller.inputController,
                sessionStatus: controller.sessionStatus.value,
                onSend: () =>
                    controller.sendMessage(controller.inputController.text),
                onCancel: controller.cancelSession,
              )),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message message) {
    final isUser = message.role == MessageRole.user;
    final widgets = <Widget>[];

    for (final part in message.parts) {
      switch (part.type) {
        case PartType.text:
          if (part.text != null && part.text!.isNotEmpty) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChatMessageBubble(
                  text: part.text!,
                  isUser: isUser,
                ),
              ),
            );
          }

        case PartType.tool:
          if (part.tool != null) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ToolCallCard(tool: part.tool!),
              ),
            );
          }

        case PartType.reasoning:
          if (part.text != null && part.text!.isNotEmpty) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildReasoningBlock(part.text!),
              ),
            );
          }

        default:
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget _buildReasoningBlock(String text) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        'Reasoning',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.textTertiary,
        ),
      ),
      initiallyExpanded: false,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
