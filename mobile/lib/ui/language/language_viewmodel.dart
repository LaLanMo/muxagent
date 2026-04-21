import 'dart:ui';

import 'package:get/get.dart';

import '../../data/repositories/language_preference_repository.dart';
import '../../i18n/app_locales.dart';

typedef LocaleUpdater = Future<void> Function(Locale locale);

class LanguageOption {
  const LanguageOption({
    required this.locale,
    required this.title,
    required this.subtitle,
  });

  final Locale locale;
  final String title;
  final String subtitle;
}

class LanguageViewModel extends GetxController {
  LanguageViewModel({
    required LanguagePreferenceRepository repository,
    LocaleUpdater? updateLocale,
  }) : _repository = repository,
       _updateLocale = updateLocale ?? Get.updateLocale;

  final LanguagePreferenceRepository _repository;
  final LocaleUpdater _updateLocale;

  static const options = <LanguageOption>[
    LanguageOption(
      locale: AppLocales.enUS,
      title: 'English',
      subtitle: 'English',
    ),
    LanguageOption(
      locale: AppLocales.zhCN,
      title: '简体中文',
      subtitle: 'Chinese (Simplified)',
    ),
    LanguageOption(locale: AppLocales.jaJP, title: '日本語', subtitle: 'Japanese'),
    LanguageOption(locale: AppLocales.koKR, title: '한국어', subtitle: 'Korean'),
    LanguageOption(
      locale: AppLocales.esES,
      title: 'Español',
      subtitle: 'Spanish',
    ),
    LanguageOption(
      locale: AppLocales.frFR,
      title: 'Français',
      subtitle: 'French',
    ),
    LanguageOption(
      locale: AppLocales.deDE,
      title: 'Deutsch',
      subtitle: 'German',
    ),
    LanguageOption(
      locale: AppLocales.ptBR,
      title: 'Português (Brasil)',
      subtitle: 'Portuguese (Brazil)',
    ),
  ];

  final selectedLocale = AppLocales.enUS.obs;

  @override
  void onInit() {
    super.onInit();
    selectedLocale.value = AppLocales.localeFor(Get.locale);
  }

  bool isSelected(Locale locale) => selectedLocale.value == locale;

  Future<void> selectLocale(Locale locale) async {
    if (!AppLocales.supported.contains(locale)) {
      return;
    }

    Get.locale = locale;
    selectedLocale.value = locale;
    update();
    await _repository.setPreferredLocale(locale);
    await _updateLocale(locale);
    selectedLocale.refresh();
    update();
  }
}
