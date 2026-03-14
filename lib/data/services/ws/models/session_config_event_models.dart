import 'acp_session_models.dart';

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

class ModeChangedEventEnvelopeDto {
  final String type;
  final String? sessionId;
  final int seq;
  final DateTime? at;
  final AppModeChangedEventDataDto modeChanged;

  const ModeChangedEventEnvelopeDto({
    required this.type,
    required this.modeChanged,
    this.sessionId,
    this.seq = 0,
    this.at,
  });

  factory ModeChangedEventEnvelopeDto.fromJson(Map<String, dynamic> json) {
    return ModeChangedEventEnvelopeDto(
      type: _requireString(json, 'type'),
      sessionId: _nullableString(json, 'sessionId'),
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      at: switch (json['at']) {
        null => null,
        final String value => DateTime.parse(value),
        _ => throw FormatException('Expected "at" to be a string or null'),
      },
      modeChanged: AppModeChangedEventDataDto.fromJson(
        _requireObject(json, 'modeChanged'),
      ),
    );
  }
}

class ConfigChangedEventEnvelopeDto {
  final String type;
  final String? sessionId;
  final int seq;
  final DateTime? at;
  final AppConfigChangedEventDataDto configChanged;

  const ConfigChangedEventEnvelopeDto({
    required this.type,
    required this.configChanged,
    this.sessionId,
    this.seq = 0,
    this.at,
  });

  factory ConfigChangedEventEnvelopeDto.fromJson(Map<String, dynamic> json) {
    return ConfigChangedEventEnvelopeDto(
      type: _requireString(json, 'type'),
      sessionId: _nullableString(json, 'sessionId'),
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      at: switch (json['at']) {
        null => null,
        final String value => DateTime.parse(value),
        _ => throw FormatException('Expected "at" to be a string or null'),
      },
      configChanged: AppConfigChangedEventDataDto.fromJson(
        _requireObject(json, 'configChanged'),
      ),
    );
  }
}
