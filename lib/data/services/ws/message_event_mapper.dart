import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import 'models/message_event_models.dart';

class MessageEventMapper {
  static AgentEvent mapEnvelope(MessageEventEnvelopeDto dto, String machineId) {
    final app = dto.messagePart.app;

    return AgentEvent(
      type: EventType.fromValue(dto.type),
      sessionId: dto.sessionId,
      seq: dto.seq,
      at: dto.at ?? DateTime.now(),
      machineId: machineId,
      messagePart: MessagePartEvent(
        partId: app.partId,
        messageId: app.messageId,
        role: MessageRole.fromValue(app.role),
        delta: app.delta,
        partType: app.partType,
        fullText: app.fullText,
      ),
    );
  }
}
