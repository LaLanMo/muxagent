import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:muxagent/data/local/session_database.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/runtime_preference_repository.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/stt_repository.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/api/stt_service.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/models/acp_session_models.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/mode_option.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/domain/runtime_option.dart';
import 'package:muxagent/ui/new_session/new_session_viewmodel.dart';
import 'package:muxagent/usecases/transcribe_audio.dart';

import '../../support/fake_paired_machine_repository.dart';
import '../../support/localization_test_utils.dart';

const _copilotModeAgentId =
    'https://agentclientprotocol.com/protocol/session-modes#agent';
const _copilotModePlanId =
    'https://agentclientprotocol.com/protocol/session-modes#plan';
const _copilotModeAutopilotId =
    'https://agentclientprotocol.com/protocol/session-modes#autopilot';

class _NoopRelayWsClient extends RelayWsClient {
  _NoopRelayWsClient()
    : super(
        crypto: CryptoService(),
        tokens: TokenService(crypto: CryptoService()),
        sessions: SessionManager(),
      );
}

class _FakeWsSessionRepository extends WsSessionRepository {
  final relayConnectedValue = true.obs;
  final connectionStateValue = ConnState.connected.obs;
  final ValueNotifier<Set<String>> _activeSessionIdsNotifier;
  final Set<String> _activeIds;
  final AppRuntimeListResponseDto runtimeListResponse;
  final List<String> listedRuntimeMachineIds = [];

  _FakeWsSessionRepository({
    required Set<String> initialActiveIds,
    required this.runtimeListResponse,
  }) : _activeIds = {...initialActiveIds},
       _activeSessionIdsNotifier = ValueNotifier(
         Set.unmodifiable({...initialActiveIds}),
       ),
       super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  Set<String> get activeSessionIds => Set.unmodifiable(_activeIds);

  @override
  ValueListenable<Set<String>> get activeSessionIdsListenable =>
      _activeSessionIdsNotifier;

  @override
  bool hasSession(String machineId) => _activeIds.contains(machineId);

  @override
  RxBool get relayConnected => relayConnectedValue;

  @override
  Rx<ConnState> get connectionState => connectionStateValue;

  @override
  Future<void> ensureConnected({required String relayHttpUrl}) async {}

  @override
  Future<void> startSession({required PairedMachine machine}) async {
    _activeIds.add(machine.machineId);
    _activeSessionIdsNotifier.value = Set.unmodifiable(_activeIds);
  }

  @override
  Future<AppRuntimeListResponseDto> listRuntimes({
    required String machineId,
  }) async {
    listedRuntimeMachineIds.add(machineId);
    return runtimeListResponse;
  }

  void dispose() {
    _activeSessionIdsNotifier.dispose();
  }
}

class _FakeTranscribeAudioUseCase extends TranscribeAudioUseCase {
  _FakeTranscribeAudioUseCase()
    : super(repo: SttRepository(service: SttService()));

  @override
  Future<bool> hasConfig() async => false;
}

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
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('NewSessionViewModel lifecycle', () {
    late String dbPath;
    late _FakeWsSessionRepository wsRepo;
    late FakePairedMachineRepository machineRepo;
    late EventRepository eventRepo;
    late NewSessionViewModel viewModel;

    setUp(() async {
      registerTestTranslations();
      SharedPreferences.setMockInitialValues({});
      dbPath = p.join(
        Directory.systemTemp.path,
        'muxagent-new-session-vm-test.db',
      );
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await SessionDatabase.resetForTest(databasePathOverride: dbPath);

      wsRepo = _FakeWsSessionRepository(
        initialActiveIds: const {'machine-1'},
        runtimeListResponse: const AppRuntimeListResponseDto(
          runtimes: [
            AppRuntimeInfoDto(id: 'codex', label: 'Codex', ready: true),
          ],
        ),
      );
      machineRepo = FakePairedMachineRepository([buildMachine('machine-1')]);
      eventRepo = EventRepository(wsRepo: wsRepo);
      viewModel = NewSessionViewModel(
        machineRepo: machineRepo,
        wsRepo: wsRepo,
        eventRepo: eventRepo,
        runtimePrefs: RuntimePreferenceRepository(),
        chatCacheRepo: SessionChatCacheRepository(),
        transcribe: _FakeTranscribeAudioUseCase(),
      );
    });

    tearDown(() async {
      viewModel.onClose();
      eventRepo.dispose();
      machineRepo.dispose();
      wsRepo.dispose();
      await SessionDatabase.resetForTest();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      Get.reset();
    });

    testWidgets(
      'loads runtimes when the initial machine selection happens during onInit',
      (tester) async {
        viewModel.onInit();
        await tester.pump();
        await tester.pump();

        expect(viewModel.selectedMachine.value?.machineId, 'machine-1');
        expect(wsRepo.listedRuntimeMachineIds, ['machine-1']);
        expect(viewModel.availableRuntimes.map((runtime) => runtime.id), [
          'codex',
        ]);
        expect(viewModel.selectedRuntime.value?.id, 'codex');
      },
    );
  });

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

    test('falls back to Build for OpenCode when there is no memory', () {
      final build = buildMode('build');
      final result = NewSessionViewModel.resolveSelectedMode(
        runtimeId: 'opencode',
        options: [buildMode('plan'), build],
      );

      expect(identical(result, build), isTrue);
    });

    test('falls back to Default for Gemini when there is no memory', () {
      final defaultMode = buildMode('default');
      final result = NewSessionViewModel.resolveSelectedMode(
        runtimeId: 'gemini',
        options: [buildMode('yolo'), buildMode('plan'), defaultMode],
      );

      expect(identical(result, defaultMode), isTrue);
    });

    test('falls back to Auto for Goose when there is no memory', () {
      final auto = buildMode('auto');
      final result = NewSessionViewModel.resolveSelectedMode(
        runtimeId: 'goose',
        options: [buildMode('chat'), buildMode('approve'), auto],
      );

      expect(identical(result, auto), isTrue);
    });

    test('falls back to Agent for Copilot when there is no memory', () {
      final agent = buildMode(_copilotModeAgentId);
      final result = NewSessionViewModel.resolveSelectedMode(
        runtimeId: 'copilot',
        options: [
          buildMode(_copilotModeAutopilotId),
          buildMode(_copilotModePlanId),
          agent,
        ],
      );

      expect(identical(result, agent), isTrue);
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
      expect(
        NewSessionViewModel.isRecoverableTransportError(
          Exception('transport stopped: process exited'),
        ),
        isTrue,
      );
      expect(
        NewSessionViewModel.isRecoverableTransportError(
          Exception('write |1: broken pipe'),
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
