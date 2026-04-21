import 'dart:ui';

class AppLocales {
  static const enUS = Locale('en', 'US');
  static const zhCN = Locale('zh', 'CN');
  static const defaultLocale = enUS;

  static const supported = <Locale>[enUS, zhCN];

  static Locale initialLocale([Locale? deviceLocale]) =>
      localeFor(deviceLocale ?? PlatformDispatcher.instance.locale);

  static Locale localeFor(Locale? locale) {
    if (locale == null) {
      return defaultLocale;
    }

    for (final supportedLocale in supported) {
      if (supportedLocale.languageCode == locale.languageCode &&
          supportedLocale.countryCode == locale.countryCode) {
        return supportedLocale;
      }
    }

    for (final supportedLocale in supported) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }

    return defaultLocale;
  }
}
