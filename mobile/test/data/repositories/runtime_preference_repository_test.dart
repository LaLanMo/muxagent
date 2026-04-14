import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/repositories/runtime_preference_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RuntimePreferenceRepository', () {
    late RuntimePreferenceRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = RuntimePreferenceRepository();
    });

    test('returns null when no runtime has been stored', () async {
      expect(await repository.getLastSelectedRuntimeId(), isNull);
    });

    test('stores and retrieves the last selected runtime id', () async {
      await repository.setLastSelectedRuntimeId('codex');

      expect(await repository.getLastSelectedRuntimeId(), 'codex');
    });

    test(
      'stores and retrieves the last selected mode id per runtime',
      () async {
        await repository.setLastSelectedModeId(
          runtimeId: 'claude-code',
          modeId: 'bypassPermissions',
        );
        await repository.setLastSelectedModeId(
          runtimeId: 'codex',
          modeId: 'full-access',
        );

        expect(
          await repository.getLastSelectedModeId('claude-code'),
          'bypassPermissions',
        );
        expect(await repository.getLastSelectedModeId('codex'), 'full-access');
      },
    );

    test('returns null when no mode has been stored for a runtime', () async {
      expect(await repository.getLastSelectedModeId('claude-code'), isNull);
    });

    test('returns remembered mode ids only for requested runtimes', () async {
      await repository.setLastSelectedModeId(
        runtimeId: 'claude-code',
        modeId: 'acceptEdits',
      );
      await repository.setLastSelectedModeId(
        runtimeId: 'codex',
        modeId: 'read-only',
      );

      expect(
        await repository.getLastSelectedModeIds([
          'claude-code',
          'custom-runtime',
        ]),
        {'claude-code': 'acceptEdits'},
      );
    });
  });
}
