import 'cost_info.dart';
import 'enums.dart';

class AgentSession {
  final String id;
  String title;
  SessionStatus status;
  String? model;
  CostInfo? cost;
  bool isRead;
  final DateTime createdAt;
  DateTime updatedAt;
  Map<String, dynamic>? metadata;

  /// Current ACP session mode string (e.g. "default", "plan", "acceptEdits").
  String? get mode => metadata?['mode'] as String?;

  AgentSession({
    required this.id,
    this.title = '',
    this.status = SessionStatus.idle,
    this.model,
    this.cost,
    this.isRead = false,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status.value,
    if (model != null) 'model': model,
    if (cost != null) 'cost': cost!.toJson(),
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (metadata != null) 'metadata': metadata,
  };
}
