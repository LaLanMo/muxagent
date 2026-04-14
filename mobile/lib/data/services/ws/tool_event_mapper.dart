import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import 'models/tool_event_models.dart';

class ToolEventMapper {
  static AgentEvent mapEnvelope(ToolEventEnvelopeDto dto, String machineId) {
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
    final claudeCode = app.claudeCode;

    return ToolEvent(
      partId: app.partId,
      messageId: app.messageId,
      callId: app.callId,
      name: name,
      kind: kind,
      title: title,
      status: ToolStatus.fromValue(app.status),
      input: app.input == null
          ? null
          : ToolInputInfo(
              description: _nonEmpty(app.input!.description),
              command: app.input!.command == null
                  ? null
                  : ToolCommandInfo(
                      argv: app.input!.command!.argv,
                      display: _nonEmpty(app.input!.command!.display),
                    ),
              filePath: _nonEmpty(app.input!.filePath),
              sourcePath: _nonEmpty(app.input!.sourcePath),
              targetPath: _nonEmpty(app.input!.targetPath),
              pattern: _nonEmpty(app.input!.pattern),
              url: _nonEmpty(app.input!.url),
              mode: _nonEmpty(app.input!.mode),
              edit: app.input!.edit == null
                  ? null
                  : ToolEditInputInfo(
                      filePath: _nonEmpty(app.input!.edit!.filePath),
                      oldString: app.input!.edit!.oldString,
                      newString: app.input!.edit!.newString,
                    ),
              rawInputJson: _nonEmpty(app.input!.rawInputJson),
            ),
      output: _nullIfEmpty(app.output),
      error: _nullIfEmpty(app.error),
      diffs: app.diffs.isEmpty
          ? null
          : app.diffs
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
}
