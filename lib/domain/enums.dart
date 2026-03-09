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
  planUpdated('plan.updated'),
  modeChanged('mode.changed'),
  modelChanged('model.changed'),
  usageUpdate('usage.update');

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
  media('media'),
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

enum ToolKind {
  execute('execute'),
  fetch('fetch'),
  edit('edit'),
  search('search'),
  read('read'),
  delete('delete'),
  move('move'),
  think('think'),
  switchMode('switch_mode'),
  other('other');

  const ToolKind(this.value);
  final String value;

  static ToolKind fromValue(String? raw) {
    if (raw == null) return ToolKind.other;
    for (final k in ToolKind.values) {
      if (k.value == raw) return k;
    }
    return ToolKind.other;
  }
}

enum PermOptionKind {
  allowOnce('allow_once'),
  allowAlways('allow_always'),
  rejectOnce('reject_once'),
  rejectAlways('reject_always');

  const PermOptionKind(this.value);
  final String value;

  static PermOptionKind fromValue(String raw) {
    for (final k in PermOptionKind.values) {
      if (k.value == raw) return k;
    }
    return PermOptionKind.rejectOnce;
  }

  bool get isAllow =>
      this == PermOptionKind.allowOnce || this == PermOptionKind.allowAlways;
  bool get isReject =>
      this == PermOptionKind.rejectOnce || this == PermOptionKind.rejectAlways;
  bool get isAlways =>
      this == PermOptionKind.allowAlways || this == PermOptionKind.rejectAlways;
}

enum ConnState {
  connected('connected'),
  disconnected('disconnected'),
  reconnecting('reconnecting');

  const ConnState(this.value);
  final String value;

  static ConnState fromValue(String raw) {
    for (final c in ConnState.values) {
      if (c.value == raw) return c;
    }
    return ConnState.disconnected;
  }
}
