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

  Map<String, dynamic> toJson() => {
    if (costAmount != 0) 'costAmount': costAmount,
    if (costCurrency != 'USD') 'costCurrency': costCurrency,
    if (totalTokens != 0) 'totalTokens': totalTokens,
  };
}
