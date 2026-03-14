class PlanEntry {
  final String content;
  final String status; // pending, in_progress, completed
  final String priority; // high, medium, low

  PlanEntry({
    required this.content,
    required this.status,
    required this.priority,
  });

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isPending => status == 'pending';
}
