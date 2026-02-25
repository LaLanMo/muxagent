enum SessionStatus {
  idle('idle'),
  running('running'),
  waitingApproval('waiting_approval'),
  error('error'),
  done('done');

  const SessionStatus(this.value);
  final String value;

  static SessionStatus fromValue(String raw) {
    for (final s in SessionStatus.values) {
      if (s.value == raw) return s;
    }
    return SessionStatus.idle;
  }
}

enum ToolStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  failed('failed');

  const ToolStatus(this.value);
  final String value;

  static ToolStatus fromValue(String raw) {
    for (final s in ToolStatus.values) {
      if (s.value == raw) return s;
    }
    return ToolStatus.pending;
  }
}

enum EventType {
  messageDelta('message.delta'),
  messageFinal('message.final'),
  toolStarted('tool.started'),
  toolUpdated('tool.updated'),
  toolCompleted('tool.completed'),
  toolFailed('tool.failed'),
  reasoning('reasoning'),
  approvalRequested('approval.requested'),
  approvalReplied('approval.replied'),
  sessionStatus('session.status'),
  runFailed('run.failed'),
  runFinished('run.finished'),
  connectionState('connection.state'),
  planUpdated('plan.updated');

  const EventType(this.value);
  final String value;

  static EventType? fromValue(String? raw) {
    if (raw == null) return null;
    for (final e in EventType.values) {
      if (e.value == raw) return e;
    }
    return null;
  }
}

enum MessageRole {
  user('user'),
  agent('agent');

  const MessageRole(this.value);
  final String value;

  static MessageRole fromValue(String raw) {
    for (final r in MessageRole.values) {
      if (r.value == raw) return r;
    }
    return MessageRole.user;
  }
}

enum PartType {
  text('text'),
  reasoning('reasoning'),
  file('file'),
  tool('tool'),
  data('data');

  const PartType(this.value);
  final String value;

  static PartType fromValue(String raw) {
    for (final p in PartType.values) {
      if (p.value == raw) return p;
    }
    return PartType.text;
  }
}

enum ConnectionState {
  connected('connected'),
  disconnected('disconnected'),
  reconnecting('reconnecting');

  const ConnectionState(this.value);
  final String value;

  static ConnectionState fromValue(String raw) {
    for (final c in ConnectionState.values) {
      if (c.value == raw) return c;
    }
    return ConnectionState.disconnected;
  }
}
