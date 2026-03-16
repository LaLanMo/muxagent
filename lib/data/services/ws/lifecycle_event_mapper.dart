import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import '../../../domain/session.dart';
import '../../../domain/cost_info.dart';
import 'models/lifecycle_event_models.dart';

class LifecycleEventMapper {
  static AgentEvent parseSessionStatus(
    Map<String, dynamic> payload,
    String machineId,
  ) {
    final dto = SessionStatusEventEnvelopeDto.fromJson(payload);
    final app = dto.sessionStatus.app;

    return AgentEvent(
      type: EventType.fromValue(dto.type),
      sessionId: dto.sessionId ?? app.id,
      seq: dto.seq,
      at: dto.at ?? DateTime.now(),
      machineId: machineId,
      session: AgentSession(
        id: app.id,
        title: app.title,
        status: SessionStatus.fromValue(app.status),
        model: app.model,
        cost: app.cost == null
            ? null
            : CostInfo(
                costAmount: app.cost!.costAmount,
                costCurrency: app.cost!.costCurrency,
                totalTokens: app.cost!.totalTokens,
              ),
        machineId: app.machineId ?? '',
        runtime: app.runtime ?? '',
        cwd: app.cwd ?? '',
        mode: switch (app.mode?.trim()) {
          final String value when value.isNotEmpty => value,
          _ => null,
        },
        createdAt: app.createdAt,
        updatedAt: app.updatedAt,
      ),
    );
  }

  static AgentEvent parseRunFailed(
    Map<String, dynamic> payload,
    String machineId,
  ) {
    final dto = RunFailedEventEnvelopeDto.fromJson(payload);
    final app = dto.runFailed.app;

    return AgentEvent(
      type: EventType.fromValue(dto.type),
      sessionId: dto.sessionId,
      seq: dto.seq,
      at: dto.at ?? DateTime.now(),
      machineId: machineId,
      error: SessionError(code: app.error.code, message: app.error.message),
    );
  }
}
