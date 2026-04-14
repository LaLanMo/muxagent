import 'enums.dart';

class PermOption {
  final String optionId;
  final PermOptionKind kind;
  final String name;

  const PermOption({
    required this.optionId,
    required this.kind,
    required this.name,
  });
}

class ApprovalCommand {
  final List<String> argv;
  final String display;

  const ApprovalCommand({required this.argv, required this.display});
}

class ApprovalRequest {
  final String id;
  final String sessionId;
  final String? toolCallId;
  final String? runtime;
  final String title;
  final String? kind;
  final String? bodyText;
  final ApprovalCommand? command;
  final String? cwd;
  final String? reason;
  final String? planMarkdown;
  final List<String> allowedPrompts;
  final List<PermOption> options;
  final DateTime createdAt;
  bool resolved;

  ApprovalRequest({
    required this.id,
    required this.sessionId,
    this.toolCallId,
    this.runtime,
    required this.title,
    this.kind,
    this.bodyText,
    this.command,
    this.cwd,
    this.reason,
    this.planMarkdown,
    this.allowedPrompts = const [],
    required this.options,
    required this.createdAt,
    this.resolved = false,
  });

  String? get commandText {
    final display = command?.display.trim();
    if (display == null || display.isEmpty) return null;
    return display;
  }

  String? get descriptionText {
    final primary = reason?.trim();
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }
    final secondary = bodyText?.trim();
    if (secondary != null && secondary.isNotEmpty) {
      return secondary;
    }
    final fallback = title.trim();
    if (fallback.isEmpty) return null;
    return fallback;
  }
}
