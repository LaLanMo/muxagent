import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import 'models/tool_event_models.dart';

class ToolEventMapper {
  static AgentEvent parseEvent(Map<String, dynamic> payload, String machineId) {
    final dto = ToolEventEnvelopeDto.fromJson(payload);
    final at = dto.at ?? DateTime.now();

    return AgentEvent(
      type: EventType.fromValue(dto.type),
      sessionId: dto.sessionId,
      seq: dto.seq,
      at: at,
      machineId: machineId,
      tool: toDomainTool(dto.tool),
    );
  }

  static ToolEvent toDomainTool(ToolWireDto dto) {
    final app = dto.app;
    final acp = dto.acp;

    final kind = _nonEmpty(app.kind) ?? _nonEmpty(acp?.kind);
    final title = _nonEmpty(app.title) ?? _nonEmpty(acp?.title);
    final name = _nonEmpty(app.name) ?? title ?? acp?.toolCallId ?? '';
    final claudeCode = app.claudeCode ?? _claudeCodeFromMeta(acp?.meta);

    return ToolEvent(
      partId: app.partId,
      messageId: app.messageId,
      callId: app.callId,
      name: name,
      kind: kind,
      title: title,
      status: ToolStatus.fromValue(app.status),
      input: _mapOrNull(app.input),
      output: _nullIfEmpty(app.output),
      error: _nullIfEmpty(app.error),
      diffs: app.diffs
          .map(
            (diff) => ToolDiff(
              path: diff.path,
              oldText: diff.oldText,
              newText: diff.newText,
            ),
          )
          .toList(),
      claudeCode: claudeCode == null
          ? null
          : ClaudeCodeToolInfo(
              parentToolUseId: _nonEmpty(claudeCode.parentToolUseId),
              toolName: _nonEmpty(claudeCode.toolName),
            ),
      locations: app.locations
          .map(
            (location) =>
                ToolLocation(path: location.path, line: location.line),
          )
          .toList(),
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    return value.isEmpty ? null : value;
  }

  static Map<String, dynamic>? _mapOrNull(Map<String, dynamic>? value) {
    if (value == null || value.isEmpty) return null;
    return Map<String, dynamic>.from(value);
  }

  static ClaudeCodeToolDto? _claudeCodeFromMeta(Map<String, dynamic>? meta) {
    if (meta == null || meta.isEmpty) return null;
    final claudeCode = meta['claudeCode'];
    if (claudeCode is! Map) return null;
    final normalized = Map<String, dynamic>.from(
      claudeCode.cast<Object?, Object?>().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    if (normalized.isEmpty) return null;
    return ClaudeCodeToolDto.fromJson(normalized);
  }
}
