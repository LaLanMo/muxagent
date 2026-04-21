import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/domain/session.dart';
import 'package:muxagent/ui/main/history_tab.dart';
import 'package:muxagent/ui/main/history_tab_viewmodel.dart';
import 'package:muxagent/ui/main/main_shell_viewmodel.dart';

import '../../support/fake_paired_machine_repository.dart';
import '../../support/localization_test_utils.dart';

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

class _FakeReconnectRecoveryCoordinator extends ReconnectRecoveryCoordinator {
  _FakeReconnectRecoveryCoordinator({
    required super.machines,
    required super.wsRepo,
    required super.eventRepo,
  }) : super(chatCacheRepo: SessionChatCacheRepository());

  @override
  Future<ReconnectRecoveryResult> recoverMachine(
    String machineId, {
    TranscriptRecoveryMode transcriptMode =
        TranscriptRecoveryMode.replayIfPossible,
  }) async {
    return ReconnectRecoveryResult(
      machineId: machineId,
      transcript: TranscriptRecoveryState.skipped,
      metadata: MetadataRecoveryState.skipped,
      sessionReady: false,
      statusesOk: false,
      knownSessionsOk: false,
      approvalsOk: false,
    );
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

AgentSession _buildSession({required String id, required String machineId}) {
  final now = DateTime.now();
  return AgentSession(
    id: id,
    machineId: machineId,
    title: 'History session',
    cwd: '~/project',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('HistoryTab', () {
    late _FakeWsSessionRepository wsRepo;
    late EventRepository eventRepo;
    late FakePairedMachineRepository machineRepo;
    late MainShellViewModel shell;
    late HistoryTabViewModel history;

    setUp(() {
      registerTestTranslations();
      wsRepo = _FakeWsSessionRepository(initialActiveIds: const {'machine-1'});
      eventRepo = EventRepository(wsRepo: wsRepo);
      eventRepo.sessions['session-2'] = _buildSession(
        id: 'session-2',
        machineId: 'machine-2',
      );
      machineRepo = FakePairedMachineRepository([_buildMachine('machine-1')]);
      shell = MainShellViewModel(
        machineRepo: machineRepo,
        recovery: _FakeReconnectRecoveryCoordinator(
          machines: machineRepo,
          wsRepo: wsRepo,
          eventRepo: eventRepo,
        ),
        wsRepo: wsRepo,
        eventRepo: eventRepo,
      );
      history = HistoryTabViewModel(
        eventRepo: eventRepo,
        machineRepo: machineRepo,
      );

      Get.put<MainShellViewModel>(shell);
      Get.put<HistoryTabViewModel>(history);
    });

    tearDown(() {
      Get.delete<HistoryTabViewModel>(force: true);
      Get.delete<MainShellViewModel>(force: true);
      eventRepo.dispose();
      machineRepo.dispose();
      wsRepo.dispose();
    });

    testWidgets('updates chips and session labels when a new machine appears', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedTestApp(child: const Scaffold(body: HistoryTab())),
      );
      await tester.pump();

      expect(find.text('host-machine-2'), findsNothing);
      expect(find.textContaining('~/project · machine-2'), findsOneWidget);

      await machineRepo.saveMachine(_buildMachine('machine-2'));
      await tester.pump();

      expect(find.text('host-machine-2'), findsOneWidget);
      expect(find.textContaining('~/project · host-machine-2'), findsOneWidget);
    });
  });
}
