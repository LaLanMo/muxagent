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
  @override
  final activeSessionIds = <String>{};
  final callOrder = <String>[];
  int ensureConnectedCalls = 0;
  int startSessionCalls = 0;
  bool connected = false;
  Object? ensureConnectedError;
  Object? startSessionError;

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
    final error = ensureConnectedError;
    if (error != null) {
      throw error;
    }
    connected = true;
    relayConnectedValue.value = true;
  }

  @override
  Future<void> startSession({required PairedMachine machine}) async {
    startSessionCalls++;
    callOrder.add('startSession');
    final error = startSessionError;
    if (error != null) {
      throw error;
    }
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
  RepairStepResult reconcileResult = const RepairStepResult.success();
  RepairStepResult titleResult = const RepairStepResult.success();
  RepairStepResult approvalResult = const RepairStepResult.success();
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
  Future<RepairStepResult> reconcileSessionStatus(String machineId) async {
    callOrder.add('reconcile');
    return reconcileResult;
  }

  @override
  Future<RepairStepResult> backfillMissingTitles(
    String machineId, {
    List<String>? sessionIds,
    String? runtime,
  }) async {
    callOrder.add('backfill');
    return titleResult;
  }

  @override
  Future<RepairStepResult> fetchPendingApprovals(String machineId) async {
    callOrder.add('approvals');
    return approvalResult;
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
      final notifications = <ReconnectRecoveryResult>[];
      final sub = coordinator.recoveries.listen((result) {
        notifications.add(result);
      });

      final result = await coordinator.recoverMachine('machine-1');

      expect(result.transcript, TranscriptRecoveryState.complete);
      expect(result.metadata, MetadataRecoveryState.complete);
      expect(result.statusesOk, isTrue);
      expect(result.titlesOk, isTrue);
      expect(result.approvalsOk, isTrue);
      expect(wsRepo.callOrder, ['ensureConnected', 'startSession']);
      expect(eventRepo.callOrder, [
        'resync',
        'reconcile',
        'backfill',
        'approvals',
      ]);
      expect(notifications.single.transcript, TranscriptRecoveryState.complete);
      expect(notifications.single.metadata, MetadataRecoveryState.complete);

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
        final incomplete = await coordinator.recoverMachine('machine-1');
        expect(incomplete.transcript, TranscriptRecoveryState.fallbackNeeded);
        expect(incomplete.metadata, MetadataRecoveryState.complete);

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

        final noCursor = await coordinator.recoverMachine('machine-1');
        expect(noCursor.transcript, TranscriptRecoveryState.fallbackNeeded);
        expect(noCursor.metadata, MetadataRecoveryState.complete);
      },
    );

    test('degrades metadata without forcing transcript fallback', () async {
      eventRepo.approvalResult = RepairStepResult.failure(StateError('boom'));

      final result = await coordinator.recoverMachine('machine-1');

      expect(result.transcript, TranscriptRecoveryState.complete);
      expect(result.metadata, MetadataRecoveryState.degraded);
      expect(result.approvalsOk, isFalse);
      expect(result.statusesOk, isTrue);
      expect(result.titlesOk, isTrue);
    });

    test('reports failed transcript when transport setup fails', () async {
      wsRepo.ensureConnectedError = StateError('boom');

      final result = await coordinator.recoverMachine('machine-1');

      expect(result.transcript, TranscriptRecoveryState.failed);
      expect(result.metadata, MetadataRecoveryState.skipped);
      expect(result.sessionReady, isFalse);
      expect(result.transportError, isA<StateError>());
      expect(eventRepo.callOrder, isEmpty);
    });

    test(
      'maps thrown resync errors to fallbackNeeded with a usable session',
      () async {
        eventRepo.resyncError = StateError('boom');

        final result = await coordinator.recoverMachine('machine-1');

        expect(result.transcript, TranscriptRecoveryState.fallbackNeeded);
        expect(result.metadata, MetadataRecoveryState.skipped);
        expect(result.sessionReady, isTrue);
      },
    );

    test('still runs repair when transport is already active', () async {
      wsRepo.connected = true;
      wsRepo.relayConnectedValue.value = true;
      wsRepo.activeSessionIds.add('machine-1');

      final result = await coordinator.recoverMachine('machine-1');

      expect(wsRepo.callOrder, isEmpty);
      expect(result.transcript, TranscriptRecoveryState.complete);
      expect(result.metadata, MetadataRecoveryState.complete);
      expect(eventRepo.callOrder, [
        'resync',
        'reconcile',
        'backfill',
        'approvals',
      ]);
    });

    test('joins duplicate in-flight recovery requests', () async {
      eventRepo.resyncBlocker = Completer<void>();

      final first = coordinator.recoverMachine('machine-1');
      final second = coordinator.recoverMachine('machine-1');

      expect(identical(first, second), isTrue);
      expect(wsRepo.ensureConnectedCalls, 0);

      eventRepo.resyncBlocker!.complete();
      final results = await Future.wait([first, second]);

      expect(
        results.map((result) => result.transcript),
        everyElement(equals(TranscriptRecoveryState.complete)),
      );
      expect(wsRepo.ensureConnectedCalls, 1);
      expect(wsRepo.startSessionCalls, 1);
      expect(
        eventRepo.callOrder.where((step) => step == 'resync'),
        hasLength(1),
      );
    });
  });
}
