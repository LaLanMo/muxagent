import 'acp_session_models.dart';

List<Map<String, dynamic>> _objectList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
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

class AppPlanEntryDto {
  final String content;
  final String priority;
  final String status;

  const AppPlanEntryDto({
    required this.content,
    required this.priority,
    required this.status,
  });

  factory AppPlanEntryDto.fromJson(Map<String, dynamic> json) {
    return AppPlanEntryDto(
      content:
          json['content'] as String? ??
          (throw FormatException('Expected "content" to be a string')),
      priority:
          json['priority'] as String? ??
          (throw FormatException('Expected "priority" to be a string')),
      status:
          json['status'] as String? ??
          (throw FormatException('Expected "status" to be a string')),
    );
  }
}

class AppPlanUpdateDto {
  final List<AppPlanEntryDto> entries;

  const AppPlanUpdateDto({required this.entries});

  factory AppPlanUpdateDto.fromJson(Map<String, dynamic> json) {
    return AppPlanUpdateDto(
      entries: _objectList(
        json,
        'entries',
      ).map(AppPlanEntryDto.fromJson).toList(),
    );
  }
}

class PlanWireDto {
  final AppPlanUpdateDto app;
  final AcpPlanUpdateDto? acp;

  const PlanWireDto({required this.app, this.acp});

  factory PlanWireDto.fromJson(Map<String, dynamic> json) {
    return PlanWireDto(
      app: AppPlanUpdateDto.fromJson(
        Map<String, dynamic>.from(json['app'] as Map),
      ),
      acp: switch (json['acp']) {
        null => null,
        final Map value => AcpPlanUpdateDto.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => throw FormatException('Expected "acp" to be an object or null'),
      },
    );
  }
}

class PlanEventEnvelopeDto {
  final String type;
  final String? sessionId;
  final int seq;
  final DateTime? at;
  final PlanWireDto plan;

  const PlanEventEnvelopeDto({
    required this.type,
    required this.plan,
    this.sessionId,
    this.seq = 0,
    this.at,
  });

  factory PlanEventEnvelopeDto.fromJson(Map<String, dynamic> json) {
    return PlanEventEnvelopeDto(
      type:
          json['type'] as String? ??
          (throw FormatException('Expected "type" to be a string')),
      sessionId: json['sessionId'] as String?,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      at: switch (json['at']) {
        null => null,
        final String value => DateTime.parse(value),
        _ => throw FormatException('Expected "at" to be a string or null'),
      },
      plan: PlanWireDto.fromJson(
        Map<String, dynamic>.from(json['plan'] as Map),
      ),
    );
  }
}
