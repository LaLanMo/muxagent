/// In-memory model for live usage display (mutable, updated by events).
class UsageInfo {
  double costAmount = 0;
  String costCurrency = 'USD';
  int contextUsed = 0;
  int contextSize = 0;
  int totalTokens = 0;
  int inputTokens = 0;
  int outputTokens = 0;
  int cachedReadTokens = 0;
  int cachedWriteTokens = 0;

  double get contextPercent =>
      contextSize > 0 ? contextUsed / contextSize : 0;

  bool get hasCost => costAmount > 0;
  bool get hasContext => contextSize > 0;
}
