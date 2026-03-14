class AppRunFinishedDto {
  final String stopReason;
  final int inputTokens;
  final int outputTokens;
  final int cachedReadTokens;
  final int cachedWriteTokens;
  final int totalTokens;

  const AppRunFinishedDto({
    required this.stopReason,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedReadTokens = 0,
    this.cachedWriteTokens = 0,
    this.totalTokens = 0,
  });

  factory AppRunFinishedDto.fromJson(Map<String, dynamic> json) {
    int intOrZero(String key) => (json[key] as num?)?.toInt() ?? 0;

    return AppRunFinishedDto(
      stopReason:
          json['stopReason'] as String? ??
          (throw FormatException('Expected "stopReason" to be a string')),
      inputTokens: intOrZero('inputTokens'),
      outputTokens: intOrZero('outputTokens'),
      cachedReadTokens: intOrZero('cachedReadTokens'),
      cachedWriteTokens: intOrZero('cachedWriteTokens'),
      totalTokens: intOrZero('totalTokens'),
    );
  }
}

class RunFinishedWireDto {
  final AppRunFinishedDto app;

  const RunFinishedWireDto({required this.app});

  factory RunFinishedWireDto.fromJson(Map<String, dynamic> json) {
    final app = json['app'];
    if (app is! Map) {
      throw FormatException('Expected "app" to be an object');
    }
    return RunFinishedWireDto(
      app: AppRunFinishedDto.fromJson(Map<String, dynamic>.from(app)),
    );
  }
}

class RunFinishedEventEnvelopeDto {
  final String type;
  final String? sessionId;
  final int seq;
  final DateTime? at;
  final RunFinishedWireDto runFinished;

  const RunFinishedEventEnvelopeDto({
    required this.type,
    required this.runFinished,
    this.sessionId,
    this.seq = 0,
    this.at,
  });

  factory RunFinishedEventEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final runFinished = json['runFinished'];
    if (runFinished is! Map) {
      throw FormatException('Expected "runFinished" to be an object');
    }
    return RunFinishedEventEnvelopeDto(
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
      runFinished: RunFinishedWireDto.fromJson(
        Map<String, dynamic>.from(runFinished),
      ),
    );
  }
}
