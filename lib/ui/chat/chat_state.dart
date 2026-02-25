import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/message.dart';
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
  final _pendingParts = <String, _PendingPart>{};

  ChatState({required this.sessionId});

  void applyDelta(MessagePartEvent delta) {
    // Get or create message
    var msg = messages[delta.messageId];
    if (msg == null) {
      msg = Message(
        id: delta.messageId,
        sessionId: sessionId,
        role: MessageRole.agent,
        parts: [],
        createdAt: DateTime.now(),
      );
      messages[delta.messageId] = msg;
      if (!messageOrder.contains(delta.messageId)) {
        messageOrder.add(delta.messageId);
      }
    }

    // Find or create part
    var pending = _pendingParts[delta.partId];
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
        messageId: delta.messageId,
        partIndex: msg.parts.length - 1,
        partType: delta.partType,
      );
      _pendingParts[delta.partId] = pending;
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
        status: event.status,
        title: event.title,
        input: event.input,
        output: event.output,
        error: event.error,
      );
      tools[event.callId] = tool;
    } else {
      tool.status = event.status;
      if (event.output != null) tool.output = event.output;
      if (event.error != null) tool.error = event.error;
      if (event.title != null) tool.title = event.title;
      if (event.input != null) tool.input = event.input;
    }

    // Also update in message parts if present
    final messageId = event.messageId;
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
    approvals.remove(id);
  }

  List<Message> get orderedMessages {
    return messageOrder
        .where((id) => messages.containsKey(id))
        .map((id) => messages[id]!)
        .toList();
  }
}
