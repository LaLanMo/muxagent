import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../../i18n/app_locales.dart';

class LanguagePreferenceRepository {
  static const preferredLocaleTagKey = 'preferred_locale_tag';

  Future<Locale?> getPreferredLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLocales.localeForTag(prefs.getString(preferredLocaleTagKey));
  }

  Future<void> setPreferredLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      preferredLocaleTagKey,
      AppLocales.tagFor(AppLocales.localeFor(locale)),
    );
  }
}
