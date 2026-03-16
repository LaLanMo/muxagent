class ModelInfo {
  final String value;
  final String name;
  final String? description;

  const ModelInfo({required this.value, required this.name, this.description});

  factory ModelInfo.fromConfigValue({
    required String value,
    required String name,
    String? description,
  }) {
    return ModelInfo(value: value, name: name, description: description);
  }
}
