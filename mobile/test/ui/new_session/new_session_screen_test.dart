import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/local/session_database.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/runtime_preference_repository.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/stt_repository.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/api/stt_service.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/mode_option.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/domain/runtime_option.dart';
import 'package:muxagent/ui/new_session/new_session_screen.dart';
import 'package:muxagent/ui/new_session/new_session_viewmodel.dart';
import 'package:muxagent/usecases/transcribe_audio.dart';

import '../../support/fake_paired_machine_repository.dart';

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
  Set<String> _activeIds;

  _FakeWsSessionRepository()
    : _activeIds = <String>{},
      _activeSessionIdsNotifier = ValueNotifier(const <String>{}),
      super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  RxBool get relayConnected => relayConnectedValue;

  @override
  Rx<ConnState> get connectionState => connectionStateValue;

  @override
  Set<String> get activeSessionIds => Set.unmodifiable(_activeIds);

  @override
  ValueListenable<Set<String>> get activeSessionIdsListenable =>
      _activeSessionIdsNotifier;

  @override
  bool hasSession(String machineId) => _activeIds.contains(machineId);

  void setActiveSessionIds(Set<String> ids) {
    _activeIds = {...ids};
    _activeSessionIdsNotifier.value = Set.unmodifiable(_activeIds);
  }

  void dispose() {
    _activeSessionIdsNotifier.dispose();
  }
}

class _TestNewSessionViewModel extends NewSessionViewModel {
  final EventRepository eventRepo;
  final FakePairedMachineRepository machineRepo;

  _TestNewSessionViewModel._({
    required super.wsRepo,
    required this.eventRepo,
    required this.machineRepo,
  }) : super(
         machineRepo: machineRepo,
         eventRepo: eventRepo,
         runtimePrefs: RuntimePreferenceRepository(),
         chatCacheRepo: SessionChatCacheRepository(),
         transcribe: TranscribeAudioUseCase(
           repo: SttRepository(service: SttService()),
         ),
       );

  factory _TestNewSessionViewModel({required WsSessionRepository wsRepo}) {
    final eventRepo = EventRepository(wsRepo: wsRepo);
    return _TestNewSessionViewModel._(
      wsRepo: wsRepo,
      eventRepo: eventRepo,
      machineRepo: FakePairedMachineRepository(),
    );
  }

  @override
  // ignore: must_call_super
  void onInit() {}
}

PairedMachine _machine() {
  return PairedMachine(
    machineId: 'machine-1',
    relayHttpUrl: 'https://relay.test',
    machineSignPubB64: 'sign-machine-1',
    machineEncPubB64: 'enc-machine-1',
    hostname: 'by',
  );
}

RuntimeOption _runtime() {
  return const RuntimeOption(
    id: 'claude-code',
    label: 'Claude Code',
    ready: true,
    defaultModeId: 'default',
    modeOptions: [
      ModeOption(id: 'bypassPermissions', label: 'Skip Perms'),
      ModeOption(id: 'default', label: 'Default'),
      ModeOption(id: 'acceptEdits', label: 'Accept Edits'),
      ModeOption(id: 'plan', label: 'Plan'),
    ],
  );
}

