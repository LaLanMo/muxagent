import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/language_preference_repository.dart';
import 'package:muxagent/i18n/app_locales.dart';
import 'package:muxagent/ui/language/language_screen.dart';
import 'package:muxagent/ui/language/language_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageScreen', () {
    late LanguagePreferenceRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      registerTestTranslations();
      repository = LanguagePreferenceRepository();
      Get.put<LanguagePreferenceRepository>(repository);
    });

    tearDown(Get.reset);

    void registerViewModel({Locale locale = AppLocales.enUS}) {
      registerTestTranslations(locale: locale);
      Get.put<LanguageViewModel>(
        LanguageViewModel(
          repository: repository,
          updateLocale: (locale) async {
            Get.locale = locale;
          },
        ),
      );
    }

    testWidgets('renders only supported language options', (tester) async {
      registerViewModel();

      await tester.pumpWidget(localizedTestApp(child: const LanguageScreen()));

      expect(find.text('APP LANGUAGE'), findsOneWidget);
      expect(find.text('English'), findsNWidgets(2));
      expect(find.text('简体中文'), findsOneWidget);
      expect(find.text('Chinese (Simplified)'), findsOneWidget);
      expect(find.text('Japanese'), findsNothing);
      expect(find.text('日本語'), findsNothing);
      expect(find.text('Spanish'), findsNothing);
      expect(find.text('Español'), findsNothing);
    });

    testWidgets('shows selected radio state for the active locale', (
      tester,
    ) async {
      registerViewModel(locale: AppLocales.zhCN);

      await tester.pumpWidget(
        localizedTestApp(
          locale: AppLocales.zhCN,
          child: const LanguageScreen(),
        ),
      );

      expect(
        find.byKey(const ValueKey('language-radio-zh_CN-selected')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('language-radio-en_US-unselected')),
        findsOneWidget,
      );
    });

    testWidgets('tapping Simplified Chinese updates translated chrome', (
      tester,
    ) async {
      registerViewModel();

      await tester.pumpWidget(localizedTestApp(child: const LanguageScreen()));

      await tester.tap(find.byKey(const ValueKey('language-option-zh_CN')));
      await tester.pump();

      expect(Get.locale, AppLocales.zhCN);
      expect(
        Get.find<LanguageViewModel>().selectedLocale.value,
        AppLocales.zhCN,
      );
      expect(await repository.getPreferredLocale(), AppLocales.zhCN);
      expect(
        find.byKey(const ValueKey('language-radio-zh_CN-selected')),
        findsOneWidget,
      );
      expect(find.text('语言'), findsOneWidget);
      expect(find.text('应用语言'), findsOneWidget);
    });
  });
}
