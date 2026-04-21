import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/language_preference_repository.dart';
import 'package:muxagent/i18n/app_locales.dart';
import 'package:muxagent/ui/language/language_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageViewModel', () {
    late LanguagePreferenceRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      registerTestTranslations(locale: AppLocales.zhCN);
      repository = LanguagePreferenceRepository();
    });

    tearDown(Get.reset);

    test('initial selected locale follows the current Get locale', () {
      final viewModel = LanguageViewModel(repository: repository);
      viewModel.onInit();

      expect(viewModel.selectedLocale.value, AppLocales.zhCN);
    });

    test('language options stay aligned with supported locales', () {
      expect(
        LanguageViewModel.options.map((option) => option.locale),
        AppLocales.supported,
      );
    });

    testWidgets(
      'selecting Simplified Chinese persists and updates Get locale',
      (tester) async {
        registerTestTranslations();
        await tester.pumpWidget(
          localizedTestApp(child: const SizedBox.shrink()),
        );
        final viewModel = LanguageViewModel(
          repository: repository,
          updateLocale: (locale) async {
            Get.locale = locale;
          },
        );
        viewModel.onInit();

        await viewModel.selectLocale(AppLocales.zhCN);
        await tester.pump();

        expect(viewModel.selectedLocale.value, AppLocales.zhCN);
        expect(await repository.getPreferredLocale(), AppLocales.zhCN);
        expect(Get.locale, AppLocales.zhCN);
      },
    );
  });
}
