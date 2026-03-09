class CostInfo {
  final double costAmount;
  final String costCurrency;
  final int totalTokens;

  CostInfo({
    this.costAmount = 0,
    this.costCurrency = 'USD',
    this.totalTokens = 0,
  });

  bool get hasCost => costAmount > 0;

  factory CostInfo.fromJson(Map<String, dynamic> json) {
    return CostInfo(
      costAmount: (json['costAmount'] as num?)?.toDouble() ?? 0,
      costCurrency: json['costCurrency'] as String? ?? 'USD',
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (costAmount != 0) 'costAmount': costAmount,
        if (costCurrency != 'USD') 'costCurrency': costCurrency,
        if (totalTokens != 0) 'totalTokens': totalTokens,
      };
}
