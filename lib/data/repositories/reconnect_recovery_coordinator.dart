import 'dart:async';

import 'package:flutter/foundation.dart';

import 'event_repository.dart';
import 'paired_machine_repository.dart';
import 'ws_session_repository.dart';

enum ReconnectRecoveryOutcome { complete, incomplete, failed, noCursor }

class ReconnectRecoveryNotification {
  final String machineId;
  final ReconnectRecoveryOutcome outcome;

  const ReconnectRecoveryNotification({
    required this.machineId,
    required this.outcome,
  });
}

class ReconnectRecoveryCoordinator {
  final PairedMachineRepository _machines;
  final WsSessionRepository _wsRepo;
  final EventRepository _eventRepo;
  final _notifications =
      StreamController<ReconnectRecoveryNotification>.broadcast();
  // Join repeated recovery requests for the same machine onto one future.
  final Map<String, Future<ReconnectRecoveryOutcome>> _inflightByMachine = {};
  // Serialize transport/session recovery so concurrent machine reconnects do
  // not interleave websocket/session establishment on the shared relay client.
  Future<void> _transportQueue = Future.value();

  ReconnectRecoveryCoordinator({
    required PairedMachineRepository machines,
    required WsSessionRepository wsRepo,
    required EventRepository eventRepo,
  }) : _machines = machines,
       _wsRepo = wsRepo,
       _eventRepo = eventRepo;

  Stream<ReconnectRecoveryNotification> get recoveries => _notifications.stream;

  Future<ReconnectRecoveryOutcome> recoverMachine(String machineId) {
    final pending = _inflightByMachine[machineId];
    if (pending != null) {
      return pending;
    }

    final completer = Completer<ReconnectRecoveryOutcome>();
    final future = completer.future;
    _inflightByMachine[machineId] = future;

    _transportQueue = _transportQueue.catchError((_) {}).then((_) async {
      try {
        final outcome = await _recoverMachine(machineId);
        completer.complete(outcome);
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        if (identical(_inflightByMachine[machineId], future)) {
          _inflightByMachine.remove(machineId);
        }
      }
    });

    return future;
  }

  Future<ReconnectRecoveryOutcome> _recoverMachine(String machineId) async {
    final machine = await _machines.getMachine(machineId);
    if (machine == null) {
      debugPrint('[ReconnectRecovery] machine not found: $machineId');
      return _emit(machineId, ReconnectRecoveryOutcome.failed);
    }

    try {
      final alreadyActive =
          _wsRepo.relayConnected.value &&
          _wsRepo.isConnected &&
          _wsRepo.hasSession(machineId);
      debugPrint(
        '[ReconnectRecovery] machine=$machineId start '
        'relayConnected=${_wsRepo.relayConnected.value} '
        'socketConnected=${_wsRepo.isConnected} '
        'hasSession=${_wsRepo.hasSession(machineId)}',
      );
      if (!alreadyActive) {
        await _wsRepo.ensureConnected(relayHttpUrl: machine.relayHttpUrl);
        if (!_wsRepo.hasSession(machineId)) {
          await _wsRepo.startSession(machine: machine);
        }
      } else {
        debugPrint(
          '[ReconnectRecovery] machine=$machineId outcome=complete '
          'reason=alreadyActive',
        );
        return _emit(machineId, ReconnectRecoveryOutcome.complete);
      }

      final resync = await _eventRepo.resync(machineId);
      await _eventRepo.reconcileSessionStatus(machineId);
      await _eventRepo.backfillMissingTitles(machineId);
      await _eventRepo.fetchPendingApprovals(machineId);

      // Incremental transcript trust is determined by events.resync. Metadata
      // repair still runs even when replay was partial and the active chat must
      // escalate to session.load fallback.
      final outcome = switch (resync.outcome) {
        ResyncOutcome.complete => ReconnectRecoveryOutcome.complete,
        ResyncOutcome.incomplete => ReconnectRecoveryOutcome.incomplete,
        ResyncOutcome.failed => ReconnectRecoveryOutcome.failed,
        ResyncOutcome.noCursor => ReconnectRecoveryOutcome.noCursor,
      };
      debugPrint(
        '[ReconnectRecovery] machine=$machineId outcome=$outcome '
        'resyncOutcome=${resync.outcome} '
        'lastSeqUsed=${resync.lastSeqUsed} '
        'highestSeqApplied=${resync.highestSeqApplied}',
      );
      return _emit(machineId, outcome);
    } catch (e) {
      debugPrint('[ReconnectRecovery] recover $machineId failed: $e');
      return _emit(machineId, ReconnectRecoveryOutcome.failed);
    }
  }

  ReconnectRecoveryOutcome _emit(
    String machineId,
    ReconnectRecoveryOutcome outcome,
  ) {
    _notifications.add(
      ReconnectRecoveryNotification(machineId: machineId, outcome: outcome),
    );
    return outcome;
  }

  Future<void> dispose() async {
    await _notifications.close();
  }
}
