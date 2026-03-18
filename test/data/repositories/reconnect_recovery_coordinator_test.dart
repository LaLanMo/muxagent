import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/paired_machine_repository.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/paired_machine.dart';

class _NoopRelayWsClient extends RelayWsClient {
  _NoopRelayWsClient()
    : super(
        crypto: CryptoService(),
        tokens: TokenService(crypto: CryptoService()),
        sessions: SessionManager(),
      );
}

class _FakePairedMachineRepository extends PairedMachineRepository {
  final Map<String, PairedMachine> machines;

  _FakePairedMachineRepository(this.machines);

  @override
  Future<PairedMachine?> getMachine(String machineId) async {
    return machines[machineId];
  }
}

class _FakeWsSessionRepository extends WsSessionRepository {
  final relayConnectedValue = false.obs;
  final activeSessionIds = <String>{};
  final callOrder = <String>[];
  int ensureConnectedCalls = 0;
  int startSessionCalls = 0;
  bool connected = false;

  _FakeWsSessionRepository()
    : super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  RxBool get relayConnected => relayConnectedValue;

  @override
  bool get isConnected => connected;

  @override
  bool hasSession(String machineId) => activeSessionIds.contains(machineId);

  @override
  Future<void> ensureConnected({required String relayHttpUrl}) async {
    ensureConnectedCalls++;
    callOrder.add('ensureConnected');
    connected = true;
    relayConnectedValue.value = true;
  }

  @override
  Future<void> startSession({required PairedMachine machine}) async {
    startSessionCalls++;
    callOrder.add('startSession');
    activeSessionIds.add(machine.machineId);
  }
}

class _FakeEventRepository extends EventRepository {
  final callOrder = <String>[];
  ResyncResult nextResult = const ResyncResult(
    outcome: ResyncOutcome.complete,
    lastSeqUsed: 4,
    highestSeqApplied: 7,
  );
  Completer<void>? resyncBlocker;
  Object? resyncError;

  _FakeEventRepository({required super.wsRepo});

  @override
  Future<ResyncResult> resync(String machineId) async {
    callOrder.add('resync');
    final blocker = resyncBlocker;
    if (blocker != null) {
      await blocker.future;
    }
    final error = resyncError;
    if (error != null) {
      throw error;
    }
    return nextResult;
  }

  @override
  Future<void> reconcileSessionStatus(String machineId) async {
    callOrder.add('reconcile');
  }

  @override
  Future<void> backfillMissingTitles(
    String machineId, {
    List<String>? sessionIds,
    String? runtime,
  }) async {
    callOrder.add('backfill');
  }

  @override
  Future<void> fetchPendingApprovals(String machineId) async {
    callOrder.add('approvals');
  }
}

void main() {
  group('ReconnectRecoveryCoordinator', () {
    late _FakeWsSessionRepository wsRepo;
    late _FakeEventRepository eventRepo;
    late ReconnectRecoveryCoordinator coordinator;

    setUp(() {
      wsRepo = _FakeWsSessionRepository();
      eventRepo = _FakeEventRepository(wsRepo: wsRepo);
      coordinator = ReconnectRecoveryCoordinator(
        machines: _FakePairedMachineRepository({
          'machine-1': PairedMachine(
            machineId: 'machine-1',
            relayHttpUrl: 'https://relay.example',
            machineSignPubB64: 'sign',
            machineEncPubB64: 'enc',
          ),
        }),
        wsRepo: wsRepo,
        eventRepo: eventRepo,
      );
    });

    test('returns complete and preserves recovery order', () async {
      final notifications = <ReconnectRecoveryOutcome>[];
      final sub = coordinator.recoveries.listen((notification) {
        notifications.add(notification.outcome);
      });

      final outcome = await coordinator.recoverMachine('machine-1');

      expect(outcome, ReconnectRecoveryOutcome.complete);
      expect(wsRepo.callOrder, ['ensureConnected', 'startSession']);
      expect(eventRepo.callOrder, [
        'resync',
        'reconcile',
        'backfill',
        'approvals',
      ]);
      expect(notifications, [ReconnectRecoveryOutcome.complete]);

      await sub.cancel();
    });

    test(
      'maps incomplete and noCursor results to fallback-needed outcomes',
      () async {
        eventRepo.nextResult = const ResyncResult(
          outcome: ResyncOutcome.incomplete,
          lastSeqUsed: 4,
          highestSeqApplied: 5,
        );
        expect(
          await coordinator.recoverMachine('machine-1'),
          ReconnectRecoveryOutcome.incomplete,
        );

        wsRepo.connected = false;
        wsRepo.relayConnectedValue.value = false;
        wsRepo.activeSessionIds.clear();
        eventRepo.callOrder.clear();
        wsRepo.callOrder.clear();
        eventRepo.nextResult = const ResyncResult(
          outcome: ResyncOutcome.noCursor,
          lastSeqUsed: 0,
          highestSeqApplied: 0,
        );

        expect(
          await coordinator.recoverMachine('machine-1'),
          ReconnectRecoveryOutcome.noCursor,
        );
      },
    );

    test('maps thrown resync errors to failed', () async {
      eventRepo.resyncError = StateError('boom');

      final outcome = await coordinator.recoverMachine('machine-1');

      expect(outcome, ReconnectRecoveryOutcome.failed);
    });

    test('joins duplicate in-flight recovery requests', () async {
      eventRepo.resyncBlocker = Completer<void>();

      final first = coordinator.recoverMachine('machine-1');
      final second = coordinator.recoverMachine('machine-1');

      expect(identical(first, second), isTrue);
      expect(wsRepo.ensureConnectedCalls, 0);

      eventRepo.resyncBlocker!.complete();
      final results = await Future.wait([first, second]);

      expect(results, [
        ReconnectRecoveryOutcome.complete,
        ReconnectRecoveryOutcome.complete,
      ]);
      expect(wsRepo.ensureConnectedCalls, 1);
      expect(wsRepo.startSessionCalls, 1);
      expect(
        eventRepo.callOrder.where((step) => step == 'resync'),
        hasLength(1),
      );
    });
  });
}
