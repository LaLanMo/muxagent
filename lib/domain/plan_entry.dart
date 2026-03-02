class PlanEntry {
  final String content;
  final String status; // pending, in_progress, completed
  final String priority; // high, medium, low

  PlanEntry({
    required this.content,
    required this.status,
    required this.priority,
  });

  factory PlanEntry.fromJson(Map<String, dynamic> json) => PlanEntry(
        content: json['content'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        priority: json['priority'] as String? ?? 'medium',
      );

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isPending => status == 'pending';
}
