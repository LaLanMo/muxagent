import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/i18n/app_locales.dart';

void main() {
  test('initial locale defaults to English for unsupported device locales', () {
    expect(AppLocales.initialLocale(const Locale('fr', 'FR')), AppLocales.enUS);
  });

  test(
    'initial locale follows a supported Simplified Chinese device locale',
    () {
      expect(
        AppLocales.initialLocale(const Locale('zh', 'CN')),
        AppLocales.zhCN,
      );
    },
  );

  test('initial locale matches supported languages without exact region', () {
    expect(
      AppLocales.initialLocale(const Locale('zh', 'Hans')),
      AppLocales.zhCN,
    );
    expect(AppLocales.initialLocale(const Locale('en', 'GB')), AppLocales.enUS);
  });
}
