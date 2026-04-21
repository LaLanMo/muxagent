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

  test('returns canonical locale tags for supported locales', () {
    expect(AppLocales.tagFor(AppLocales.enUS), 'en_US');
    expect(AppLocales.tagFor(AppLocales.zhCN), 'zh_CN');
  });

  test('localeForTag accepts canonical and hyphenated supported tags', () {
    expect(AppLocales.localeForTag('en_US'), AppLocales.enUS);
    expect(AppLocales.localeForTag('en-US'), AppLocales.enUS);
    expect(AppLocales.localeForTag('zh_CN'), AppLocales.zhCN);
    expect(AppLocales.localeForTag('zh-CN'), AppLocales.zhCN);
  });

  test('localeForTag rejects empty or unsupported tags', () {
    expect(AppLocales.localeForTag(null), isNull);
    expect(AppLocales.localeForTag(''), isNull);
    expect(AppLocales.localeForTag('fr_FR'), isNull);
    expect(AppLocales.localeForTag('zh_TW'), isNull);
    expect(AppLocales.localeForTag('not-a-locale'), isNull);
  });
}
