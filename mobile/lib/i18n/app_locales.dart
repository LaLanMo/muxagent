import 'dart:ui';

class AppLocales {
  static const enUS = Locale('en', 'US');
  static const zhCN = Locale('zh', 'CN');
  static const jaJP = Locale('ja', 'JP');
  static const koKR = Locale('ko', 'KR');
  static const esES = Locale('es', 'ES');
  static const frFR = Locale('fr', 'FR');
  static const deDE = Locale('de', 'DE');
  static const ptBR = Locale('pt', 'BR');
  static const defaultLocale = enUS;

  static const supported = <Locale>[
    enUS,
    zhCN,
    jaJP,
    koKR,
    esES,
    frFR,
    deDE,
    ptBR,
  ];

  static Locale initialLocale([Locale? deviceLocale]) =>
      localeFor(deviceLocale ?? PlatformDispatcher.instance.locale);

  static String tagFor(Locale locale) {
    final normalized = localeFor(locale);
    return '${normalized.languageCode}_${normalized.countryCode}';
  }

  static Locale? localeForTag(String? tag) {
    final normalizedTag = tag?.trim().replaceAll('-', '_');
    if (normalizedTag == null || normalizedTag.isEmpty) {
      return null;
    }

    final parts = normalizedTag
        .split('_')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) {
      return null;
    }

    final languageCode = parts.first.toLowerCase();
    final countryCode = parts.last.toUpperCase();
    for (final supportedLocale in supported) {
      if (supportedLocale.languageCode == languageCode &&
          supportedLocale.countryCode == countryCode) {
        return supportedLocale;
      }
    }
    return null;
  }

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
