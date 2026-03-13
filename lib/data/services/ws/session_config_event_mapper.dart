import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import '../../../domain/session_config_change.dart';
import 'models/acp_session_models.dart';

class SessionConfigEventMapper {
  static AgentEvent parseEvent(Map<String, dynamic> payload, String machineId) {
    final type = EventType.fromValue(payload['type'] as String?);
    final sessionId = payload['sessionId'] as String?;
    final seq = (payload['seq'] as num?)?.toInt() ?? 0;
    final at = payload['at'] != null
        ? DateTime.parse(payload['at'] as String)
        : DateTime.now();
    final rawData = payload['data'] as Map<String, dynamic>? ?? const {};

    return switch (type) {
      EventType.modeChanged => _parseModeChanged(
        sessionId: sessionId,
        seq: seq,
        at: at,
        machineId: machineId,
        rawData: rawData,
      ),
      EventType.modelChanged => _parseConfigChanged(
        eventType: EventType.modelChanged,
        sessionId: sessionId,
        seq: seq,
        at: at,
        machineId: machineId,
        rawData: rawData,
      ),
      _ => AgentEvent(
        type: type,
        sessionId: sessionId,
        seq: seq,
        at: at,
        machineId: machineId,
      ),
    };
  }

  static AgentEvent _parseModeChanged({
    required String? sessionId,
    required int seq,
    required DateTime at,
    required String machineId,
    required Map<String, dynamic> rawData,
  }) {
    final dto = AppModeChangedEventDataDto.fromJson(rawData);
    return AgentEvent(
      type: EventType.modeChanged,
      sessionId: sessionId,
      seq: seq,
      at: at,
      machineId: machineId,
      modeChange: SessionModeChange(currentModeId: dto.app.currentModeId),
    );
  }

  static AgentEvent _parseConfigChanged({
    required EventType eventType,
    required String? sessionId,
    required int seq,
    required DateTime at,
    required String machineId,
    required Map<String, dynamic> rawData,
  }) {
    final dto = AppConfigChangedEventDataDto.fromJson(rawData);
    return AgentEvent(
      type: eventType,
      sessionId: sessionId,
      seq: seq,
      at: at,
      machineId: machineId,
      configChange: SessionConfigChange(
        configId: dto.app.configId,
        currentValue: dto.app.currentValue,
        category: dto.app.category,
        values: dto.app.values
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
