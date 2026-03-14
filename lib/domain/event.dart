import 'approval.dart';
import 'enums.dart';
import 'plan_entry.dart';
import 'session_config_change.dart';
import 'session.dart';

class MessagePartEvent {
  final String partId;
  final String messageId;
  final MessageRole? role;
  final String delta;
  final String partType;
  final String fullText;

  MessagePartEvent({
    required this.partId,
    required this.messageId,
    this.role,
    this.delta = '',
    this.partType = '',
    this.fullText = '',
  });
}

class ToolDiff {
  final String path;
  final String? oldText;
  final String newText;

  ToolDiff({required this.path, this.oldText, required this.newText});
}

class ToolLocation {
  final String path;
  final int? line;

  ToolLocation({required this.path, this.line});
}

class PlanUpdate {
  final List<PlanEntry> entries;

  const PlanUpdate({required this.entries});
}

class UsageUpdate {
  final int contextUsed;
  final int contextSize;
  final double? costAmount;
  final String? costCurrency;

  const UsageUpdate({
    required this.contextUsed,
    required this.contextSize,
    this.costAmount,
    this.costCurrency,
  });
}

class RunFinishedUpdate {
  final String stopReason;
  final int inputTokens;
  final int outputTokens;
  final int cachedReadTokens;
  final int cachedWriteTokens;
  final int totalTokens;

  const RunFinishedUpdate({
    required this.stopReason,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedReadTokens = 0,
    this.cachedWriteTokens = 0,
    this.totalTokens = 0,
  });
}

class ToolEvent {
  final String partId;
  final String messageId;
  final String callId;
  final String name;
  final String? kind;
  final String? title;
  final ToolStatus status;
  final Map<String, dynamic>? input;
  final String? output;
  final String? error;
  final List<ToolDiff>? diffs;
  final Map<String, dynamic>? metadata;
  final List<ToolLocation>? locations;

  ToolEvent({
    required this.partId,
    required this.messageId,
    required this.callId,
    required this.name,
    this.kind,
    this.title,
    required this.status,
    this.input,
    this.output,
    this.error,
    this.diffs,
    this.metadata,
    this.locations,
  });
}

class SessionError {
  final String code;
  final String message;

  SessionError({required this.code, required this.message});
}

class ContentBlock {
  final String type;
  final String? text;
  final String? mimeType;
  final String? data;
  final String? uri;

  ContentBlock({
    required this.type,
    this.text,
    this.mimeType,
    this.data,
    this.uri,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    if (text != null) 'text': text,
    if (mimeType != null) 'mimeType': mimeType,
    if (data != null) 'data': data,
    if (uri != null) 'uri': uri,
  };
}

class AgentEvent {
  final EventType? type;
  final String? sessionId;
  final int seq;
  final DateTime at;
  final String machineId;

  final MessagePartEvent? messagePart;
  final ToolEvent? tool;
  final ApprovalRequest? approval;
  final AgentSession? session;
  final SessionError? error;
  final SessionModeChange? modeChange;
  final SessionConfigChange? configChange;
  final PlanUpdate? planUpdate;
  final UsageUpdate? usageUpdate;
  final RunFinishedUpdate? runFinished;

  AgentEvent({
    this.type,
    this.sessionId,
    this.seq = 0,
    required this.at,
    required this.machineId,
    this.messagePart,
    this.tool,
    this.approval,
    this.session,
    this.error,
    this.modeChange,
    this.configChange,
    this.planUpdate,
    this.usageUpdate,
    this.runFinished,
  });
}
