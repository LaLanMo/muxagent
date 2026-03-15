import 'cost_info.dart';
import 'enums.dart';

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
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
