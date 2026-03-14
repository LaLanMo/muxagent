import 'acp_session_models.dart';

num _requireNum(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value;
  throw FormatException('Expected "$key" to be a number');
}

class AppUsageUpdateDto {
  final int contextUsed;
  final int contextSize;
  final double? costAmount;
  final String? costCurrency;

  const AppUsageUpdateDto({
    required this.contextUsed,
    required this.contextSize,
    this.costAmount,
    this.costCurrency,
  });

  factory AppUsageUpdateDto.fromJson(Map<String, dynamic> json) {
    final rawCostAmount = json['costAmount'];
    if (rawCostAmount != null && rawCostAmount is! num) {
      throw FormatException('Expected "costAmount" to be a number or null');
    }
    final rawCostCurrency = json['costCurrency'];
    if (rawCostCurrency != null && rawCostCurrency is! String) {
      throw FormatException('Expected "costCurrency" to be a string or null');
    }

    return AppUsageUpdateDto(
      contextUsed: _requireNum(json, 'contextUsed').toInt(),
      contextSize: _requireNum(json, 'contextSize').toInt(),
      costAmount: rawCostAmount?.toDouble(),
      costCurrency: rawCostCurrency as String?,
    );
  }
}

class UsageWireDto {
  final AppUsageUpdateDto app;
  final AcpUsageUpdateDto? acp;

  const UsageWireDto({required this.app, this.acp});

  factory UsageWireDto.fromJson(Map<String, dynamic> json) {
    return UsageWireDto(
      app: AppUsageUpdateDto.fromJson(
        Map<String, dynamic>.from(json['app'] as Map),
      ),
      acp: switch (json['acp']) {
        null => null,
        final Map value => AcpUsageUpdateDto.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => throw FormatException('Expected "acp" to be an object or null'),
      },
    );
  }
}

class UsageEventEnvelopeDto {
  final String type;
  final String? sessionId;
  final int seq;
  final DateTime? at;
  final UsageWireDto usage;

  const UsageEventEnvelopeDto({
    required this.type,
    required this.usage,
    this.sessionId,
    this.seq = 0,
    this.at,
  });

  factory UsageEventEnvelopeDto.fromJson(Map<String, dynamic> json) {
    return UsageEventEnvelopeDto(
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
      usage: UsageWireDto.fromJson(
        Map<String, dynamic>.from(json['usage'] as Map),
      ),
    );
  }
}
