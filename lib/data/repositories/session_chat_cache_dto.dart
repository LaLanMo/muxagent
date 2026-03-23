import 'dart:convert';

import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/message.dart';
import '../../domain/plan_entry.dart';
import '../../domain/session_config_snapshot.dart';
import '../../domain/tool_activity.dart';
import '../services/local/session_config_snapshot_codec.dart';
import '../../ui/chat/chat_state.dart';

const int sessionChatCacheSchemaVersion = 1;

enum SessionChatCacheState {
  empty('empty'),
  ready('ready'),
  stale('stale');

  const SessionChatCacheState(this.value);

  final String value;

  static SessionChatCacheState fromValue(String? raw) {
    for (final state in SessionChatCacheState.values) {
      if (state.value == raw) {
        return state;
      }
    }
    return SessionChatCacheState.empty;
  }
}

class SessionChatCacheEntry {
  final String sessionId;
  final String machineId;
  final String title;
  final SessionChatCacheState cacheState;
  final int cacheVersion;

  /// Highest transcript-affecting event seq represented by this cache entry.
  final int lastAppliedSeq;
  final Map<String, dynamic> chatStateJson;
  final Map<String, dynamic> configSnapshotJson;
  final DateTime updatedAt;

  const SessionChatCacheEntry({
    required this.sessionId,
    required this.machineId,
    this.title = '',
    required this.cacheState,
    this.cacheVersion = sessionChatCacheSchemaVersion,
    this.lastAppliedSeq = 0,
    required this.chatStateJson,
    this.configSnapshotJson = const {},
    required this.updatedAt,
  });

  bool get isCompatible => cacheVersion == sessionChatCacheSchemaVersion;

  bool get isNonEmpty {
    return _listFieldHasItems(chatStateJson['messages']) ||
        _listFieldHasItems(chatStateJson['messageOrder']) ||
        _mapFieldHasItems(chatStateJson['toolsByCallId']) ||
        _mapFieldHasItems(chatStateJson['approvalsById']) ||
        _listFieldHasItems(chatStateJson['planEntries']);
  }

  bool get isRenderable {
    return isCompatible && _isValidChatStateJson(chatStateJson) && isNonEmpty;
  }

