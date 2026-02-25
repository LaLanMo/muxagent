class CostInfo {
  final double totalUsd;
  final int inputTokens;
  final int outputTokens;
  final int cacheRead;
  final int cacheWrite;

  CostInfo({
    this.totalUsd = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheRead = 0,
    this.cacheWrite = 0,
  });

  factory CostInfo.fromJson(Map<String, dynamic> json) {
    return CostInfo(
      totalUsd: (json['totalUsd'] as num?)?.toDouble() ?? 0,
      inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
      outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
      cacheRead: (json['cacheRead'] as num?)?.toInt() ?? 0,
      cacheWrite: (json['cacheWrite'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (totalUsd != 0) 'totalUsd': totalUsd,
        if (inputTokens != 0) 'inputTokens': inputTokens,
        if (outputTokens != 0) 'outputTokens': outputTokens,
        if (cacheRead != 0) 'cacheRead': cacheRead,
        if (cacheWrite != 0) 'cacheWrite': cacheWrite,
      };
}
