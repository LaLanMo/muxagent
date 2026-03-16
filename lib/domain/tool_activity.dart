import 'enums.dart';
import 'event.dart';

class ToolActivity {
  final String id;
  final String name;
  String? kind;
  ToolStatus status;
  String? title;
  ToolInputInfo? input;
  String? output;
  String? error;
  ClaudeCodeToolInfo? claudeCode;
  List<ToolDiff>? diffs;
  List<ToolLocation>? locations;

  ToolActivity({
    required this.id,
    required this.name,
    this.kind,
    this.status = ToolStatus.pending,
    this.title,
    this.input,
    this.output,
    this.error,
    this.claudeCode,
    this.diffs,
    this.locations,
  });

  ToolKind get effectiveKind {
    if (kind != null) return ToolKind.fromValue(kind);
    final n = name.toLowerCase();
    if (n.contains('bash')) return ToolKind.execute;
    if (n.contains('read')) return ToolKind.read;
    if (n.contains('edit') || n.contains('write')) return ToolKind.edit;
    if (n.contains('grep') || n.contains('glob')) return ToolKind.search;
    if (n.contains('fetch')) return ToolKind.fetch;
    return ToolKind.other;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status.value,
    if (kind != null) 'kind': kind,
    if (title != null) 'title': title,
    if (input != null)
      'input': {
        if (input!.description != null) 'description': input!.description,
        if (input!.command != null)
          'command': {
            if (input!.command!.argv.isNotEmpty) 'argv': input!.command!.argv,
            if (input!.command!.display != null)
              'display': input!.command!.display,
          },
        if (input!.filePath != null) 'filePath': input!.filePath,
        if (input!.sourcePath != null) 'sourcePath': input!.sourcePath,
        if (input!.targetPath != null) 'targetPath': input!.targetPath,
        if (input!.pattern != null) 'pattern': input!.pattern,
        if (input!.url != null) 'url': input!.url,
        if (input!.mode != null) 'mode': input!.mode,
        if (input!.edit != null)
          'edit': {
            if (input!.edit!.filePath != null)
              'filePath': input!.edit!.filePath,
            if (input!.edit!.oldString != null)
              'oldString': input!.edit!.oldString,
            if (input!.edit!.newString != null)
              'newString': input!.edit!.newString,
          },
        if (input!.rawInputJson != null) 'rawInputJson': input!.rawInputJson,
      },
    if (output != null) 'output': output,
    if (error != null) 'error': error,
    if (claudeCode != null)
      'claudeCode': {
        if (claudeCode!.parentToolUseId != null)
          'parentToolUseId': claudeCode!.parentToolUseId,
        if (claudeCode!.toolName != null) 'toolName': claudeCode!.toolName,
      },
  };
}

extension ToolActivityMeta on ToolActivity {
  String? get parentToolCallId => claudeCode?.parentToolUseId;

  String? get claudeToolName => claudeCode?.toolName;

  bool get isChildTool => parentToolCallId != null;
}
