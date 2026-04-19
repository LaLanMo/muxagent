import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/models/auth_request.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/ui/main/main_shell_viewmodel.dart';
import 'package:muxagent/ui/main/settings_tab.dart';
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

class _FakeCryptoService extends CryptoService {
  @override
  Future<bool> hasMasterKey() async => true;
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
  group('SettingsTab', () {
    late _FakeWsSessionRepository wsRepo;
    late EventRepository eventRepo;
    late FakePairedMachineRepository machineRepo;
    late MainShellViewModel shell;
    late SettingsTabViewModel settings;

    setUp(() {
      Get.testMode = true;
      final machine = _buildMachine('machine-1');
      machineRepo = FakePairedMachineRepository([machine]);
      wsRepo = _FakeWsSessionRepository();
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
      settings = SettingsTabViewModel(
        crypto: _FakeCryptoService(),
        machineRepo: machineRepo,
        wsRepo: wsRepo,
        connectMachine: (_) async {
          throw UnimplementedError();
        },
        pairingLinkParser: const AuthRequestPairingLinkParser(),
      );
      Get.put<MainShellViewModel>(shell);
      Get.put<SettingsTabViewModel>(settings);
    });

    tearDown(() {
      Get.delete<SettingsTabViewModel>(force: true);
      Get.delete<MainShellViewModel>(force: true);
      eventRepo.dispose();
      machineRepo.dispose();
      wsRepo.dispose();
    });

    testWidgets('rebuilds machine status pills when active sessions change', (
      tester,
    ) async {
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: SettingsTab())),
      );
      await tester.pump();

      expect(find.text('online'), findsNothing);
      expect(find.text('offline'), findsOneWidget);

      wsRepo.setActiveSessionIds({'machine-1'});
      await tester.pump();

      expect(find.text('online'), findsOneWidget);
      expect(find.text('offline'), findsNothing);
      expect(find.text('Tap to reconnect'), findsNothing);
    });
  });
}
