import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:muxagent/i18n/app_locales.dart';
import 'package:muxagent/i18n/app_translations.dart';

void registerTestTranslations({Locale locale = AppLocales.enUS}) {
  Get.testMode = true;
  Get.clearTranslations();
  Get.addTranslations(AppTranslations().keys);
  Get.locale = locale;
  Get.fallbackLocale = AppLocales.enUS;
}

Widget localizedTestApp({
  required Widget child,
  Locale locale = AppLocales.enUS,
}) {
  return GetMaterialApp(
    translations: AppTranslations(),
    locale: locale,
    fallbackLocale: AppLocales.enUS,
    supportedLocales: AppLocales.supported,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}
