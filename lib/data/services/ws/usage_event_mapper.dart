import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import 'models/usage_event_models.dart';

class UsageEventMapper {
  static AgentEvent parseEvent(Map<String, dynamic> payload, String machineId) {
    final dto = UsageEventEnvelopeDto.fromJson(payload);
    final at = dto.at ?? DateTime.now();

    return AgentEvent(
      type: EventType.fromValue(dto.type),
      sessionId: dto.sessionId,
      seq: dto.seq,
      at: at,
      machineId: machineId,
      usageUpdate: UsageUpdate(
        contextUsed: dto.usage.app.contextUsed.toInt(),
        contextSize: dto.usage.app.contextSize.toInt(),
        costAmount: dto.usage.app.costAmount,
        costCurrency: dto.usage.app.costCurrency,
      ),
    );
  }
}
