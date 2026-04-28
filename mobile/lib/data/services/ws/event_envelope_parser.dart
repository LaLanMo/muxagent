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
import 'ws_types.dart';

class EventEnvelopeParser {
  static const Set<EventType> _scopedReplayAllowedTypes = {
    EventType.messageDelta,
    EventType.reasoning,
    EventType.toolStarted,
    EventType.toolUpdated,
    EventType.toolCompleted,
    EventType.toolFailed,
    EventType.approvalRequested,
    EventType.approvalReplied,
    EventType.runFinished,
    EventType.runFailed,
    EventType.planUpdated,
  };

  static String? rawEventType(WsEvent wsEvent) {
    final value = wsEvent.payload['type'];
    return value is String ? value : null;
  }

  static AgentEvent parseCommitted(WsEvent wsEvent) {
    final event = parse(wsEvent);
    if (event == null || event.type == null) {
      throw FormatException('Unsupported event type: ${rawEventType(wsEvent)}');
    }
    if (event.seq <= 0) {
      throw FormatException('Committed event seq must be > 0');
    }
    return event;
  }

  static AgentEvent parseScopedReplayEvent(
    Map<String, dynamic> payload, {
    required String machineId,
  }) {
    final rawType = payload['type'];
    final eventType = EventType.fromValue(rawType as String?);
    if (eventType == null) {
      throw FormatException('Unsupported replay event type: $rawType');
    }
    if (!_scopedReplayAllowedTypes.contains(eventType)) {
      throw FormatException(
        'Event type ${eventType.value} is not allowed in session.load replay',
      );
    }
    if (!payload.containsKey('seq')) {
      throw FormatException('Scoped replay event must include seq: 0');
    }
    final rawSeq = payload['seq'];
    if (rawSeq is! int || rawSeq != 0) {
      throw FormatException('Scoped replay event seq must be 0');
    }
    final event = parse(
      WsEvent(
        type: WsMessageType.event.value,
        payload: {...payload, 'machineId': machineId},
      ),
    );
    if (event == null || event.type == null) {
      throw FormatException('Unsupported replay event type: $rawType');
    }
    return event;
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
    };
  }
}
