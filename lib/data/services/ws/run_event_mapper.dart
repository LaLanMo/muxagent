import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import 'models/run_event_models.dart';

class RunEventMapper {
  static AgentEvent mapRunFinishedEnvelope(
    RunFinishedEventEnvelopeDto dto,
    String machineId,
  ) {
    final app = dto.runFinished.app;

    return AgentEvent(
      type: EventType.fromValue(dto.type),
      sessionId: dto.sessionId,
      seq: dto.seq,
      at: dto.at ?? DateTime.now(),
      machineId: machineId,
      runFinished: RunFinishedUpdate(
        stopReason: app.stopReason,
        inputTokens: app.inputTokens,
        outputTokens: app.outputTokens,
        cachedReadTokens: app.cachedReadTokens,
        cachedWriteTokens: app.cachedWriteTokens,
        totalTokens: app.totalTokens,
      ),
    );
  }
}
