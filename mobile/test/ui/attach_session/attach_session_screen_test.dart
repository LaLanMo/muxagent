import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/runtime_preference_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/domain/runtime_option.dart';
import 'package:muxagent/ui/attach_session/attach_session_screen.dart';
import 'package:muxagent/ui/attach_session/attach_session_viewmodel.dart';

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

class _TestAttachSessionViewModel extends AttachSessionViewModel {
  final EventRepository eventRepo;
  final FakePairedMachineRepository machineRepo;

  _TestAttachSessionViewModel._({
    required super.wsRepo,
    required this.eventRepo,
    required this.machineRepo,
  }) : super(
         machineRepo: machineRepo,
         eventRepo: eventRepo,
         runtimePrefs: RuntimePreferenceRepository(),
       );

  factory _TestAttachSessionViewModel({required WsSessionRepository wsRepo}) {
    final eventRepo = EventRepository(wsRepo: wsRepo);
    return _TestAttachSessionViewModel._(
      wsRepo: wsRepo,
      eventRepo: eventRepo,
      machineRepo: FakePairedMachineRepository(),
    );
  }
}

PairedMachine _machine() {
  return PairedMachine(
    machineId: 'machine-1',
    relayHttpUrl: 'https://relay.test',
    machineSignPubB64: 'sign-machine-1',
    machineEncPubB64: 'enc-machine-1',
    hostname: 'MacBook Pro',
  );
}

RuntimeOption _runtime() {
  return const RuntimeOption(
    id: 'claude-code',
    label: 'Claude Code',
    ready: true,
    defaultModeId: 'default',
    modeOptions: [],
  );
}

void main() {
  group('AttachSessionScreen', () {
    late _FakeWsSessionRepository wsRepo;
    late _TestAttachSessionViewModel viewModel;

    setUp(() {
      Get.testMode = true;
      wsRepo = _FakeWsSessionRepository();
      viewModel = _TestAttachSessionViewModel(wsRepo: wsRepo);
      Get.put<AttachSessionViewModel>(viewModel);
    });

    tearDown(() {
      wsRepo.dispose();
      viewModel.eventRepo.dispose();
      viewModel.machineRepo.dispose();
      Get.reset();
    });

    testWidgets('renders the attach form fields and button', (tester) async {
      final machine = _machine();
      final runtime = _runtime();
      viewModel.machineRepo.setMachines([machine]);
      viewModel.selectedMachine.value = machine;
      viewModel.availableRuntimes.value = [runtime];
      viewModel.selectedRuntime.value = runtime;
      viewModel.sessionIdController.text = 'session-123';
      viewModel.sessionIdText.value = 'session-123';

      await tester.pumpWidget(
        const GetMaterialApp(home: AttachSessionScreen()),
      );
      await tester.pump();

      expect(
        find.text('Continue a session you started in your machine'),
        findsOneWidget,
      );
      expect(find.text('SESSION ID'), findsOneWidget);
      expect(find.text('RUNTIME'), findsOneWidget);
      expect(find.text('MACHINE'), findsOneWidget);
      expect(find.text('Attach Session'), findsWidgets);
    });

    testWidgets(
      'opens the machine dropdown immediately when the selector is tapped',
      (tester) async {
        final machine = _machine();
        viewModel.machineRepo.setMachines([machine]);

        await tester.pumpWidget(
          const GetMaterialApp(home: AttachSessionScreen()),
        );
        await tester.pump();

        expect(find.text('Select a machine'), findsOneWidget);
        expect(find.text('MacBook Pro'), findsNothing);

        await tester.tap(find.text('Select a machine'));
        await tester.pump();

        expect(find.text('MacBook Pro'), findsOneWidget);
      },
    );

    testWidgets('renders offline machines in a disabled style', (tester) async {
      final machine = _machine();
      viewModel.machineRepo.setMachines([machine]);

      await tester.pumpWidget(
        const GetMaterialApp(home: AttachSessionScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Select a machine'));
      await tester.pump();

      expect(
        find.ancestor(
          of: find.text('MacBook Pro'),
          matching: find.byWidgetPredicate(
            (widget) => widget is Opacity && widget.opacity == 0.55,
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