void main() {
  group('NewSessionScreen', () {
    late _FakeWsSessionRepository wsRepo;
    late _TestNewSessionViewModel viewModel;

    setUp(() {
      Get.testMode = true;
      wsRepo = _FakeWsSessionRepository();
      viewModel = _TestNewSessionViewModel(wsRepo: wsRepo);
      Get.put<NewSessionViewModel>(viewModel);
    });

    tearDown(() {
      wsRepo.dispose();
      viewModel.eventRepo.dispose();
      viewModel.machineRepo.dispose();
      Get.reset();
    });

    testWidgets('renders the v2 labels, mode cards, and worktree row', (
      tester,
    ) async {
      final machine = _machine();
      final runtime = _runtime();
      viewModel.machineRepo.setMachines([machine]);
      viewModel.selectedMachine.value = machine;
      viewModel.availableRuntimes.value = [runtime];
      viewModel.selectedRuntime.value = runtime;
      viewModel.availableModes.value = runtime.modeOptions;
      viewModel.selectedMode.value = runtime.modeOptions[1];
      viewModel.useWorktree.value = true;

      await tester.pumpWidget(const GetMaterialApp(home: NewSessionScreen()));
      await tester.pump();

      expect(find.text('RUNTIME'), findsOneWidget);
      expect(find.text('MACHINE'), findsOneWidget);
      expect(
        find.text('Already started a session in your machine?'),
        findsOneWidget,
      );
      expect(find.text('WORKING DIRECTORY'), findsOneWidget);
      expect(find.text('INITIAL PROMPT'), findsOneWidget);
      expect(find.text('MODE'), findsOneWidget);
      expect(find.text('GIT WORKTREE'), findsOneWidget);
      expect(find.text('Skip Perms'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Accept Edits'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Use Worktree'), findsOneWidget);
      expect(find.text('Start Session'), findsOneWidget);
    });

    testWidgets('shows a readable fallback when no mode options exist', (
      tester,
    ) async {
      final machine = _machine();
      final runtime = _runtime();
      viewModel.machineRepo.setMachines([machine]);
      viewModel.selectedMachine.value = machine;
      viewModel.availableRuntimes.value = [runtime];
      viewModel.selectedRuntime.value = runtime;
      viewModel.availableModes.clear();

      await tester.pumpWidget(const GetMaterialApp(home: NewSessionScreen()));
      await tester.pump();

      expect(find.text('Use runtime default mode'), findsOneWidget);
    });

    testWidgets('opens the working directory dropdown without widget errors', (
      tester,
    ) async {
      final machine = _machine();
      final runtime = _runtime();
      viewModel.machineRepo.setMachines([machine]);
      viewModel.selectedMachine.value = machine;
      viewModel.availableRuntimes.value = [runtime];
      viewModel.selectedRuntime.value = runtime;
      viewModel.availableModes.value = runtime.modeOptions;
      viewModel.selectedMode.value = runtime.modeOptions[1];
      viewModel.recentCwds.value = [
        RecentCwd(path: '~/project-a', lastUsed: DateTime(2026, 4, 13, 12)),
      ];
      viewModel.filteredCwds.value = List.of(viewModel.recentCwds);

      await tester.pumpWidget(const GetMaterialApp(home: NewSessionScreen()));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Working directory'));
      await tester.pump();

      expect(find.text('RECENT'), findsOneWidget);
      expect(find.text('~/project-a'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('formats home directory paths in the dropdown for display', (
      tester,
    ) async {
      final machine = _machine();
      final runtime = _runtime();
      viewModel.machineRepo.setMachines([machine]);
      viewModel.selectedMachine.value = machine;
      viewModel.availableRuntimes.value = [runtime];
      viewModel.selectedRuntime.value = runtime;
      viewModel.availableModes.value = runtime.modeOptions;
      viewModel.selectedMode.value = runtime.modeOptions[1];
      viewModel.recentCwds.value = [
        RecentCwd(
          path: '/Users/by/Projects/cmdr',
          lastUsed: DateTime(2026, 4, 13, 12),
        ),
      ];
      viewModel.filteredCwds.value = List.of(viewModel.recentCwds);

      await tester.pumpWidget(const GetMaterialApp(home: NewSessionScreen()));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Working directory'));
      await tester.pump();

      expect(find.text('~/Projects/cmdr'), findsOneWidget);
      expect(find.text('/Users/by/Projects/cmdr'), findsNothing);
    });

    testWidgets(
      'opens the machine dropdown immediately when the selector is tapped',
      (tester) async {
        final machine = _machine();
        viewModel.machineRepo.setMachines([machine]);
        wsRepo.setActiveSessionIds({machine.machineId});

        await tester.pumpWidget(const GetMaterialApp(home: NewSessionScreen()));
        await tester.pump();

        expect(find.text('Select a machine'), findsOneWidget);
        expect(find.text('by'), findsNothing);

        await tester.tap(find.text('Select a machine'));
        await tester.pump();

        expect(find.text('by'), findsOneWidget);
      },
    );

    testWidgets('renders offline machines in a disabled style', (tester) async {
      final machine = _machine();
      viewModel.machineRepo.setMachines([machine]);

      await tester.pumpWidget(const GetMaterialApp(home: NewSessionScreen()));
      await tester.pump();

      await tester.tap(find.text('Select a machine'));
      await tester.pump();

      expect(
        find.ancestor(
          of: find.text('by'),
          matching: find.byWidgetPredicate(
            (widget) => widget is Opacity && widget.opacity == 0.55,
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
