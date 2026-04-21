import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/i18n/app_locales.dart';

void main() {
  test('initial locale defaults to English for unsupported device locales', () {
    expect(AppLocales.initialLocale(const Locale('it', 'IT')), AppLocales.enUS);
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
    expect(AppLocales.initialLocale(const Locale('ja')), AppLocales.jaJP);
    expect(AppLocales.initialLocale(const Locale('ko')), AppLocales.koKR);
    expect(AppLocales.initialLocale(const Locale('es', 'MX')), AppLocales.esES);
    expect(AppLocales.initialLocale(const Locale('fr', 'CA')), AppLocales.frFR);
    expect(AppLocales.initialLocale(const Locale('de')), AppLocales.deDE);
    expect(AppLocales.initialLocale(const Locale('pt', 'PT')), AppLocales.ptBR);
  });

  test('returns canonical locale tags for supported locales', () {
    expect(AppLocales.tagFor(AppLocales.enUS), 'en_US');
    expect(AppLocales.tagFor(AppLocales.zhCN), 'zh_CN');
    expect(AppLocales.tagFor(AppLocales.jaJP), 'ja_JP');
    expect(AppLocales.tagFor(AppLocales.koKR), 'ko_KR');
    expect(AppLocales.tagFor(AppLocales.esES), 'es_ES');
    expect(AppLocales.tagFor(AppLocales.frFR), 'fr_FR');
    expect(AppLocales.tagFor(AppLocales.deDE), 'de_DE');
    expect(AppLocales.tagFor(AppLocales.ptBR), 'pt_BR');
  });

  test('localeForTag accepts canonical and hyphenated supported tags', () {
    expect(AppLocales.localeForTag('en_US'), AppLocales.enUS);
    expect(AppLocales.localeForTag('en-US'), AppLocales.enUS);
    expect(AppLocales.localeForTag('zh_CN'), AppLocales.zhCN);
    expect(AppLocales.localeForTag('zh-CN'), AppLocales.zhCN);
    expect(AppLocales.localeForTag('ja_JP'), AppLocales.jaJP);
    expect(AppLocales.localeForTag('ja-JP'), AppLocales.jaJP);
    expect(AppLocales.localeForTag('ko_KR'), AppLocales.koKR);
    expect(AppLocales.localeForTag('ko-KR'), AppLocales.koKR);
    expect(AppLocales.localeForTag('es_ES'), AppLocales.esES);
    expect(AppLocales.localeForTag('es-ES'), AppLocales.esES);
    expect(AppLocales.localeForTag('fr_FR'), AppLocales.frFR);
    expect(AppLocales.localeForTag('fr-FR'), AppLocales.frFR);
    expect(AppLocales.localeForTag('de_DE'), AppLocales.deDE);
    expect(AppLocales.localeForTag('de-DE'), AppLocales.deDE);
    expect(AppLocales.localeForTag('pt_BR'), AppLocales.ptBR);
    expect(AppLocales.localeForTag('pt-BR'), AppLocales.ptBR);
  });

  test('localeForTag rejects empty or unsupported tags', () {
    expect(AppLocales.localeForTag(null), isNull);
    expect(AppLocales.localeForTag(''), isNull);
    expect(AppLocales.localeForTag('it_IT'), isNull);
    expect(AppLocales.localeForTag('zh_TW'), isNull);
    expect(AppLocales.localeForTag('not-a-locale'), isNull);
  });
}
