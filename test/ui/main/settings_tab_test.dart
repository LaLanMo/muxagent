import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/paired_machine_repository.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/ui/main/main_shell_viewmodel.dart';
import 'package:muxagent/ui/main/settings_tab.dart';
import 'package:muxagent/ui/main/settings_tab_viewmodel.dart';

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

  @override
  Future<PairedMachine?> getMachine(String machineId) async {
    for (final machine in _machines) {
      if (machine.machineId == machineId) {
        return machine;
      }
    }
    return null;
  }
}

class _FakeWsSessionRepository extends WsSessionRepository {
  final relayConnectedValue = true.obs;
  final _activeSessionsController = StreamController<Set<String>>.broadcast();
  final Set<String> _activeIds;

  _FakeWsSessionRepository({Set<String>? initialActiveIds})
    : _activeIds = {...?initialActiveIds},
      super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  RxBool get relayConnected => relayConnectedValue;

  @override
  Stream<Set<String>> get activeSessions => _activeSessionsController.stream;

  @override
  Set<String> get activeSessionIds => Set.unmodifiable(_activeIds);

  @override
  bool hasSession(String machineId) => _activeIds.contains(machineId);

  void dispose() {
    _activeSessionsController.close();
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
    late MainShellViewModel shell;
    late SettingsTabViewModel settings;

    setUp(() {
      Get.testMode = true;
      final machine = _buildMachine('machine-1');
      wsRepo = _FakeWsSessionRepository();
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
      settings = SettingsTabViewModel(
        crypto: _FakeCryptoService(),
        machines: shell.machines,
        activeSessionIds: shell.activeSessionIds,
        relayConnected: shell.relayConnected,
        connectMachine: (_) async {
          throw UnimplementedError();
        },
      );
      Get.put<MainShellViewModel>(shell);
      Get.put<SettingsTabViewModel>(settings);
    });

    tearDown(() {
      Get.delete<SettingsTabViewModel>(force: true);
      Get.delete<MainShellViewModel>(force: true);
      eventRepo.dispose();
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

      shell.activeSessionIds.add('machine-1');
      await tester.pump();

      expect(find.text('online'), findsOneWidget);
      expect(find.text('offline'), findsNothing);
      expect(find.text('Tap to reconnect'), findsNothing);
    });
  });
}
