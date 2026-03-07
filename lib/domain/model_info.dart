class ModelInfo {
  final String value;
  final String name;
  final String? description;

  const ModelInfo({
    required this.value,
    required this.name,
    this.description,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      value: json['value'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}