  SessionChatCacheEntry copyWith({
    String? sessionId,
    String? machineId,
    String? title,
    SessionChatCacheState? cacheState,
    int? cacheVersion,
    int? lastAppliedSeq,
    Map<String, dynamic>? chatStateJson,
    Map<String, dynamic>? configSnapshotJson,
    DateTime? updatedAt,
  }) {
    return SessionChatCacheEntry(
      sessionId: sessionId ?? this.sessionId,
      machineId: machineId ?? this.machineId,
      title: title ?? this.title,
      cacheState: cacheState ?? this.cacheState,
      cacheVersion: cacheVersion ?? this.cacheVersion,
      lastAppliedSeq: lastAppliedSeq ?? this.lastAppliedSeq,
      chatStateJson: chatStateJson ?? this.chatStateJson,
      configSnapshotJson: configSnapshotJson ?? this.configSnapshotJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDatabaseRow() {
    return {
      'session_id': sessionId,
      'machine_id': machineId,
      'title': title,
      'cache_state': cacheState.value,
      'cache_version': cacheVersion,
      'last_applied_seq': lastAppliedSeq,
      'chat_state_json': jsonEncode(chatStateJson),
      'config_snapshot_json': jsonEncode(configSnapshotJson),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static SessionChatCacheEntry? fromDatabaseRow(Map<String, Object?> row) {
    final sessionId = row['session_id'] as String?;
    final machineId = row['machine_id'] as String?;
    final updatedAtRaw = row['updated_at'] as String?;
    if (sessionId == null ||
        sessionId.isEmpty ||
        machineId == null ||
        machineId.isEmpty ||
        updatedAtRaw == null ||
        updatedAtRaw.isEmpty) {
      return null;
    }

    final updatedAt = DateTime.tryParse(updatedAtRaw);
    if (updatedAt == null) {
      return null;
    }

    final chatStateJson = _decodeJsonMap(row['chat_state_json']);
    if (chatStateJson == null) {
      return null;
    }

    final configSnapshotJson =
        _decodeJsonMap(row['config_snapshot_json']) ??
        emptyConfigSnapshotJson();

    final cacheVersion =
        (row['cache_version'] as num?)?.toInt() ??
        sessionChatCacheSchemaVersion;
    final lastAppliedSeq = (row['last_applied_seq'] as num?)?.toInt() ?? 0;

    return SessionChatCacheEntry(
      sessionId: sessionId,
      machineId: machineId,
      title: row['title'] as String? ?? '',
      cacheState: SessionChatCacheState.fromValue(
        row['cache_state'] as String?,
      ),
      cacheVersion: cacheVersion,
      lastAppliedSeq: lastAppliedSeq < 0 ? 0 : lastAppliedSeq,
      chatStateJson: chatStateJson,
      configSnapshotJson: configSnapshotJson,
      updatedAt: updatedAt,
    );
  }

  static Map<String, dynamic> emptyChatStateJson() {
    return {
      'messages': const <dynamic>[],
      'messageOrder': const <dynamic>[],
      'toolsByCallId': const <String, dynamic>{},
      'approvalsById': const <String, dynamic>{},
      'planEntries': const <dynamic>[],
    };
  }

  static Map<String, dynamic> emptyConfigSnapshotJson() {
    return {
      'modeConfigId': '',
      'modelConfigId': '',
      'currentModel': null,
      'currentMode': null,
      'availableModels': const <dynamic>[],
      'availableModes': const <dynamic>[],
    };
  }

  static bool _listFieldHasItems(Object? value) {
    return value is List && value.isNotEmpty;
  }

  static bool _mapFieldHasItems(Object? value) {
    return value is Map && value.isNotEmpty;
  }

  static bool _isValidChatStateJson(Map<String, dynamic> json) {
    return json['messages'] is List &&
        json['messageOrder'] is List &&
        json['toolsByCallId'] is Map &&
        json['approvalsById'] is Map &&
        json['planEntries'] is List;
  }

  static Map<String, dynamic>? _decodeJsonMap(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is! String || value.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      return null;
    }
    return decoded.cast<String, dynamic>();
  }
}

class SessionChatCacheHydrated {
  final SessionChatCacheEntry entry;
  final ChatState chatState;
  final SessionConfigSnapshot configSnapshot;

  const SessionChatCacheHydrated({
    required this.entry,
    required this.chatState,
    required this.configSnapshot,
  });
}

SessionChatCacheEntry buildSessionChatCacheEntry({
  required String sessionId,
  required String machineId,
  required String title,
  required ChatState chatState,
  required SessionConfigSnapshot configSnapshot,
  required SessionChatCacheState cacheState,
  int lastAppliedSeq = 0,
  DateTime? updatedAt,
}) {
  return SessionChatCacheEntry(
    sessionId: sessionId,
    machineId: machineId,
    title: title,
    cacheState: cacheState,
    lastAppliedSeq: lastAppliedSeq < 0 ? 0 : lastAppliedSeq,
    chatStateJson: _serializeChatState(chatState),
    configSnapshotJson: _serializeConfigSnapshot(configSnapshot),
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

SessionChatCacheHydrated? hydrateSessionChatCacheEntry(
  SessionChatCacheEntry entry,
) {
  if (!entry.isRenderable) {
    return null;
  }

  final chatState = _deserializeChatState(entry);
  if (chatState == null) {
    return null;
  }
  final configSnapshot =
      _deserializeConfigSnapshot(entry.configSnapshotJson) ??
      const SessionConfigSnapshot();

  return SessionChatCacheHydrated(
    entry: entry,
    chatState: chatState,
    configSnapshot: configSnapshot,
  );
}

Map<String, dynamic> _serializeChatState(ChatState chatState) {
  final persistedMessages = <Message>[];
  final persistedMessageOrder = <String>[];

  for (final messageId in chatState.messageOrder) {
    final message = chatState.messages[messageId];
    if (message == null || _isLocalOnlyOptimisticMessage(message)) {
      continue;
    }
    persistedMessages.add(message);
    persistedMessageOrder.add(messageId);
  }

  return {
    'messages': persistedMessages.map(_serializeMessage).toList(),
    'messageOrder': persistedMessageOrder,
    'toolsByCallId': {
      for (final entry in chatState.tools.entries)
        entry.key: _serializeTool(entry.value),
    },
    'approvalsById': {
      for (final entry in chatState.approvals.entries)
        entry.key: _serializeApproval(entry.value),
    },
    'planEntries': chatState.planEntries.map(_serializePlanEntry).toList(),
  };
}

bool _isLocalOnlyOptimisticMessage(Message message) {
  return message.role == MessageRole.user && message.id.startsWith('local-');
}

Map<String, dynamic> _serializeMessage(Message message) {
  return {
    'id': message.id,
    'role': message.role.value,
    'createdAt': message.createdAt.toIso8601String(),
    'parts': message.parts.map(_serializeMessagePart).toList(),
  };
}

Map<String, dynamic> _serializeMessagePart(MessagePart part) {
  return {
    'type': part.type.value,
    if (part.text != null) 'text': part.text,
    if (part.media != null) 'media': _serializeMedia(part.media!),
    if (part.tool != null) 'toolCallId': part.tool!.id,
  };
}

Map<String, dynamic> _serializeMedia(MediaPart media) {
  return {
    if (media.url != null) 'url': media.url,
    if (media.base64 != null) 'base64': media.base64,
    if (media.mimeType != null) 'mimeType': media.mimeType,
    if (media.name != null) 'name': media.name,
    if (media.size != null) 'size': media.size,
  };
}

Map<String, dynamic> _serializeTool(ToolActivity tool) {
  return {
    'id': tool.id,
    'name': tool.name,
    'status': tool.status.value,
    if (tool.kind != null) 'kind': tool.kind,
    if (tool.title != null) 'title': tool.title,
    if (tool.input != null) 'input': _serializeToolInput(tool.input!),
    if (tool.output != null) 'output': tool.output,
    if (tool.error != null) 'error': tool.error,
    if (tool.claudeCode != null)
      'claudeCode': {
        if (tool.claudeCode!.parentToolUseId != null)
          'parentToolUseId': tool.claudeCode!.parentToolUseId,
        if (tool.claudeCode!.toolName != null)
          'toolName': tool.claudeCode!.toolName,
      },
    if (tool.diffs != null)
      'diffs': tool.diffs!
          .map(
            (diff) => {
              'path': diff.path,
              'oldText': diff.oldText,
              'newText': diff.newText,
            },
          )
          .toList(),
    if (tool.locations != null)
      'locations': tool.locations!
          .map((location) => {'path': location.path, 'line': location.line})
          .toList(),
  };
}

Map<String, dynamic> _serializeToolInput(ToolInputInfo input) {
  return {
    if (input.description != null) 'description': input.description,
    if (input.command != null)
      'command': {
        'argv': input.command!.argv,
        if (input.command!.display != null) 'display': input.command!.display,
      },
    if (input.filePath != null) 'filePath': input.filePath,
    if (input.sourcePath != null) 'sourcePath': input.sourcePath,
    if (input.targetPath != null) 'targetPath': input.targetPath,
    if (input.pattern != null) 'pattern': input.pattern,
    if (input.url != null) 'url': input.url,
    if (input.mode != null) 'mode': input.mode,
    if (input.edit != null)
      'edit': {
        if (input.edit!.filePath != null) 'filePath': input.edit!.filePath,
        if (input.edit!.oldString != null) 'oldString': input.edit!.oldString,
        if (input.edit!.newString != null) 'newString': input.edit!.newString,
      },
    if (input.rawInputJson != null) 'rawInputJson': input.rawInputJson,
  };
}

Map<String, dynamic> _serializeApproval(ApprovalRequest approval) {
  return {
    'id': approval.id,
    'sessionId': approval.sessionId,
    if (approval.toolCallId != null) 'toolCallId': approval.toolCallId,
    if (approval.runtime != null) 'runtime': approval.runtime,
    'title': approval.title,
    if (approval.kind != null) 'kind': approval.kind,
    if (approval.bodyText != null) 'bodyText': approval.bodyText,
    if (approval.command != null)
      'command': {
        'argv': approval.command!.argv,
        'display': approval.command!.display,
      },
    if (approval.cwd != null) 'cwd': approval.cwd,
    if (approval.reason != null) 'reason': approval.reason,
    if (approval.planMarkdown != null) 'planMarkdown': approval.planMarkdown,
    'allowedPrompts': approval.allowedPrompts,
    'options': approval.options
        .map(
          (option) => {
            'optionId': option.optionId,
            'kind': option.kind.value,
            'name': option.name,
          },
        )
        .toList(),
    'createdAt': approval.createdAt.toIso8601String(),
    'resolved': approval.resolved,
  };
}

Map<String, dynamic> _serializePlanEntry(PlanEntry entry) {
  return {
    'content': entry.content,
    'status': entry.status,
    'priority': entry.priority,
  };
}

Map<String, dynamic> _serializeConfigSnapshot(SessionConfigSnapshot snapshot) {
  return serializeSessionConfigSnapshot(snapshot);
}

ChatState? _deserializeChatState(SessionChatCacheEntry entry) {
  final messagesRaw = entry.chatStateJson['messages'];
  final messageOrderRaw = entry.chatStateJson['messageOrder'];
  final toolsRaw = entry.chatStateJson['toolsByCallId'];
  final approvalsRaw = entry.chatStateJson['approvalsById'];
  final planEntriesRaw = entry.chatStateJson['planEntries'];

  if (messagesRaw is! List ||
      messageOrderRaw is! List ||
      toolsRaw is! Map ||
      approvalsRaw is! Map ||
      planEntriesRaw is! List) {
    return null;
  }

  final tools = <String, ToolActivity>{};
  for (final rawEntry in toolsRaw.entries) {
    if (rawEntry.key is! String || rawEntry.value is! Map) {
      return null;
    }
    final tool = _deserializeTool(
      rawEntry.value.cast<String, dynamic>(),
      expectedId: rawEntry.key as String,
    );
    if (tool == null) {
      return null;
    }
    tools[rawEntry.key as String] = tool;
  }

  final messagesById = <String, Message>{};
  for (final rawMessage in messagesRaw) {
    if (rawMessage is! Map) {
      return null;
    }
    final message = _deserializeMessage(
      entry.sessionId,
      rawMessage.cast<String, dynamic>(),
      tools,
    );
    if (message == null) {
      return null;
    }
    messagesById[message.id] = message;
  }

  final chatState = ChatState(sessionId: entry.sessionId);
  for (final rawMessageId in messageOrderRaw) {
    if (rawMessageId is! String) {
      return null;
    }
    final message = messagesById[rawMessageId];
    if (message != null) {
      chatState.finalizeMessage(message);
    }
  }

  for (final entryTool in tools.entries) {
    chatState.tools[entryTool.key] = entryTool.value;
  }

  for (final rawApproval in approvalsRaw.entries) {
    if (rawApproval.key is! String || rawApproval.value is! Map) {
      return null;
    }
    final approval = _deserializeApproval(
      rawApproval.value.cast<String, dynamic>(),
      expectedId: rawApproval.key as String,
    );
    if (approval == null) {
      return null;
    }
    chatState.approvals[approval.id] = approval;
  }

  final planEntries = <PlanEntry>[];
  for (final rawPlanEntry in planEntriesRaw) {
    if (rawPlanEntry is! Map) {
      return null;
    }
    final planEntry = _deserializePlanEntry(
      rawPlanEntry.cast<String, dynamic>(),
    );
    if (planEntry == null) {
      return null;
    }
    planEntries.add(planEntry);
  }
  chatState.planEntries = planEntries;

  return chatState;
}

Message? _deserializeMessage(
  String sessionId,
  Map<String, dynamic> json,
  Map<String, ToolActivity> tools,
) {
  final id = json['id'] as String?;
  final roleValue = json['role'] as String?;
  final createdAtRaw = json['createdAt'] as String?;
  final partsRaw = json['parts'];
  if (id == null ||
      id.isEmpty ||
      roleValue == null ||
      createdAtRaw == null ||
      partsRaw is! List) {
    return null;
  }

  final createdAt = DateTime.tryParse(createdAtRaw);
  if (createdAt == null) {
    return null;
  }

  final parts = <MessagePart>[];
  for (final rawPart in partsRaw) {
    if (rawPart is! Map) {
      return null;
    }
    final part = _deserializeMessagePart(
      rawPart.cast<String, dynamic>(),
      tools,
    );
    if (part == null) {
      return null;
    }
    parts.add(part);
  }

  return Message(
    id: id,
    sessionId: sessionId,
    role: MessageRole.fromValue(roleValue),
    parts: parts,
    createdAt: createdAt,
  );
}

MessagePart? _deserializeMessagePart(
  Map<String, dynamic> json,
  Map<String, ToolActivity> tools,
) {
  final typeValue = json['type'] as String?;
  if (typeValue == null || typeValue.isEmpty) {
    return null;
  }
  final type = PartType.fromValue(typeValue);
  return MessagePart(
    type: type,
    text: json['text'] as String?,
    media: json['media'] is Map
        ? _deserializeMedia(json['media'].cast<String, dynamic>())
        : null,
    tool: json['toolCallId'] is String
        ? tools[json['toolCallId'] as String]
        : null,
  );
}

MediaPart _deserializeMedia(Map<String, dynamic> json) {
  return MediaPart(
    url: json['url'] as String?,
    base64: json['base64'] as String?,
    mimeType: json['mimeType'] as String?,
    name: json['name'] as String?,
    size: (json['size'] as num?)?.toInt(),
  );
}

ToolActivity? _deserializeTool(
  Map<String, dynamic> json, {
  required String expectedId,
}) {
  final id = (json['id'] as String?) ?? expectedId;
  final name = json['name'] as String?;
  final statusValue = json['status'] as String?;
  if (id.isEmpty || name == null || name.isEmpty || statusValue == null) {
    return null;
  }

  final diffsRaw = json['diffs'];
  final locationsRaw = json['locations'];

  return ToolActivity(
    id: id,
    name: name,
    kind: json['kind'] as String?,
    status: ToolStatus.fromValue(statusValue),
    title: json['title'] as String?,
    input: json['input'] is Map
        ? _deserializeToolInput(json['input'].cast<String, dynamic>())
        : null,
    output: json['output'] as String?,
    error: json['error'] as String?,
    claudeCode: json['claudeCode'] is Map
        ? ClaudeCodeToolInfo(
            parentToolUseId: json['claudeCode']['parentToolUseId'] as String?,
            toolName: json['claudeCode']['toolName'] as String?,
          )
        : null,
    diffs: diffsRaw is List
        ? diffsRaw
              .whereType<Map>()
              .map(
                (diff) => ToolDiff(
                  path: diff['path'] as String? ?? '',
                  oldText: diff['oldText'] as String?,
                  newText: diff['newText'] as String? ?? '',
                ),
              )
              .where((diff) => diff.path.isNotEmpty)
              .toList()
        : null,
    locations: locationsRaw is List
        ? locationsRaw
              .whereType<Map>()
              .map(
                (location) => ToolLocation(
                  path: location['path'] as String? ?? '',
                  line: (location['line'] as num?)?.toInt(),
                ),
              )
              .where((location) => location.path.isNotEmpty)
              .toList()
        : null,
  );
}

ToolInputInfo _deserializeToolInput(Map<String, dynamic> json) {
  final commandRaw = json['command'];
  final editRaw = json['edit'];
  return ToolInputInfo(
    description: json['description'] as String?,
    command: commandRaw is Map
        ? ToolCommandInfo(
            argv:
                (commandRaw['argv'] as List?)?.whereType<String>().toList() ??
                const [],
            display: commandRaw['display'] as String?,
          )
        : null,
    filePath: json['filePath'] as String?,
    sourcePath: json['sourcePath'] as String?,
    targetPath: json['targetPath'] as String?,
    pattern: json['pattern'] as String?,
    url: json['url'] as String?,
    mode: json['mode'] as String?,
    edit: editRaw is Map
        ? ToolEditInputInfo(
            filePath: editRaw['filePath'] as String?,
            oldString: editRaw['oldString'] as String?,
            newString: editRaw['newString'] as String?,
          )
        : null,
    rawInputJson: json['rawInputJson'] as String?,
  );
}

ApprovalRequest? _deserializeApproval(
  Map<String, dynamic> json, {
  required String expectedId,
}) {
  final id = (json['id'] as String?) ?? expectedId;
  final sessionId = json['sessionId'] as String?;
  final title = json['title'] as String?;
  final createdAtRaw = json['createdAt'] as String?;
  final optionsRaw = json['options'];
  if (id.isEmpty ||
      sessionId == null ||
      sessionId.isEmpty ||
      title == null ||
      createdAtRaw == null ||
      optionsRaw is! List) {
    return null;
  }

  final createdAt = DateTime.tryParse(createdAtRaw);
  if (createdAt == null) {
    return null;
  }

  final options = <PermOption>[];
  for (final rawOption in optionsRaw) {
    if (rawOption is! Map) {
      return null;
    }
    final optionId = rawOption['optionId'] as String?;
    final kind = rawOption['kind'] as String?;
    final name = rawOption['name'] as String?;
    if (optionId == null || kind == null || name == null) {
      return null;
    }
    options.add(
      PermOption(
        optionId: optionId,
        kind: PermOptionKind.fromValue(kind),
        name: name,
      ),
    );
  }

  final commandRaw = json['command'];
  return ApprovalRequest(
    id: id,
    sessionId: sessionId,
    toolCallId: json['toolCallId'] as String?,
    runtime: json['runtime'] as String?,
    title: title,
    kind: json['kind'] as String?,
    bodyText: json['bodyText'] as String?,
    command: commandRaw is Map
        ? ApprovalCommand(
            argv:
                (commandRaw['argv'] as List?)?.whereType<String>().toList() ??
                const [],
            display: commandRaw['display'] as String? ?? '',
          )
        : null,
    cwd: json['cwd'] as String?,
    reason: json['reason'] as String?,
    planMarkdown: json['planMarkdown'] as String?,
    allowedPrompts:
        (json['allowedPrompts'] as List?)?.whereType<String>().toList() ??
        const [],
    options: options,
    createdAt: createdAt,
    resolved: json['resolved'] as bool? ?? false,
  );
}

PlanEntry? _deserializePlanEntry(Map<String, dynamic> json) {
  final content = json['content'] as String?;
  final status = json['status'] as String?;
  final priority = json['priority'] as String?;
  if (content == null || status == null || priority == null) {
    return null;
  }
  return PlanEntry(content: content, status: status, priority: priority);
}

SessionConfigSnapshot? _deserializeConfigSnapshot(Map<String, dynamic> json) {
  return deserializeSessionConfigSnapshot(json);
}
