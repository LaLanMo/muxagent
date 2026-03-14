import 'approval.dart';
import 'enums.dart';
import 'message.dart';
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

  factory MessagePartEvent.fromJson(Map<String, dynamic> json) {
    return MessagePartEvent(
      partId: json['partId'] as String? ?? '',
      messageId: json['messageId'] as String? ?? '',
      role: json['role'] != null
          ? MessageRole.fromValue(json['role'] as String)
          : null,
      delta: json['delta'] as String? ?? '',
      partType: json['partType'] as String? ?? '',
      fullText: json['fullText'] as String? ?? '',
    );
  }
}

class ToolDiff {
  final String path;
  final String? oldText;
  final String newText;

  ToolDiff({required this.path, this.oldText, required this.newText});

  factory ToolDiff.fromJson(Map<String, dynamic> json) {
    return ToolDiff(
      path: json['path'] as String? ?? '',
      oldText: json['oldText'] as String?,
      newText: json['newText'] as String? ?? '',
    );
  }
}

class ToolLocation {
  final String path;
  final int? line;

  ToolLocation({required this.path, this.line});

  factory ToolLocation.fromJson(Map<String, dynamic> json) {
    return ToolLocation(
      path: json['path'] as String? ?? '',
      line: (json['line'] as num?)?.toInt(),
    );
  }
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

  factory ToolEvent.fromJson(Map<String, dynamic> json) {
    final diffsJson = json['diffs'] as List<dynamic>?;
    final locsJson = json['locations'] as List<dynamic>?;
    return ToolEvent(
      partId: json['partId'] as String? ?? '',
      messageId: json['messageId'] as String? ?? '',
      callId: json['callId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String?,
      title: json['title'] as String?,
      status: ToolStatus.fromValue(json['status'] as String? ?? 'pending'),
      input: json['input'] as Map<String, dynamic>?,
      output: json['output'] as String?,
      error: json['error'] as String?,
      diffs: diffsJson
          ?.map((e) => ToolDiff.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      locations: locsJson
          ?.map((e) => ToolLocation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SessionError {
  final String code;
  final String message;

  SessionError({required this.code, required this.message});

  factory SessionError.fromJson(Map<String, dynamic> json) {
    return SessionError(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
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
  final Message? message;
  final ToolEvent? tool;
  final ApprovalRequest? approval;
  final AgentSession? session;
  final SessionError? error;
  final Map<String, dynamic>? data;
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
    this.message,
    this.tool,
    this.approval,
    this.session,
    this.error,
    this.data,
    this.modeChange,
    this.configChange,
    this.planUpdate,
    this.usageUpdate,
    this.runFinished,
  });

  factory AgentEvent.fromJson(Map<String, dynamic> json, String machineId) {
    return AgentEvent(
      type: EventType.fromValue(json['type'] as String?),
      sessionId: json['sessionId'] as String?,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      at: json['at'] != null
          ? DateTime.parse(json['at'] as String)
          : DateTime.now(),
      machineId: machineId,
      messagePart: json['messagePart'] != null
          ? MessagePartEvent.fromJson(
              json['messagePart'] as Map<String, dynamic>,
            )
          : null,
      message: json['message'] != null
          ? Message.fromJson(json['message'] as Map<String, dynamic>)
          : null,
      tool: json['tool'] != null
          ? ToolEvent.fromJson(json['tool'] as Map<String, dynamic>)
          : null,
      approval: null,
      session: json['session'] != null
          ? AgentSession.fromJson(json['session'] as Map<String, dynamic>)
          : null,
      error: json['error'] != null
          ? SessionError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      data: json['data'] as Map<String, dynamic>?,
      modeChange: null,
      configChange: null,
      planUpdate: null,
      usageUpdate: null,
      runFinished: null,
    );
  }
}
