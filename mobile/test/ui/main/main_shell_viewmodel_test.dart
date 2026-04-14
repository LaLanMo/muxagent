import 'package:flutter/foundation.dart';
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

  _FakeWsSessionRepository({required Set<String> initialActiveIds})
    : _activeIds = {...initialActiveIds},
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

  void emitActiveSessions(Set<String> ids) {
    _activeIds = {...ids};
    _activeSessionIdsNotifier.value = Set.unmodifiable(_activeIds);
  }

  void dispose() {
    _activeSessionIdsNotifier.dispose();
  }
}

class _FakeReconnectRecoveryCoordinator extends ReconnectRecoveryCoordinator {
  final Future<ReconnectRecoveryResult> Function(
    String machineId, {
    TranscriptRecoveryMode transcriptMode,
  })
  _handler;

  _FakeReconnectRecoveryCoordinator({
    required Future<ReconnectRecoveryResult> Function(
      String machineId, {
      TranscriptRecoveryMode transcriptMode,
    })
    handler,
  }) : _handler = handler,
       super(
         machines: FakePairedMachineRepository(const []),
         wsRepo: _FakeWsSessionRepository(initialActiveIds: const {}),
         eventRepo: EventRepository(
           wsRepo: _FakeWsSessionRepository(initialActiveIds: const {}),
         ),
         chatCacheRepo: SessionChatCacheRepository(),
       );

  @override
  Future<ReconnectRecoveryResult> recoverMachine(
    String machineId, {
    TranscriptRecoveryMode transcriptMode =
        TranscriptRecoveryMode.replayIfPossible,
  }) {
    return _handler(machineId, transcriptMode: transcriptMode);
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
  group('MainShellViewModel session presence', () {
    late _FakeWsSessionRepository wsRepo;
    late EventRepository eventRepo;
    late FakePairedMachineRepository machineRepo;
    late MainShellViewModel viewModel;

    setUp(() {
      Get.testMode = true;
      wsRepo = _FakeWsSessionRepository(initialActiveIds: {'machine-1'});
      eventRepo = EventRepository(wsRepo: wsRepo);
      machineRepo = FakePairedMachineRepository([_buildMachine('machine-1')]);
      viewModel = MainShellViewModel(
        machineRepo: machineRepo,
        recovery: ReconnectRecoveryCoordinator(
          machines: machineRepo,
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
      machineRepo.dispose();
      wsRepo.dispose();
    });

    testWidgets(
      'reads initial repository session presence without a shell mirror',
      (tester) async {
        viewModel.onInit();
        await tester.pump();

        expect(viewModel.isMachineConnected('machine-1'), isTrue);
      },
    );

    testWidgets(
      'reflects updated repository session presence after listable changes',
      (tester) async {
        viewModel.onInit();
        await tester.pump();

        wsRepo.emitActiveSessions({'machine-2'});
        await tester.pump();

        expect(viewModel.isMachineConnected('machine-1'), isFalse);
        expect(viewModel.isMachineConnected('machine-2'), isTrue);
      },
    );

    testWidgets(
      'reports a machine connected after successful recovery updates repository presence',
      (tester) async {
        final machine = _buildMachine('machine-1');
        wsRepo.dispose();
        eventRepo.dispose();
        machineRepo.dispose();
        wsRepo = _FakeWsSessionRepository(initialActiveIds: const {});
        eventRepo = EventRepository(wsRepo: wsRepo);
        machineRepo = FakePairedMachineRepository([machine]);
        final recovery = _FakeReconnectRecoveryCoordinator(
          handler:
              (
                machineId, {
                transcriptMode = TranscriptRecoveryMode.replayIfPossible,
              }) async {
                wsRepo.emitActiveSessions({machineId});
                return ReconnectRecoveryResult(
                  machineId: machineId,
                  transcript: TranscriptRecoveryState.skipped,
                  metadata: MetadataRecoveryState.complete,
                  sessionReady: true,
                  statusesOk: true,
                  titlesOk: true,
                  approvalsOk: true,
                );
              },
        );
        viewModel = MainShellViewModel(
          machineRepo: machineRepo,
          recovery: recovery,
          wsRepo: wsRepo,
          eventRepo: eventRepo,
        );

        expect(viewModel.isMachineConnected(machine.machineId), isFalse);

        final result = await viewModel.connectMachine(machine);
        await tester.pump();

        expect(result.sessionReady, isTrue);
        expect(viewModel.isMachineConnected(machine.machineId), isTrue);
      },
    );
  });
}
