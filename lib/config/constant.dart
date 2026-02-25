class AppConstants {
  static const String appName = 'MuxAgent';

  // Auth request expiration time
  static const Duration authRequestTimeout = Duration(minutes: 5);

  // Polling interval for auth status
  static const Duration authPollInterval = Duration(seconds: 2);
}
