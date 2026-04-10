class ModeOption {
  final String id;
  final String label;
  final String? description;

  const ModeOption({required this.id, required this.label, this.description});

  factory ModeOption.fromConfigValue({
    required String value,
    required String name,
    String? description,
  }) {
    return ModeOption(
      id: value,
      label: _displayLabel(value, name),
      description: description,
    );
  }

  factory ModeOption.fromId(String? id) {
    final value = id ?? '';
    return ModeOption(id: value, label: _displayLabel(value, null));
  }

  static List<ModeOption> orderedForRuntime(
    String runtimeId,
    Iterable<ModeOption> modes,
  ) {
    final visible = [
      for (final mode in modes)
        if (isVisibleForRuntime(runtimeId, mode.id)) mode,
    ];

    final order = switch (runtimeId) {
      'claude-code' => const {
        'bypassPermissions': 0,
        'default': 1,
        'acceptEdits': 2,
        'plan': 3,
      },
      'codex' => const {'full-access': 0, 'auto': 1, 'read-only': 2},
      'opencode' => const {'build': 0, 'plan': 1},
      _ => const <String, int>{},
    };

    visible.sort((a, b) {
      final rankA = order[a.id] ?? 999;
      final rankB = order[b.id] ?? 999;
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      return a.label.compareTo(b.label);
    });
    return visible;
  }

  static bool isVisibleForRuntime(String runtimeId, String modeId) {
    if (runtimeId == 'claude-code' && modeId == 'dontAsk') {
      return false;
    }
    return true;
  }

  // Keep app copy consistent even when runtimes use different labels
  // for the same known permission mode.
  static String _displayLabel(String id, String? upstreamLabel) {
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
        return 'Skip Perms';
      case 'read-only':
        return 'Read Only';
      case 'full-access':
        return 'Full Access';
      default:
        return upstreamLabel ?? _fallbackLabel(id);
    }
  }

  static String _fallbackLabel(String id) {
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
