import 'approval_event_models.dart';

List<Map<String, dynamic>> _requireObjectList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    throw FormatException('Expected "$key" to be a list');
  }
  if (value is! List) {
    throw FormatException('Expected "$key" to be a list');
  }
  return value.map((item) {
    if (item is! Map) {
      throw FormatException('Expected "$key" items to be objects');
    }
    return Map<String, dynamic>.from(item);
  }).toList();
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a string');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a string or null');
}

bool _requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Expected "$key" to be a bool');
}

DateTime? _nullableDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Expected "$key" to be a string or null');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed != null) return parsed;
  throw FormatException('Expected "$key" to be an ISO-8601 datetime');
}

class RpcResyncResponseDto {
  final List<Map<String, dynamic>> events;
  final bool complete;

  const RpcResyncResponseDto({required this.events, required this.complete});

  factory RpcResyncResponseDto.fromJson(Map<String, dynamic> json) {
    return RpcResyncResponseDto(
      events: _requireObjectList(json, 'events'),
      complete: _requireBool(json, 'complete'),
    );
  }
}

class RpcResolvedSessionDto {
  final String sessionId;
  final String? title;
  final String? cwd;
  final String? status;
  final DateTime? updatedAt;

  const RpcResolvedSessionDto({
    required this.sessionId,
    this.title,
    this.cwd,
    this.status,
    this.updatedAt,
  });

  factory RpcResolvedSessionDto.fromJson(Map<String, dynamic> json) {
    return RpcResolvedSessionDto(
      sessionId: _requireString(json, 'sessionId'),
      title: _nullableString(json, 'title'),
      cwd: _nullableString(json, 'cwd'),
      status: _nullableString(json, 'status'),
      updatedAt: _nullableDateTime(json, 'updatedAt'),
    );
  }
}

class RpcSessionResolveResponseDto {
  final List<RpcResolvedSessionDto> sessions;

  const RpcSessionResolveResponseDto({this.sessions = const []});

  factory RpcSessionResolveResponseDto.fromJson(Map<String, dynamic> json) {
    return RpcSessionResolveResponseDto(
      sessions: _requireObjectList(
        json,
        'sessions',
      ).map(RpcResolvedSessionDto.fromJson).toList(),
    );
  }
}

class RpcPendingApprovalsResponseDto {
  final List<ApprovalWireDto> approvals;

  const RpcPendingApprovalsResponseDto({this.approvals = const []});

  factory RpcPendingApprovalsResponseDto.fromJson(Map<String, dynamic> json) {
    return RpcPendingApprovalsResponseDto(
      approvals: _requireObjectList(
        json,
        'approvals',
      ).map(ApprovalWireDto.fromJson).toList(),
    );
  }
}

class RpcFsEntryDto {
  final String path;
  final bool isDir;
  final String? name;

  const RpcFsEntryDto({required this.path, required this.isDir, this.name});

  factory RpcFsEntryDto.fromJson(Map<String, dynamic> json) {
    return RpcFsEntryDto(
      path: _requireString(json, 'path'),
      isDir: _requireBool(json, 'isDir'),
      name: _nullableString(json, 'name'),
    );
  }
}

class RpcFsListResponseDto {
  final List<RpcFsEntryDto> entries;

  const RpcFsListResponseDto({this.entries = const []});

  factory RpcFsListResponseDto.fromJson(Map<String, dynamic> json) {
    return RpcFsListResponseDto(
      entries: _requireObjectList(
        json,
        'entries',
      ).map(RpcFsEntryDto.fromJson).toList(),
    );
  }
}

class RpcFsSearchResponseDto {
  final List<RpcFsEntryDto> results;

  const RpcFsSearchResponseDto({this.results = const []});

  factory RpcFsSearchResponseDto.fromJson(Map<String, dynamic> json) {
    return RpcFsSearchResponseDto(
      results: _requireObjectList(
        json,
        'results',
      ).map(RpcFsEntryDto.fromJson).toList(),
    );
  }
}
