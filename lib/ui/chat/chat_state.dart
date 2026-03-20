import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/message.dart';
import '../../domain/plan_entry.dart';
import '../../domain/run_diff_summary.dart';
import '../../domain/tool_activity.dart';
import '../../utils/diff_utils.dart';

class _PendingPart {
  final String messageId;
  int partIndex;
  String partType;

  _PendingPart({
    required this.messageId,
    required this.partIndex,
    required this.partType,
  });
}

class ChatState {
  final String sessionId;
  final messages = <String, Message>{};
  final messageOrder = <String>[];
  final tools = <String, ToolActivity>{};
  final approvals = <String, ApprovalRequest>{};
  var planEntries = <PlanEntry>[];
  final _pendingParts = <String, _PendingPart>{};

  final _diffSummaryCache = <String, RunDiffSummary?>{};

  ChatState({required this.sessionId});

  void applyDelta(MessagePartEvent delta) {
    if (delta.messageId.isEmpty || delta.role == null) {
      return;
    }

    final messageId = delta.messageId;
    final partId = delta.partId.isEmpty
        ? 'part-${DateTime.now().microsecondsSinceEpoch}'
        : delta.partId;

    // Get or create message
    var msg = messages[messageId];
    if (msg == null) {
      msg = Message(
        id: messageId,
        sessionId: sessionId,
        role: delta.role!,
        parts: [],
        createdAt: DateTime.now(),
      );
      messages[messageId] = msg;
      if (!messageOrder.contains(messageId)) {
        messageOrder.add(messageId);
      }
    }

    // Find or create part
    var pending = _pendingParts[partId];
    if (pending == null) {
      // New part
      final part = MessagePart(
        type: PartType.fromValue(
          delta.partType.isEmpty ? 'text' : delta.partType,
        ),
        text: delta.fullText.isNotEmpty ? delta.fullText : delta.delta,
      );
      msg.parts.add(part);
      pending = _PendingPart(
        messageId: messageId,
        partIndex: msg.parts.length - 1,
        partType: delta.partType,
      );
      _pendingParts[partId] = pending;
    } else {
      // Update existing part
      final part = msg.parts[pending.partIndex];
      if (delta.fullText.isNotEmpty) {
        part.text = delta.fullText;
      } else {
        part.text = (part.text ?? '') + delta.delta;
      }
    }
  }

  void finalizeMessage(Message msg) {
    messages[msg.id] = msg;
    if (!messageOrder.contains(msg.id)) {
      messageOrder.add(msg.id);
    }
    // Clean up pending parts for this message
    _pendingParts.removeWhere((_, v) => v.messageId == msg.id);
  }

  void applyToolEvent(ToolEvent event) {
    // Update the tool in tools map
    var tool = tools[event.callId];
    if (tool == null) {
      tool = ToolActivity(
        id: event.callId,
        name: event.name,
        kind: event.kind,
        status: event.status,
        title: event.title,
        input: event.input,
        output: event.output,
        error: event.error,
        diffs: event.diffs,
        claudeCode: event.claudeCode,
        locations: event.locations,
      );
      tools[event.callId] = tool;
    } else {
      tool.status = event.status;
      if (event.kind != null) tool.kind = event.kind;
      if (event.output != null) tool.output = event.output;
      if (event.error != null) tool.error = event.error;
      if (event.title != null) tool.title = event.title;
      if (event.input != null) tool.input = event.input;
      if (event.diffs != null) tool.diffs = event.diffs;
      if (event.claudeCode != null) tool.claudeCode = event.claudeCode;
      if (event.locations != null) tool.locations = event.locations;
    }

    // Also update in message parts if present
    final messageId = event.messageId.isEmpty
        ? 'tool-${event.callId}'
        : event.messageId;
    final msg = messages[messageId];
    if (msg != null) {
      // Find or create tool part in message
      bool found = false;
      for (final part in msg.parts) {
        if (part.type == PartType.tool && part.tool?.id == event.callId) {
          part.tool = tool;
          found = true;
          break;
        }
      }
      if (!found) {
        msg.parts.add(MessagePart(type: PartType.tool, tool: tool));
      }
    } else {
      // Create message with tool part
      final newMsg = Message(
        id: messageId,
        sessionId: sessionId,
        role: MessageRole.agent,
        parts: [MessagePart(type: PartType.tool, tool: tool)],
        createdAt: DateTime.now(),
      );
      messages[messageId] = newMsg;
      if (!messageOrder.contains(messageId)) {
        messageOrder.add(messageId);
      }
    }
  }

  void addApproval(ApprovalRequest req) {
    approvals[req.id] = req;
  }

  void resolveApproval(String id) {
    final approval = approvals[id];
    if (approval != null && approval.kind == 'switch_mode') {
      // Keep plan approvals visible but mark as resolved (hides buttons)
      approval.resolved = true;
    } else {
      approvals.remove(id);
    }
  }

