import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/repositories/language_preference_repository.dart';
import 'package:muxagent/i18n/app_locales.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguagePreferenceRepository', () {
    late LanguagePreferenceRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = LanguagePreferenceRepository();
    });

    test('returns null when no preferred locale has been stored', () async {
      expect(await repository.getPreferredLocale(), isNull);
    });

    test('stores and retrieves the preferred locale', () async {
      await repository.setPreferredLocale(AppLocales.zhCN);

      expect(await repository.getPreferredLocale(), AppLocales.zhCN);
    });

    test('normalizes saved locale tags', () async {
      await repository.setPreferredLocale(AppLocales.zhCN);
      final prefs = await SharedPreferences.getInstance();

      expect(
        prefs.getString(LanguagePreferenceRepository.preferredLocaleTagKey),
        'zh_CN',
      );
    });

    test('returns null for unsupported or malformed stored values', () async {
      for (final storedValue in ['it_IT', 'zh_TW', 'bad-value', '']) {
        SharedPreferences.setMockInitialValues({
          LanguagePreferenceRepository.preferredLocaleTagKey: storedValue,
        });

        expect(await repository.getPreferredLocale(), isNull);
      }
    });
  });
}
