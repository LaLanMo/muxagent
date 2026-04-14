import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/theme.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/paired_machine_repository.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/ui/common/relay_status_pill.dart';
import 'package:muxagent/ui/main/main_shell_viewmodel.dart';

class _NoopRelayWsClient extends RelayWsClient {
  _NoopRelayWsClient()
    : super(
        crypto: CryptoService(),
        tokens: TokenService(crypto: CryptoService()),
        sessions: SessionManager(),
      );
}

class _FakePairedMachineRepository extends PairedMachineRepository {
  final List<PairedMachine> _machines;

  _FakePairedMachineRepository(this._machines);

  @override
  Future<List<PairedMachine>> listMachines() async => _machines;
}

class _FakeWsSessionRepository extends WsSessionRepository {
  final relayConnectedValue = true.obs;
  final connectionStateValue = ConnState.connected.obs;
  final ValueNotifier<Set<String>> _activeSessionIdsNotifier;
  Set<String> _activeIds;

  _FakeWsSessionRepository({Set<String>? initialActiveIds})
    : _activeIds = {...?initialActiveIds},
      _activeSessionIdsNotifier = ValueNotifier(
        Set.unmodifiable({...?initialActiveIds}),
      ),
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

  void dispose() {
    _activeSessionIdsNotifier.dispose();
  }
}

PairedMachine _buildMachine(String id) {
  return PairedMachine(
    machineId: id,
    relayHttpUrl: 'https://relay.test',
    machineSignPubB64: 'sign-$id',
    machineEncPubB64: 'enc-$id',
    hostname: 'host-$id',
  );
}

void main() {
  group('RelayStatusPill', () {
    late _FakeWsSessionRepository wsRepo;
    late EventRepository eventRepo;
    late MainShellViewModel shell;

    setUp(() {
      Get.testMode = true;
      final machine = _buildMachine('machine-1');
      wsRepo = _FakeWsSessionRepository(initialActiveIds: {'machine-1'});
      eventRepo = EventRepository(wsRepo: wsRepo);
      shell = MainShellViewModel(
        machineRepo: _FakePairedMachineRepository([machine]),
        recovery: ReconnectRecoveryCoordinator(
          machines: _FakePairedMachineRepository([machine]),
          wsRepo: wsRepo,
          eventRepo: eventRepo,
          chatCacheRepo: SessionChatCacheRepository(),
        ),
        wsRepo: wsRepo,
        eventRepo: eventRepo,
      );
      shell.machines.value = [machine];
      Get.put<MainShellViewModel>(shell);
    });

    tearDown(() {
      Get.delete<MainShellViewModel>(force: true);
      eventRepo.dispose();
      wsRepo.dispose();
    });

    Future<void> pumpPill(WidgetTester tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(body: Center(child: RelayStatusPill())),
        ),
      );
      await tester.pump();
    }

    testWidgets('stays hidden while relay is connected', (tester) async {
      wsRepo.relayConnectedValue.value = true;
      wsRepo.connectionStateValue.value = ConnState.connected;

      await pumpPill(tester);

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('reconnecting'), findsNothing);
      expect(find.text('offline'), findsNothing);
    });

    testWidgets('renders the reconnecting chip with a subtle warning style', (
      tester,
    ) async {
      wsRepo.relayConnectedValue.value = false;
      wsRepo.connectionStateValue.value = ConnState.reconnecting;

      await pumpPill(tester);

      final chipFinder = find.byKey(
        const ValueKey('relay-status-pill-reconnecting'),
      );
      final chip = tester.widget<Container>(
        find.descendant(of: chipFinder, matching: find.byType(Container)).first,
      );
      final decoration = chip.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      expect(find.text('reconnecting'), findsOneWidget);
      expect(decoration.color, const Color(0xFFFFFAEF));
      expect(border.top.color, const Color(0xFFE7C98C));
      expect(
        (tester.widget<Text>(find.text('reconnecting')).style?.color),
        AppTheme.warning,
      );
    });

    testWidgets('renders the disconnected chip with a stronger failure style', (
      tester,
    ) async {
      wsRepo.relayConnectedValue.value = false;
      wsRepo.connectionStateValue.value = ConnState.disconnected;

      await pumpPill(tester);

      final chipFinder = find.byKey(
        const ValueKey('relay-status-pill-disconnected'),
      );
      final chip = tester.widget<Container>(
        find.descendant(of: chipFinder, matching: find.byType(Container)).first,
      );
      final decoration = chip.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      expect(find.text('offline'), findsOneWidget);
      expect(decoration.color, AppTheme.disconnectedBg);
      expect(border.top.color, const Color(0xFFE0B2AA));
      expect(
        (tester.widget<Text>(find.text('offline')).style?.color),
        AppTheme.statusDisconnected,
      );
    });
  });
}
