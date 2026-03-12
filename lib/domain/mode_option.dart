class ModeOption {
  final String id;
  final String label;
  final String? description;

  const ModeOption({
    required this.id,
    required this.label,
    this.description,
  });

  factory ModeOption.fromJson(Map<String, dynamic> json) {
    final id = json['value'] as String? ?? json['id'] as String? ?? '';
    final label =
        json['name'] as String? ?? json['label'] as String? ?? _fallbackLabel(id);
    return ModeOption(
      id: id,
      label: label,
      description: json['description'] as String?,
    );
  }

  factory ModeOption.fromId(String? id) {
    final value = id ?? '';
    return ModeOption(id: value, label: _fallbackLabel(value));
  }

  static String _fallbackLabel(String id) {
    switch (id) {
      case 'default':
      case 'auto':
        return 'Default';
      case 'acceptEdits':
        return 'Accept Edits';
      case 'plan':
        return 'Plan';
      case 'dontAsk':
        return "Don't Ask";
      case 'bypassPermissions':
        return 'Bypass Permissions';
      case 'read-only':
        return 'Read Only';
      case 'full-access':
        return 'Full Access';
      default:
        if (id.isEmpty) return 'Default';
        return id
            .replaceAll('-', ' ')
            .replaceAllMapped(
              RegExp(r'([a-z])([A-Z])'),
              (match) => '${match[1]} ${match[2]}',
            )
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }
}
