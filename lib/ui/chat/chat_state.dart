import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/message.dart';
import '../../domain/plan_entry.dart';
import '../../domain/tool_activity.dart';

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

  List<ToolActivity> childToolsOf(String parentToolId) {
    return tools.values
        .where((t) => t.parentToolCallId == parentToolId)
        .toList();
  }

  List<Message> get orderedMessages {
    return messageOrder
        .where((id) => messages.containsKey(id))
        .map((id) => messages[id]!)
        .toList();
  }
}
