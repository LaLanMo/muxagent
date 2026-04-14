import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import '../../../domain/plan_entry.dart';
import 'models/plan_event_models.dart';

class PlanEventMapper {
  static AgentEvent mapEnvelope(PlanEventEnvelopeDto dto, String machineId) {
    final at = dto.at ?? DateTime.now();

    return AgentEvent(
      type: EventType.fromValue(dto.type),
      sessionId: dto.sessionId,
      seq: dto.seq,
      at: at,
      machineId: machineId,
      planUpdate: PlanUpdate(
        entries: dto.plan.app.entries
            .map(
              (entry) => PlanEntry(
                content: entry.content,
                priority: entry.priority,
                status: entry.status,
              ),
            )
            .toList(),
      ),
    );
  }
}
