import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/domain/mode_option.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/domain/runtime_option.dart';
import 'package:muxagent/ui/new_session/new_session_viewmodel.dart';

ModeOption buildMode(String id) {
  return ModeOption(id: id, label: id);
}

RuntimeOption buildRuntime(
  String id, {
  String defaultModeId = '',
  List<ModeOption> modeOptions = const [],
}) {
  return RuntimeOption(
    id: id,
    label: id,
    ready: true,
    defaultModeId: defaultModeId,
    modeOptions: modeOptions,
  );
}

PairedMachine buildMachine(String id, {String? hostname}) {
  return PairedMachine(
    machineId: id,
    relayHttpUrl: 'https://relay.test',
    machineSignPubB64: 'sign-$id',
    machineEncPubB64: 'enc-$id',
    hostname: hostname ?? id,
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

    test('prefers the remembered runtime when it is still available', () {
      final codex = buildRuntime('codex');
      final result = NewSessionViewModel.resolveSelectedRuntime(
        options: [buildRuntime('claude-code'), codex],
        rememberedRuntimeId: 'codex',
      );

      expect(identical(result, codex), isTrue);
    });

    test('falls back to the first runtime when there is no memory', () {
      final first = buildRuntime('codex');
      final result = NewSessionViewModel.resolveSelectedRuntime(
        options: [first, buildRuntime('claude-code')],
      );

      expect(identical(result, first), isTrue);
    });

    test('falls back to the first runtime when memory is unavailable', () {
      final first = buildRuntime('custom-runtime');
      final result = NewSessionViewModel.resolveSelectedRuntime(
        options: [first, buildRuntime('codex')],
        rememberedRuntimeId: 'claude-code',
      );

      expect(identical(result, first), isTrue);
    });
  });

  group('NewSessionViewModel.resolveSelectedMode', () {
    test('prefers the remembered mode for the matching runtime', () {
      final remembered = buildMode('acceptEdits');
      final result = NewSessionViewModel.resolveSelectedMode(
        runtimeId: 'claude-code',
        options: [
          buildMode('bypassPermissions'),
          remembered,
          buildMode('plan'),
        ],
        rememberedModeId: 'acceptEdits',
      );

      expect(identical(result, remembered), isTrue);
    });

    test('falls back to Skip Perms for Claude when there is no memory', () {
      final skipPerms = buildMode('bypassPermissions');
      final result = NewSessionViewModel.resolveSelectedMode(
        runtimeId: 'claude-code',
        options: [buildMode('plan'), skipPerms, buildMode('acceptEdits')],
      );

      expect(identical(result, skipPerms), isTrue);
    });

    test('falls back to Full Access for Codex when there is no memory', () {
      final fullAccess = buildMode('full-access');
      final result = NewSessionViewModel.resolveSelectedMode(
        runtimeId: 'codex',
        options: [buildMode('read-only'), fullAccess, buildMode('auto')],
      );

      expect(identical(result, fullAccess), isTrue);
    });

    test(
      'does not carry the previous runtime current mode across runtimes',
      () {
        final skipPerms = buildMode('bypassPermissions');
        final result = NewSessionViewModel.resolveSelectedMode(
          runtimeId: 'claude-code',
          options: [skipPerms, buildMode('acceptEdits')],
          current: buildMode('full-access'),
          currentRuntimeId: 'codex',
        );

        expect(identical(result, skipPerms), isTrue);
      },
    );

    test(
      'preserves the current mode when it still belongs to the same runtime',
      () {
        final acceptEdits = buildMode('acceptEdits');
        final result = NewSessionViewModel.resolveSelectedMode(
          runtimeId: 'claude-code',
          options: [buildMode('bypassPermissions'), acceptEdits],
          current: buildMode('acceptEdits'),
          currentRuntimeId: 'claude-code',
          rememberedModeId: 'bypassPermissions',
        );

        expect(identical(result, acceptEdits), isTrue);
      },
    );

    test('falls back to the runtime default for non-special runtimes', () {
      final strict = buildMode('strict');
      final result = NewSessionViewModel.resolveSelectedMode(
        runtimeId: 'custom-runtime',
        options: [buildMode('relaxed'), strict],
        runtimeDefaultModeId: 'strict',
      );

      expect(identical(result, strict), isTrue);
    });

    test('falls back to the first option when the default is unavailable', () {
      final first = buildMode('plan');
      final result = NewSessionViewModel.resolveSelectedMode(
        runtimeId: 'custom-runtime',
        options: [first, buildMode('acceptEdits')],
        runtimeDefaultModeId: 'missing-default',
      );

      expect(identical(result, first), isTrue);
    });
  });

  group('NewSessionViewModel.resolveSelectedMachine', () {
    test('preserves the current machine when it is still connected', () {
      final current = buildMachine('machine-2');
      final result = NewSessionViewModel.resolveSelectedMachine(
        machines: [buildMachine('machine-1'), current],
        connectedMachineIds: {'machine-2'},
        current: buildMachine('machine-2'),
      );

      expect(identical(result, current), isTrue);
    });

    test(
      'does not auto-select when multiple machines are online by default',
      () {
        final result = NewSessionViewModel.resolveSelectedMachine(
          machines: [buildMachine('machine-1'), buildMachine('machine-2')],
          connectedMachineIds: {'machine-1', 'machine-2'},
        );

        expect(result, isNull);
      },
    );

    test('selects the only online machine', () {
      final only = buildMachine('machine-2');
      final result = NewSessionViewModel.resolveSelectedMachine(
        machines: [buildMachine('machine-1'), only],
        connectedMachineIds: {'machine-2'},
      );

      expect(identical(result, only), isTrue);
    });

    test('selects the first online machine when reconnect allows fallback', () {
      final first = buildMachine('machine-1');
      final result = NewSessionViewModel.resolveSelectedMachine(
        machines: [first, buildMachine('machine-2')],
        connectedMachineIds: {'machine-1', 'machine-2'},
        selectFirstOnlineWhenMultiple: true,
      );

      expect(identical(result, first), isTrue);
    });
  });

  group('NewSessionViewModel.isRecoverableTransportError', () {
    test('treats stale transport errors as recoverable', () {
      expect(
        NewSessionViewModel.isRecoverableTransportError(
          Exception('rpc timeout'),
        ),
        isTrue,
      );
      expect(
        NewSessionViewModel.isRecoverableTransportError(
          Exception('machine offline'),
        ),
        isTrue,
      );
      expect(
        NewSessionViewModel.isRecoverableTransportError(
          Exception('socket not connected'),
        ),
        isTrue,
      );
    });

    test('does not retry ordinary application errors', () {
      expect(
        NewSessionViewModel.isRecoverableTransportError(
          Exception('please select a runtime'),
        ),
        isFalse,
      );
    });
  });
}
