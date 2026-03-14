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

class AppCostInfoDto {
  final double costAmount;
  final String costCurrency;
  final int totalTokens;

  const AppCostInfoDto({
    required this.costAmount,
    required this.costCurrency,
    required this.totalTokens,
  });

  factory AppCostInfoDto.fromJson(Map<String, dynamic> json) {
    return AppCostInfoDto(
      costAmount: (json['costAmount'] as num?)?.toDouble() ?? 0,
      costCurrency: json['costCurrency'] as String? ?? 'USD',
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
    );
  }
}

class AppSessionStatusDto {
  final String id;
  final String title;
  final String status;
  final String? model;
  final AppCostInfoDto? cost;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const AppSessionStatusDto({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.model,
    this.cost,
    this.metadata,
  });

  factory AppSessionStatusDto.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    if (createdAt is! String) {
      throw FormatException('Expected "createdAt" to be a string');
    }
    if (updatedAt is! String) {
      throw FormatException('Expected "updatedAt" to be a string');
    }

    return AppSessionStatusDto(
      id: _requireString(json, 'id'),
      title: json['title'] as String? ?? '',
      status: _requireString(json, 'status'),
      model: _nullableString(json, 'model'),
      cost: switch (json['cost']) {
        null => null,
        final Map value => AppCostInfoDto.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => throw FormatException('Expected "cost" to be an object or null'),
      },
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      metadata: _nullableObject(json, 'metadata'),
    );
  }
}

class SessionStatusWireDto {
  final AppSessionStatusDto app;

  const SessionStatusWireDto({required this.app});

  factory SessionStatusWireDto.fromJson(Map<String, dynamic> json) {
    return SessionStatusWireDto(
      app: AppSessionStatusDto.fromJson(_requireObject(json, 'app')),
    );
  }
}

class SessionStatusEventEnvelopeDto {
  final String type;
  final String? sessionId;
  final int seq;
  final DateTime? at;
  final SessionStatusWireDto sessionStatus;

  const SessionStatusEventEnvelopeDto({
    required this.type,
    required this.sessionStatus,
    this.sessionId,
    this.seq = 0,
    this.at,
  });

  factory SessionStatusEventEnvelopeDto.fromJson(Map<String, dynamic> json) {
    return SessionStatusEventEnvelopeDto(
      type: _requireString(json, 'type'),
      sessionId: _nullableString(json, 'sessionId'),
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      at: switch (json['at']) {
        null => null,
        final String value => DateTime.parse(value),
        _ => throw FormatException('Expected "at" to be a string or null'),
      },
      sessionStatus: SessionStatusWireDto.fromJson(
        _requireObject(json, 'sessionStatus'),
      ),
    );
  }
}

class AppSessionErrorDto {
  final String code;
  final String message;

  const AppSessionErrorDto({required this.code, required this.message});

  factory AppSessionErrorDto.fromJson(Map<String, dynamic> json) {
    return AppSessionErrorDto(
      code: _requireString(json, 'code'),
      message: _requireString(json, 'message'),
    );
  }
}

class AppRunFailedDto {
  final AppSessionErrorDto error;

  const AppRunFailedDto({required this.error});

  factory AppRunFailedDto.fromJson(Map<String, dynamic> json) {
    return AppRunFailedDto(
      error: AppSessionErrorDto.fromJson(_requireObject(json, 'error')),
    );
  }
}

class RunFailedWireDto {
  final AppRunFailedDto app;

  const RunFailedWireDto({required this.app});

  factory RunFailedWireDto.fromJson(Map<String, dynamic> json) {
    return RunFailedWireDto(
      app: AppRunFailedDto.fromJson(_requireObject(json, 'app')),
    );
  }
}

class RunFailedEventEnvelopeDto {
  final String type;
  final String? sessionId;
  final int seq;
  final DateTime? at;
  final RunFailedWireDto runFailed;

  const RunFailedEventEnvelopeDto({
    required this.type,
    required this.runFailed,
    this.sessionId,
    this.seq = 0,
    this.at,
  });

  factory RunFailedEventEnvelopeDto.fromJson(Map<String, dynamic> json) {
    return RunFailedEventEnvelopeDto(
      type: _requireString(json, 'type'),
      sessionId: _nullableString(json, 'sessionId'),
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      at: switch (json['at']) {
        null => null,
        final String value => DateTime.parse(value),
        _ => throw FormatException('Expected "at" to be a string or null'),
      },
      runFailed: RunFailedWireDto.fromJson(_requireObject(json, 'runFailed')),
    );
  }
}
