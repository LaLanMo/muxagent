import 'cost_info.dart';
import 'enums.dart';
import 'session_config_snapshot.dart';

class AgentSession {
  final String id;
  String title;
  SessionStatus status;
  String? model;
  CostInfo? cost;
  String machineId;
  String runtime;
  String cwd;
  String? mode;
  SessionConfigSnapshot configSnapshot;
  bool isRead;
  final DateTime createdAt;
  DateTime updatedAt;

  AgentSession({
    required this.id,
    this.title = '',
    this.status = SessionStatus.idle,
    this.model,
    this.cost,
    this.machineId = '',
    this.runtime = '',
    this.cwd = '',
    this.mode,
    this.configSnapshot = const SessionConfigSnapshot(),
    this.isRead = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status.value,
    if (model != null) 'model': model,
    if (cost != null) 'cost': cost!.toJson(),
    if (machineId.isNotEmpty) 'machineId': machineId,
    if (runtime.isNotEmpty) 'runtime': runtime,
    if (cwd.isNotEmpty) 'cwd': cwd,
    if (mode != null && mode!.isNotEmpty) 'mode': mode,
    'configSnapshot': {
      'modeConfigId': configSnapshot.modeConfigId,
      'currentMode': configSnapshot.currentMode?.id,
      'availableModes': configSnapshot.availableModes.map((m) => m.id).toList(),
      'modelConfigId': configSnapshot.modelConfigId,
      'currentModel': configSnapshot.currentModel,
      'availableModels': configSnapshot.availableModels
          .map((m) => m.value)
          .toList(),
    },
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
