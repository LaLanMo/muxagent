import 'dart:async';

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
  final _activeSessionsController = StreamController<Set<String>>.broadcast();
  final relayConnectedValue = true.obs;
  Set<String> _activeIds;

  _FakeWsSessionRepository({required Set<String> initialActiveIds})
    : _activeIds = {...initialActiveIds},
      super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  Stream<Set<String>> get activeSessions => _activeSessionsController.stream;

  @override
  Set<String> get activeSessionIds => Set.unmodifiable(_activeIds);

  @override
  bool hasSession(String machineId) => _activeIds.contains(machineId);

  @override
  RxBool get relayConnected => relayConnectedValue;

  void emitActiveSessions(Set<String> ids) {
    _activeIds = {...ids};
    _activeSessionsController.add(Set.unmodifiable(_activeIds));
  }

  void dispose() {
    _activeSessionsController.close();
  }
}

PairedMachine _buildMachine(String machineId) {
  return PairedMachine(
    machineId: machineId,
    relayHttpUrl: 'https://relay.test',
    machineSignPubB64: 'sign-$machineId',
    machineEncPubB64: 'enc-$machineId',
    hostname: 'host-$machineId',
  );
}

void main() {
  group('MainShellViewModel active session mirror', () {
    late _FakeWsSessionRepository wsRepo;
    late EventRepository eventRepo;
    late MainShellViewModel viewModel;

    setUp(() {
      Get.testMode = true;
      wsRepo = _FakeWsSessionRepository(initialActiveIds: {'machine-1'});
      eventRepo = EventRepository(wsRepo: wsRepo);
      viewModel = MainShellViewModel(
        machineRepo: _FakePairedMachineRepository([_buildMachine('machine-1')]),
        recovery: ReconnectRecoveryCoordinator(
          machines: _FakePairedMachineRepository([_buildMachine('machine-1')]),
          wsRepo: wsRepo,
          eventRepo: eventRepo,
          chatCacheRepo: SessionChatCacheRepository(),
        ),
        wsRepo: wsRepo,
        eventRepo: eventRepo,
      );
    });

    tearDown(() {
      viewModel.onClose();
      eventRepo.dispose();
      wsRepo.dispose();
    });

    testWidgets(
      'copies the repository active sessions into the shell on init',
      (tester) async {
        viewModel.onInit();
        await tester.pump();

        expect(viewModel.activeSessionIds, contains('machine-1'));
      },
    );

    testWidgets(
      'replaces mirrored session ids when the repository stream emits',
      (tester) async {
        viewModel.onInit();
        await tester.pump();

        wsRepo.emitActiveSessions({'machine-2'});
        await tester.pump();

        expect(viewModel.activeSessionIds, isNot(contains('machine-1')));
        expect(viewModel.activeSessionIds, contains('machine-2'));
      },
    );
  });
}
