class PermOption {
  final String optionId;
  final String kind;
  final String name;

  PermOption({
    required this.optionId,
    required this.kind,
    required this.name,
  });

  factory PermOption.fromJson(Map<String, dynamic> json) {
    return PermOption(
      optionId: json['optionId'] as String,
      kind: json['kind'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'optionId': optionId,
        'kind': kind,
        'name': name,
      };
}

class ApprovalRequest {
  final String id;
  final String sessionId;
  final String toolName;
  final String title;
  final String? kind;
  final Map<String, dynamic>? input;
  final List<PermOption> options;
  final DateTime createdAt;

  ApprovalRequest({
    required this.id,
    required this.sessionId,
    required this.toolName,
    required this.title,
    this.kind,
    this.input,
    required this.options,
    required this.createdAt,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      toolName: json['toolName'] as String,
      title: json['title'] as String,
      kind: json['kind'] as String?,
      input: json['input'] as Map<String, dynamic>?,
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => PermOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'toolName': toolName,
        'title': title,
        if (kind != null) 'kind': kind,
        if (input != null) 'input': input,
        'options': options.map((o) => o.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}
