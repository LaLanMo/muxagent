import 'enums.dart';

class ToolActivity {
  final String id;
  final String name;
  ToolStatus status;
  String? title;
  Map<String, dynamic>? input;
  String? output;
  String? error;
  Map<String, dynamic>? metadata;

  ToolActivity({
    required this.id,
    required this.name,
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
      status: ToolStatus.fromValue(json['status'] as String? ?? 'pending'),
      title: json['title'] as String?,
      input: json['input'] as Map<String, dynamic>?,
      output: json['output'] as String?,
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.value,
        if (title != null) 'title': title,
        if (input != null) 'input': input,
        if (output != null) 'output': output,
        if (error != null) 'error': error,
        if (metadata != null) 'metadata': metadata,
      };
}