  void updatePlan(List<PlanEntry> entries) {
    planEntries = entries;
  }

  bool adoptLocalOptimisticUserMessage(String authoritativeMessageId) {
    if (authoritativeMessageId.isEmpty) {
      return false;
    }

    final optimisticMessageId = messageOrder.cast<String?>().firstWhere((
      messageId,
    ) {
      if (messageId == null) {
        return false;
      }
      final message = messages[messageId];
      return message != null &&
          message.role == MessageRole.user &&
          message.id.startsWith('local-');
    }, orElse: () => null);

    if (optimisticMessageId == null) {
      return false;
    }

    final optimisticMessage = messages.remove(optimisticMessageId);
    if (optimisticMessage == null) {
      messageOrder.remove(optimisticMessageId);
      return false;
    }

    final messageIndex = messageOrder.indexOf(optimisticMessageId);
    if (messageIndex >= 0) {
      messageOrder[messageIndex] = authoritativeMessageId;
    }

    _diffSummaryCache.remove(optimisticMessageId);
    _pendingParts.removeWhere(
      (_, value) => value.messageId == optimisticMessageId,
    );

    messages[authoritativeMessageId] = Message(
      id: authoritativeMessageId,
      sessionId: optimisticMessage.sessionId,
      role: optimisticMessage.role,
      parts: [],
      createdAt: optimisticMessage.createdAt,
    );
    return true;
  }

  void reset() {
    messages.clear();
    messageOrder.clear();
    tools.clear();
    approvals.clear();
    planEntries = [];
    _pendingParts.clear();
    _diffSummaryCache.clear();
  }

  void replaceWith(ChatState other) {
    reset();
    messages.addAll(other.messages);
    messageOrder.addAll(other.messageOrder);
    tools.addAll(other.tools);
    approvals.addAll(other.approvals);
    planEntries = List<PlanEntry>.from(other.planEntries);
  }

  List<ToolActivity> childToolsOf(String parentToolId) {
    return tools.values
        .where((t) => t.parentToolCallId == parentToolId)
        .toList();
  }

  /// Computes an aggregate diff summary for the agent run following the user
  /// message identified by [userMessageId]. Returns null if no edit diffs
  /// exist in that run. Results are cached per user message ID.
  RunDiffSummary? runDiffSummaryAfter(String userMessageId) {
    if (_diffSummaryCache.containsKey(userMessageId)) {
      return _diffSummaryCache[userMessageId];
    }

    final startIdx = messageOrder.indexOf(userMessageId);
    if (startIdx < 0) return null;

    // Collect all agent messages until the next user message (or end).
    // Per-file: track first oldText and last newText to aggregate.
    final fileOld = <String, String?>{}; // path → first oldText
    final fileNew = <String, String>{}; // path → last newText

    void collectDiffs(ToolActivity tool) {
      if (tool.effectiveKind != ToolKind.edit || tool.diffs == null) return;
      for (final diff in tool.diffs!) {
        if (!fileOld.containsKey(diff.path)) {
          fileOld[diff.path] = diff.oldText;
        }
        fileNew[diff.path] = diff.newText;
      }
      // Also collect child tool diffs (subagent edits).
      for (final child in childToolsOf(tool.id)) {
        collectDiffs(child);
      }
    }

    for (var i = startIdx + 1; i < messageOrder.length; i++) {
      final msg = messages[messageOrder[i]];
      if (msg == null) continue;
      if (msg.role == MessageRole.user) break;
      for (final part in msg.parts) {
        if (part.type == PartType.tool && part.tool != null) {
          collectDiffs(part.tool!);
        }
      }
    }

    if (fileNew.isEmpty) {
      _diffSummaryCache[userMessageId] = null;
      return null;
    }

    int totalAdd = 0;
    int totalDel = 0;
    final files = <FileDiffStat>[];

    for (final path in fileNew.keys) {
      final oldSrc = fileOld[path] ?? '';
      final newSrc = fileNew[path]!;
      final result = computeLineDiff(oldSrc, newSrc);
      if (result.additions > 0 || result.deletions > 0) {
        files.add(
          FileDiffStat(
            path: path,
            additions: result.additions,
            deletions: result.deletions,
            oldText: oldSrc,
            newText: newSrc,
          ),
        );
        totalAdd += result.additions;
        totalDel += result.deletions;
      }
    }

    if (files.isEmpty) {
      _diffSummaryCache[userMessageId] = null;
      return null;
    }

    final summary = RunDiffSummary(
      files: files,
      totalAdditions: totalAdd,
      totalDeletions: totalDel,
    );
    _diffSummaryCache[userMessageId] = summary;
    return summary;
  }

  List<Message> get orderedMessages {
    return messageOrder
        .where((id) => messages.containsKey(id))
        .map((id) => messages[id]!)
        .toList();
  }
}
