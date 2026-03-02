import 'enums.dart';

class ToolActivity {
  final String id;
  final String name;
  String? kind;
  ToolStatus status;
  String? title;
  Map<String, dynamic>? input;
  String? output;
  String? error;
  Map<String, dynamic>? metadata;

  ToolActivity({
    required this.id,
    required this.name,
    this.kind,
    this.status = ToolStatus.pending,
    this.title,
    this.input,
    this.output,
    this.error,
    this.metadata,
  });

  factory ToolActivity.fromJson(Map<String, dynamic> json) {
    return ToolActivity(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String?,
      status: ToolStatus.fromValue(json['status'] as String? ?? 'pending'),
      title: json['title'] as String?,
      input: json['input'] as Map<String, dynamic>?,
      output: json['output'] as String?,
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  ToolKind get effectiveKind {
    if (kind != null) return ToolKind.fromValue(kind);
    final n = name.toLowerCase();
    if (n.contains('bash')) return ToolKind.execute;
    if (n.contains('read')) return ToolKind.read;
    if (n.contains('edit') || n.contains('write')) return ToolKind.edit;
    if (n.contains('grep') || n.contains('glob')) return ToolKind.search;
    if (n.contains('fetch')) return ToolKind.fetch;
    return ToolKind.other;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.value,
        if (kind != null) 'kind': kind,
        if (title != null) 'title': title,
        if (input != null) 'input': input,
        if (output != null) 'output': output,
        if (error != null) 'error': error,
        if (metadata != null) 'metadata': metadata,
      };
}
