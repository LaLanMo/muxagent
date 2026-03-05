import 'cost_info.dart';
import 'enums.dart';

class AgentSession {
  final String id;
  String title;
  SessionStatus status;
  String? model;
  CostInfo? cost;
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
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  factory AgentSession.fromJson(Map<String, dynamic> json) {
    return AgentSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      status: SessionStatus.fromValue(json['status'] as String? ?? 'idle'),
      model: json['model'] as String?,
      cost: json['cost'] != null
          ? CostInfo.fromJson(json['cost'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status.value,
        if (model != null) 'model': model,
        if (cost != null) 'cost': cost!.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };
}
