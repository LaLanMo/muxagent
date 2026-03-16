Map<String, dynamic>? _nullableObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected "$key" to be an object or null');
}

Map<String, dynamic> _requireObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected "$key" to be an object');
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

class AcpContentBlockDto {
  final Map<String, dynamic>? meta;
  final String type;
  final String? text;
  final Map<String, dynamic> raw;

  const AcpContentBlockDto({
    required this.type,
    required this.raw,
    this.text,
    this.meta,
  });

  factory AcpContentBlockDto.fromJson(Map<String, dynamic> json) {
    return AcpContentBlockDto(
      meta: _nullableObject(json, '_meta'),
      type: _requireString(json, 'type'),
      text: _nullableString(json, 'text'),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);
}

class AcpContentChunkDto {
  final Map<String, dynamic>? meta;
  final String sessionUpdate;
  final String? messageId;
  final AcpContentBlockDto content;

  const AcpContentChunkDto({
    required this.sessionUpdate,
    required this.content,
    this.messageId,
    this.meta,
  });

  factory AcpContentChunkDto.fromJson(Map<String, dynamic> json) {
    return AcpContentChunkDto(
      meta: _nullableObject(json, '_meta'),
      sessionUpdate: _requireString(json, 'sessionUpdate'),
      messageId: _nullableString(json, 'messageId'),
      content: AcpContentBlockDto.fromJson(_requireObject(json, 'content')),
    );
  }

  Map<String, dynamic> toJson() => {
    if (meta != null) '_meta': meta,
    'sessionUpdate': sessionUpdate,
    if (messageId != null) 'messageId': messageId,
    'content': content.toJson(),
  };
}

class AppMessagePartDto {
  final String partId;
  final String messageId;
  final String role;
  final String delta;
  final String partType;
  final String fullText;

  const AppMessagePartDto({
    required this.partId,
    required this.messageId,
    required this.role,
    required this.delta,
    required this.partType,
    this.fullText = '',
  });

  factory AppMessagePartDto.fromJson(Map<String, dynamic> json) {
    final fullText = json['fullText'];
    if (fullText != null && fullText is! String) {
      throw FormatException('Expected "fullText" to be a string or null');
    }

    return AppMessagePartDto(
      partId: _requireString(json, 'partId'),
      messageId: _requireString(json, 'messageId'),
      role: _requireString(json, 'role'),
      delta: _requireString(json, 'delta'),
      partType: _requireString(json, 'partType'),
      fullText: fullText as String? ?? '',
    );
  }
}

class MessagePartWireDto {
  final AppMessagePartDto app;
  final AcpContentChunkDto? acp;

  const MessagePartWireDto({required this.app, this.acp});

  factory MessagePartWireDto.fromJson(Map<String, dynamic> json) {
    return MessagePartWireDto(
      app: AppMessagePartDto.fromJson(_requireObject(json, 'app')),
      acp: switch (json['acp']) {
        null => null,
        final Map value => AcpContentChunkDto.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => throw FormatException('Expected "acp" to be an object or null'),
      },
    );
  }
}

class MessageEventEnvelopeDto {
  final String type;
  final String? sessionId;
  final int seq;
  final DateTime? at;
  final MessagePartWireDto messagePart;

  const MessageEventEnvelopeDto({
    required this.type,
    required this.messagePart,
    this.sessionId,
    this.seq = 0,
    this.at,
  });

  factory MessageEventEnvelopeDto.fromJson(Map<String, dynamic> json) {
    return MessageEventEnvelopeDto(
      type: _requireString(json, 'type'),
      sessionId: json['sessionId'] as String?,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      at: switch (json['at']) {
        null => null,
        final String value => DateTime.parse(value),
        _ => throw FormatException('Expected "at" to be a string or null'),
      },
      messagePart: MessagePartWireDto.fromJson(
        _requireObject(json, 'messagePart'),
      ),
    );
  }
}
