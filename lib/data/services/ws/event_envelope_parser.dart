import '../../../domain/enums.dart';
import '../../../domain/event.dart';
import 'approval_event_mapper.dart';
import 'lifecycle_event_mapper.dart';
import 'message_event_mapper.dart';
import 'plan_event_mapper.dart';
import 'run_event_mapper.dart';
import 'session_config_event_mapper.dart';
import 'tool_event_mapper.dart';
import 'usage_event_mapper.dart';

class EventEnvelopeParser {
  static AgentEvent? parse(Map<String, dynamic> payload, String machineId) {
    final eventType = EventType.fromValue(payload['type'] as String?);
    if (eventType == null) {
      return null;
    }

    return switch (eventType) {
      EventType.approvalRequested || EventType.approvalReplied =>
        ApprovalEventMapper.parseEvent(payload, machineId),
      EventType.toolStarted ||
      EventType.toolUpdated ||
      EventType.toolCompleted ||
      EventType.toolFailed => ToolEventMapper.parseEvent(payload, machineId),
      EventType.messageDelta ||
      EventType.reasoning => MessageEventMapper.parseEvent(payload, machineId),
      EventType.planUpdated => PlanEventMapper.parseEvent(payload, machineId),
      EventType.sessionStatus => LifecycleEventMapper.parseSessionStatus(
        payload,
        machineId,
      ),
      EventType.runFailed => LifecycleEventMapper.parseRunFailed(
        payload,
        machineId,
      ),
      EventType.runFinished => RunEventMapper.parseRunFinished(
        payload,
        machineId,
      ),
      EventType.usageUpdate => UsageEventMapper.parseEvent(payload, machineId),
      EventType.modeChanged || EventType.modelChanged =>
        SessionConfigEventMapper.parseEvent(payload, machineId),
    };
  }
}
