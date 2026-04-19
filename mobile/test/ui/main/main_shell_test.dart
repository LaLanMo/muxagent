import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/paired_machine_repository.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/models/auth_request.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/ui/common/pill_tab_bar.dart';
import 'package:muxagent/ui/main/active_tab_viewmodel.dart';
import 'package:muxagent/ui/main/history_tab_viewmodel.dart';
import 'package:muxagent/ui/main/main_shell.dart';
import 'package:muxagent/ui/main/main_shell_viewmodel.dart';
import 'package:muxagent/ui/main/settings_tab_viewmodel.dart';

import '../../support/fake_pairing_deep_link_coordinator.dart';
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
  final ValueNotifier<Set<String>> _activeSessionIdsNotifier;
  final Set<String> _activeIds;

  _FakeWsSessionRepository({Set<String>? initialActiveIds})
    : _activeIds = {...?initialActiveIds},
      _activeSessionIdsNotifier = ValueNotifier(
        Set.unmodifiable({...?initialActiveIds}),
      ),
      super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  RxBool get relayConnected => relayConnectedValue;

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
  group('MainShell', () {
    late _FakeWsSessionRepository wsRepo;
    late EventRepository eventRepo;
    late FakePairedMachineRepository machineRepo;
    late MainShellViewModel shell;

    setUp(() {
      Get.testMode = true;
      final machine = _buildMachine('machine-1');
      machineRepo = FakePairedMachineRepository([machine]);
      wsRepo = _FakeWsSessionRepository(initialActiveIds: {'machine-1'});
      eventRepo = EventRepository(wsRepo: wsRepo);
      shell = MainShellViewModel(
        machineRepo: machineRepo,
        recovery: ReconnectRecoveryCoordinator(
          machines: machineRepo,
          wsRepo: wsRepo,
          eventRepo: eventRepo,
          chatCacheRepo: SessionChatCacheRepository(),
        ),
        wsRepo: wsRepo,
        eventRepo: eventRepo,
        pairingDeepLinkCoordinator: FakePairingDeepLinkCoordinator(
          blockingWelcomeRedirect: false,
        ),
      );

      Get.put<WsSessionRepository>(wsRepo);
      Get.put<PairedMachineRepository>(machineRepo);
      Get.put<MainShellViewModel>(shell);
      Get.put<ActiveTabViewModel>(ActiveTabViewModel(eventRepo: eventRepo));
      Get.put<HistoryTabViewModel>(
        HistoryTabViewModel(eventRepo: eventRepo, machineRepo: machineRepo),
      );
      Get.put<SettingsTabViewModel>(
        SettingsTabViewModel(
          crypto: CryptoService(),
          machineRepo: machineRepo,
          wsRepo: wsRepo,
          connectMachine: (_) async =>
              throw UnimplementedError('not needed in this test'),
          pairingLinkParser: const AuthRequestPairingLinkParser(),
        ),
      );
    });

    tearDown(() {
      Get.delete<SettingsTabViewModel>(force: true);
      Get.delete<HistoryTabViewModel>(force: true);
      Get.delete<ActiveTabViewModel>(force: true);
      Get.delete<MainShellViewModel>(force: true);
      Get.delete<PairedMachineRepository>(force: true);
      Get.delete<WsSessionRepository>(force: true);
      eventRepo.dispose();
      machineRepo.dispose();
      wsRepo.dispose();
    });

    testWidgets(
      'renders the tab bar as an overlay instead of a scaffold footer',
      (tester) async {
        await tester.pumpWidget(const GetMaterialApp(home: MainShell()));
        await tester.pump();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.bottomNavigationBar, isNull);

        expect(find.byType(PillTabBar), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byType(PillTabBar),
            matching: find.byType(Align),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
