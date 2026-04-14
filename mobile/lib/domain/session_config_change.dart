class SessionModeChange {
  final String currentModeId;
  final String? configId;
  final List<SessionConfigValue> values;

  const SessionModeChange({
    required this.currentModeId,
    this.configId,
    this.values = const [],
  });
}

class SessionConfigValue {
  final String value;
  final String name;
  final String? description;

  const SessionConfigValue({
    required this.value,
    required this.name,
    this.description,
  });
}

class SessionConfigChange {
  final String configId;
  final String currentValue;
  final String? category;
  final List<SessionConfigValue> values;

  const SessionConfigChange({
    required this.configId,
    required this.currentValue,
    required this.values,
    this.category,
  });
}
