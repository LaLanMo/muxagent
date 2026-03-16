class SessionModeChange {
  final String currentModeId;

  const SessionModeChange({required this.currentModeId});
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
