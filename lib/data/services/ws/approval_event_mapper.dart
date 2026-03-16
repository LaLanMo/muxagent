import '../../../domain/approval.dart';
import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import 'models/approval_event_models.dart';

class ApprovalEventMapper {
  static AgentEvent mapEnvelope(
    ApprovalEventEnvelopeDto dto,
    String machineId,
  ) {
    final at = dto.at ?? DateTime.now();

    return AgentEvent(
      type: EventType.fromValue(dto.type),
      sessionId: dto.sessionId ?? dto.approval.acp?.sessionId,
      seq: dto.seq,
      at: at,
      machineId: machineId,
      approval: toDomainApproval(
        dto.approval,
        fallbackSessionId: dto.sessionId,
        fallbackCreatedAt: at,
      ),
    );
  }

  static ApprovalRequest parseApproval(
    Map<String, dynamic> json, {
    String? fallbackSessionId,
    DateTime? fallbackCreatedAt,
  }) {
    final dto = ApprovalWireDto.fromJson(json);
    return toDomainApproval(
      dto,
      fallbackSessionId: fallbackSessionId,
      fallbackCreatedAt: fallbackCreatedAt,
    );
  }

  static ApprovalRequest toDomainApproval(
    ApprovalWireDto dto, {
    String? fallbackSessionId,
    DateTime? fallbackCreatedAt,
  }) {
    final acp = dto.acp;
    final app = dto.app;

    final options =
        acp?.options
            .map(
              (option) => PermOption(
                optionId: option.optionId,
                kind: PermOptionKind.fromValue(option.kind),
                name: option.name,
              ),
            )
            .toList() ??
        const <PermOption>[];

    final commandDto = app.command;
    final command = commandDto == null
        ? null
        : ApprovalCommand(
            argv: commandDto.argv,
            display:
                _nonEmpty(commandDto.display) ??
                commandDto.argv.join(' ').trim(),
          );

    final allowedPrompts =
        app.plan?.allowedPrompts
            .map((item) => item.prompt.trim())
            .where((prompt) => prompt.isNotEmpty)
            .toList() ??
        const <String>[];

    return ApprovalRequest(
      id: app.requestId,
      sessionId: acp?.sessionId ?? fallbackSessionId ?? '',
      toolCallId: _nonEmpty(app.toolCallId) ?? acp?.toolCall.toolCallId,
      runtime: _nonEmpty(app.runtime),
      title: _nonEmpty(app.title) ?? _nonEmpty(acp?.toolCall.title) ?? '',
      kind: _nonEmpty(app.toolKind) ?? _nonEmpty(acp?.toolCall.kind),
      bodyText: _nonEmpty(app.bodyText),
      command: command,
      cwd: _nonEmpty(app.cwd),
      reason: _nonEmpty(app.reason),
      planMarkdown: _nonEmpty(app.plan?.markdown),
      allowedPrompts: allowedPrompts,
      options: options,
      createdAt: app.createdAt ?? fallbackCreatedAt ?? DateTime.now(),
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
