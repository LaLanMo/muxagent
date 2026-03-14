import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import '../../../domain/session_config_change.dart';
import 'models/session_config_event_models.dart';

class SessionConfigEventMapper {
  static AgentEvent parseEvent(Map<String, dynamic> payload, String machineId) {
    final type = EventType.fromValue(payload['type'] as String?);
    return switch (type) {
      EventType.modeChanged => _parseModeChanged(payload, machineId),
      EventType.modelChanged => _parseConfigChanged(payload, machineId),
      _ => AgentEvent(
        type: type,
        sessionId: payload['sessionId'] as String?,
        seq: (payload['seq'] as num?)?.toInt() ?? 0,
        at: payload['at'] != null
            ? DateTime.parse(payload['at'] as String)
            : DateTime.now(),
        machineId: machineId,
      ),
    };
  }

  static AgentEvent _parseModeChanged(
    Map<String, dynamic> payload,
    String machineId,
  ) {
    final dto = ModeChangedEventEnvelopeDto.fromJson(payload);
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

  static AgentEvent _parseConfigChanged(
    Map<String, dynamic> payload,
    String machineId,
  ) {
    final dto = ConfigChangedEventEnvelopeDto.fromJson(payload);
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
