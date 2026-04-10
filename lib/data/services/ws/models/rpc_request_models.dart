import '../../../../domain/prompt_content_block.dart';

class RpcSessionCreateParamsDto {
  final String cwd;
  final String runtime;
  final bool useWorktree;
  final String? permissionMode;

  const RpcSessionCreateParamsDto({
    required this.cwd,
    required this.runtime,
    this.useWorktree = false,
    this.permissionMode,
  });

  Map<String, dynamic> toJson() => {
    'cwd': cwd,
    'runtime': runtime,
    if (useWorktree) 'useWorktree': true,
    if (permissionMode != null && permissionMode!.isNotEmpty)
      'permissionMode': permissionMode,
  };
}

class RpcSessionLoadParamsDto {
  final String sessionId;
  final String cwd;
  final String runtime;
  final String? permissionMode;
  final String? model;

  const RpcSessionLoadParamsDto({
    required this.sessionId,
    required this.cwd,
    required this.runtime,
    this.permissionMode,
    this.model,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'cwd': cwd,
    'runtime': runtime,
    if (permissionMode != null && permissionMode!.isNotEmpty)
      'permissionMode': permissionMode,
    if (model != null && model!.isNotEmpty && model != 'default')
      'model': model,
  };
}

class RpcFsListParamsDto {
  final String sessionId;
  final String path;

  const RpcFsListParamsDto({required this.sessionId, required this.path});

  Map<String, dynamic> toJson() => {'sessionId': sessionId, 'path': path};
}

class RpcFsSearchParamsDto {
  final String sessionId;
  final String query;

  const RpcFsSearchParamsDto({required this.sessionId, required this.query});

  Map<String, dynamic> toJson() => {'sessionId': sessionId, 'query': query};
}

class RpcResyncEventsParamsDto {
  final int lastSeq;
  final int? streamEpoch;

  const RpcResyncEventsParamsDto({required this.lastSeq, this.streamEpoch});

  Map<String, dynamic> toJson() => {
    'lastSeq': lastSeq,
    if (streamEpoch != null && streamEpoch! > 0) 'streamEpoch': streamEpoch,
  };
}

class RpcResyncEventsPageParamsDto {
  final int lastSeq;
  final int? streamEpoch;
  final int? maxBytes;
  final int? maxEvents;

  const RpcResyncEventsPageParamsDto({
    required this.lastSeq,
    this.streamEpoch,
    this.maxBytes,
    this.maxEvents,
  });

  Map<String, dynamic> toJson() => {
    'lastSeq': lastSeq,
    if (streamEpoch != null && streamEpoch! > 0) 'streamEpoch': streamEpoch,
    if (maxBytes != null && maxBytes! > 0) 'maxBytes': maxBytes,
    if (maxEvents != null && maxEvents! > 0) 'maxEvents': maxEvents,
  };
}

class RpcSessionResolveParamsDto {
  final List<String> sessionIds;
  final String? runtime;

  const RpcSessionResolveParamsDto({required this.sessionIds, this.runtime});

  Map<String, dynamic> toJson() => {
    'sessionIds': sessionIds,
    if (runtime != null && runtime!.isNotEmpty) 'runtime': runtime,
  };
}

class RpcSessionSetModeParamsDto {
  final String sessionId;
  final String permissionMode;

  const RpcSessionSetModeParamsDto({
    required this.sessionId,
    required this.permissionMode,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'permissionMode': permissionMode,
  };
}

class RpcSessionSetConfigOptionParamsDto {
  final String sessionId;
  final String configId;
  final String value;

  const RpcSessionSetConfigOptionParamsDto({
    required this.sessionId,
    required this.configId,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'configId': configId,
    'value': value,
  };
}

class PromptContentBlockDto {
  final String type;
  final String? text;
  final String? mimeType;
  final String? data;
  final String? uri;

  const PromptContentBlockDto({
    required this.type,
    this.text,
    this.mimeType,
    this.data,
    this.uri,
  });

  factory PromptContentBlockDto.fromDomain(PromptContentBlock block) {
    return PromptContentBlockDto(
      type: block.type,
      text: block.text,
      mimeType: block.mimeType,
      data: block.data,
      uri: block.uri,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (text != null) 'text': text,
    if (mimeType != null) 'mimeType': mimeType,
    if (data != null) 'data': data,
    if (uri != null) 'uri': uri,
  };
}

class RpcSessionPromptParamsDto {
  final String sessionId;
  final List<PromptContentBlockDto> content;

  const RpcSessionPromptParamsDto({
    required this.sessionId,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'content': content.map((block) => block.toJson()).toList(),
  };
}

class RpcApprovalReplyParamsDto {
  final String sessionId;
  final String requestId;
  final String optionId;

  const RpcApprovalReplyParamsDto({
    required this.sessionId,
    required this.requestId,
    required this.optionId,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'requestId': requestId,
    'optionId': optionId,
  };
}

class RpcSessionCancelParamsDto {
  final String sessionId;

  const RpcSessionCancelParamsDto({required this.sessionId});

  Map<String, dynamic> toJson() => {'sessionId': sessionId};
}
