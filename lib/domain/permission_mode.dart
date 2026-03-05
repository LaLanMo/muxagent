import 'dart:ui';

enum PermissionMode {
  defaultMode('default', 'Default', 0xFF9DA1A8),
  acceptEdits('acceptEdits', 'Accept Edits', 0xFF2563EB),
  plan('plan', 'Plan', 0xFF7C3AED),
  dontAsk('dontAsk', "Don't Ask", 0xFFF59E0B),
  bypassPermissions('bypassPermissions', 'Skip Perms', 0xFFDC2626);

  const PermissionMode(this.id, this.label, this.colorValue);
  final String id;
  final String label;
  final int colorValue;

  Color get color => Color(colorValue);

  bool get showPill => this != defaultMode;

  static PermissionMode fromId(String? id) => PermissionMode.values.firstWhere(
        (m) => m.id == id,
        orElse: () => PermissionMode.defaultMode,
      );
}
