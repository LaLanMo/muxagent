import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import '../../../domain/session_config_change.dart';
import 'models/session_config_event_models.dart';

class SessionConfigEventMapper {
  static AgentEvent mapModeChangedEnvelope(
    ModeChangedEventEnvelopeDto dto,
    String machineId,
  ) {
    return AgentEvent(
      type: EventType.modeChanged,
      sessionId: dto.sessionId,
      seq: dto.seq,
      at: dto.at ?? DateTime.now(),
      machineId: machineId,
      modeChange: SessionModeChange(
        currentModeId: dto.modeChanged.app.currentModeId,
      ),
    );
  }

  static AgentEvent mapConfigChangedEnvelope(
    ConfigChangedEventEnvelopeDto dto,
    String machineId,
  ) {
    return AgentEvent(
      type: EventType.modelChanged,
      sessionId: dto.sessionId,
      seq: dto.seq,
      at: dto.at ?? DateTime.now(),
      machineId: machineId,
      configChange: SessionConfigChange(
        configId: dto.configChanged.app.configId,
        currentValue: dto.configChanged.app.currentValue,
        category: dto.configChanged.app.category,
        values: dto.configChanged.app.values
            .map(
              (value) => SessionConfigValue(
                value: value.value,
                name: value.name,
                description: value.description,
              ),
            )
            .toList(),
      ),
    );
  }
}
