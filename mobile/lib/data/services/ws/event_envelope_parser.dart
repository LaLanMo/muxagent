import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import 'approval_event_mapper.dart';
import 'lifecycle_event_mapper.dart';
import 'message_event_mapper.dart';
import 'models/approval_event_models.dart';
import 'models/lifecycle_event_models.dart';
import 'models/message_event_models.dart';
import 'models/plan_event_models.dart';
import 'models/run_event_models.dart';
import 'models/session_config_event_models.dart';
import 'models/tool_event_models.dart';
import 'models/usage_event_models.dart';
import 'models/ws_models.dart';
import 'plan_event_mapper.dart';
import 'run_event_mapper.dart';
import 'session_config_event_mapper.dart';
import 'tool_event_mapper.dart';
import 'usage_event_mapper.dart';

class EventEnvelopeParser {
  static String? rawEventType(WsEvent wsEvent) {
    final value = wsEvent.payload['type'];
    return value is String ? value : null;
  }

  static AgentEvent? parse(WsEvent wsEvent) {
    final payload = wsEvent.payload;
    final machineId =
        payload['machineId'] as String? ??
        payload['machine_id'] as String? ??
        '';
    final eventType = EventType.fromValue(payload['type'] as String?);
    if (eventType == null) {
      return null;
    }

    return switch (eventType) {
      EventType.approvalRequested ||
      EventType.approvalReplied => ApprovalEventMapper.mapEnvelope(
        ApprovalEventEnvelopeDto.fromJson(payload),
        machineId,
      ),
      EventType.toolStarted ||
      EventType.toolUpdated ||
      EventType.toolCompleted ||
      EventType.toolFailed => ToolEventMapper.mapEnvelope(
        ToolEventEnvelopeDto.fromJson(payload),
        machineId,
      ),
      EventType.messageDelta ||
      EventType.reasoning => MessageEventMapper.mapEnvelope(
        MessageEventEnvelopeDto.fromJson(payload),
        machineId,
      ),
      EventType.planUpdated => PlanEventMapper.mapEnvelope(
        PlanEventEnvelopeDto.fromJson(payload),
        machineId,
      ),
      EventType.sessionStatus => LifecycleEventMapper.mapSessionStatusEnvelope(
        SessionStatusEventEnvelopeDto.fromJson(payload),
        machineId,
      ),
      EventType.runFailed => LifecycleEventMapper.mapRunFailedEnvelope(
        RunFailedEventEnvelopeDto.fromJson(payload),
        machineId,
      ),
      EventType.runFinished => RunEventMapper.mapRunFinishedEnvelope(
        RunFinishedEventEnvelopeDto.fromJson(payload),
        machineId,
      ),
      EventType.usageUpdate => UsageEventMapper.mapEnvelope(
        UsageEventEnvelopeDto.fromJson(payload),
        machineId,
      ),
      EventType.modeChanged => SessionConfigEventMapper.mapModeChangedEnvelope(
        ModeChangedEventEnvelopeDto.fromJson(payload),
        machineId,
      ),
      EventType.modelChanged =>
        SessionConfigEventMapper.mapConfigChangedEnvelope(
          ConfigChangedEventEnvelopeDto.fromJson(payload),
          machineId,
        ),
      EventType.historyComplete =>
        LifecycleEventMapper.mapHistoryCompleteEnvelope(
          HistoryCompleteEventEnvelopeDto.fromJson(payload),
          machineId,
        ),
    };
  }
}
