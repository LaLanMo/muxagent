import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/domain/runtime_option.dart';
import 'package:muxagent/ui/new_session/new_session_viewmodel.dart';

RuntimeOption buildRuntime(String id) {
  return RuntimeOption(
    id: id,
    label: id,
    ready: true,
    defaultModeId: '',
    modeOptions: const [],
  );
}

void main() {
  group('NewSessionViewModel.resolveSelectedRuntime', () {
    test('preserves the current runtime when it is still available', () {
      final codex = buildRuntime('codex');
      final result = NewSessionViewModel.resolveSelectedRuntime(
        options: [buildRuntime('claude-code'), codex],
        current: buildRuntime('codex'),
      );

      expect(identical(result, codex), isTrue);
    });

    test('auto-selects the only available runtime', () {
      final claudeCode = buildRuntime('claude-code');
      final result = NewSessionViewModel.resolveSelectedRuntime(
        options: [claudeCode],
      );

      expect(identical(result, claudeCode), isTrue);
    });

    test(
      'defaults to Claude code when Claude and Codex are both available',
      () {
        final claudeCode = buildRuntime('claude-code');
        final result = NewSessionViewModel.resolveSelectedRuntime(
          options: [buildRuntime('codex'), claudeCode],
        );

        expect(identical(result, claudeCode), isTrue);
      },
    );

    test(
      'requires explicit selection for other multi-runtime combinations',
      () {
        final result = NewSessionViewModel.resolveSelectedRuntime(
          options: [buildRuntime('codex'), buildRuntime('custom-runtime')],
        );

        expect(result, isNull);
      },
    );
  });
}
