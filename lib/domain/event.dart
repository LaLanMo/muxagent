import 'approval.dart';
import 'enums.dart';
import 'message.dart';
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

class ToolEvent {
  final String partId;
  final String messageId;
  final String callId;
  final String name;
  final String? title;
  final ToolStatus status;
  final Map<String, dynamic>? input;
  final String? output;
  final String? error;

  ToolEvent({
    required this.partId,
    required this.messageId,
    required this.callId,
    required this.name,
    this.title,
    required this.status,
    this.input,
    this.output,
    this.error,
  });

  factory ToolEvent.fromJson(Map<String, dynamic> json) {
    return ToolEvent(
      partId: json['partId'] as String? ?? '',
      messageId: json['messageId'] as String? ?? '',
      callId: json['callId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      title: json['title'] as String?,
      status: ToolStatus.fromValue(json['status'] as String? ?? 'pending'),
      input: json['input'] as Map<String, dynamic>?,
      output: json['output'] as String?,
      error: json['error'] as String?,
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
      approval: json['approval'] != null
          ? ApprovalRequest.fromJson(json['approval'] as Map<String, dynamic>)
          : null,
      session: json['session'] != null
          ? AgentSession.fromJson(json['session'] as Map<String, dynamic>)
          : null,
      error: json['error'] != null
          ? SessionError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}
