import 'dart:async';

import 'package:flutter/foundation.dart';

import 'event_repository.dart';
import 'paired_machine_repository.dart';
import 'session_chat_cache_repository.dart';
import 'ws_session_repository.dart';

enum TranscriptRecoveryState { skipped, complete, fallbackNeeded, failed }

enum TranscriptRecoveryMode { metadataOnly, replayIfPossible }

enum MetadataRecoveryState { complete, degraded, skipped }

class ReconnectRecoveryResult {
  final String machineId;
  final TranscriptRecoveryState transcript;
  final MetadataRecoveryState metadata;
  final ResyncOutcome? resyncOutcome;
  final bool sessionReady;
  final bool statusesOk;
  final bool knownSessionsOk;
  final bool approvalsOk;
  final Object? transportError;

  const ReconnectRecoveryResult({
    required this.machineId,
    required this.transcript,
    required this.metadata,
    required this.sessionReady,
    required this.statusesOk,
    required this.knownSessionsOk,
    required this.approvalsOk,
    this.resyncOutcome,
    this.transportError,
  });
}

class ReconnectRecoveryCoordinator {
  final PairedMachineRepository _machines;
  final WsSessionRepository _wsRepo;
  final EventRepository _eventRepo;
  final SessionChatCacheRepository _chatCacheRepo;
  final _notifications = StreamController<ReconnectRecoveryResult>.broadcast();
  // Join repeated recovery requests for the same machine onto one future.
  final Map<String, Future<ReconnectRecoveryResult>> _inflightByRequest = {};
  // Serialize transport/session recovery so concurrent machine reconnects do
  // not interleave websocket/session establishment on the shared relay client.
  Future<void> _transportQueue = Future.value();

  ReconnectRecoveryCoordinator({
    required PairedMachineRepository machines,
    required WsSessionRepository wsRepo,
    required EventRepository eventRepo,
    required SessionChatCacheRepository chatCacheRepo,
  }) : _machines = machines,
       _wsRepo = wsRepo,
       _eventRepo = eventRepo,
       _chatCacheRepo = chatCacheRepo;

  Stream<ReconnectRecoveryResult> get recoveries => _notifications.stream;

  Future<ReconnectRecoveryResult> recoverMachine(
    String machineId, {
    TranscriptRecoveryMode transcriptMode =
        TranscriptRecoveryMode.replayIfPossible,
  }) {
    final requestKey = _requestKey(machineId, transcriptMode);
    final pending = _inflightByRequest[requestKey];
    if (pending != null) {
      return pending;
    }

    final completer = Completer<ReconnectRecoveryResult>();
    final future = completer.future;
    _inflightByRequest[requestKey] = future;

    _transportQueue = _transportQueue.catchError((_) {}).then((_) async {
      try {
        final outcome = await _recoverMachine(
          machineId,
          transcriptMode: transcriptMode,
        );
        completer.complete(outcome);
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        if (identical(_inflightByRequest[requestKey], future)) {
          _inflightByRequest.remove(requestKey);
        }
      }
    });

    return future;
  }

  String _requestKey(String machineId, TranscriptRecoveryMode transcriptMode) {
    return '$machineId:${transcriptMode.name}';
  }

  Future<ReconnectRecoveryResult> _recoverMachine(
    String machineId, {
    required TranscriptRecoveryMode transcriptMode,
  }) async {
    final machine = await _machines.getMachine(machineId);
    if (machine == null) {
      debugPrint('[ReconnectRecovery] machine not found: $machineId');
      return _emit(
        ReconnectRecoveryResult(
          machineId: machineId,
          transcript: TranscriptRecoveryState.failed,
          metadata: MetadataRecoveryState.skipped,
          sessionReady: false,
          statusesOk: false,
          knownSessionsOk: false,
          approvalsOk: false,
          transportError: StateError('machine not found'),
        ),
      );
    }

    try {
      final alreadyActiveTransport =
          _wsRepo.relayConnected.value &&
          _wsRepo.isConnected &&
          _wsRepo.hasSession(machineId);
      debugPrint(
        '[ReconnectRecovery] machine=$machineId start '
        'transcriptMode=${transcriptMode.name} '
        'relayConnected=${_wsRepo.relayConnected.value} '
        'socketConnected=${_wsRepo.isConnected} '
        'hasSession=${_wsRepo.hasSession(machineId)} '
        'alreadyActive=$alreadyActiveTransport',
      );
      Object? transportError;
      if (!alreadyActiveTransport) {
        try {
          await _wsRepo.ensureConnected(relayHttpUrl: machine.relayHttpUrl);
          if (!_wsRepo.hasSession(machineId)) {
            await _wsRepo.startSession(machine: machine);
          }
        } catch (e) {
          transportError = e;
        }
      }

      final sessionReady =
          _wsRepo.relayConnected.value &&
          _wsRepo.isConnected &&
          _wsRepo.hasSession(machineId);
      if (!sessionReady) {
        debugPrint(
          '[ReconnectRecovery] machine=$machineId transcript=failed '
          'metadata=skipped sessionReady=$sessionReady error=$transportError',
        );
        return _emit(
          ReconnectRecoveryResult(
            machineId: machineId,
            transcript: TranscriptRecoveryState.failed,
            metadata: MetadataRecoveryState.skipped,
            sessionReady: false,
            statusesOk: false,
            knownSessionsOk: false,
            approvalsOk: false,
            transportError: transportError,
          ),
        );
      }

      final resync = transcriptMode == TranscriptRecoveryMode.metadataOnly
          ? null
          : await _eventRepo.resync(machineId);
      // Keep metadata/session-status repair ordered so resolve-based metadata
      // refresh runs before status repair and pending-approval hydration.
      final knownSessions = await _eventRepo.syncKnownSessions(machineId);
      final statuses = await _eventRepo.reconcileSessionStatus(machineId);
      final approvals = await _eventRepo.fetchPendingApprovals(machineId);

      final transcript = resync == null
          ? TranscriptRecoveryState.skipped
          : switch (resync.outcome) {
              ResyncOutcome.complete => TranscriptRecoveryState.complete,
              ResyncOutcome.incomplete =>
                TranscriptRecoveryState.fallbackNeeded,
              ResyncOutcome.noCursor => TranscriptRecoveryState.fallbackNeeded,
              ResyncOutcome.reset => TranscriptRecoveryState.fallbackNeeded,
              ResyncOutcome.failed =>
                sessionReady
                    ? TranscriptRecoveryState.fallbackNeeded
                    : TranscriptRecoveryState.failed,
            };
      final metadata = knownSessions.ok && statuses.ok && approvals.ok
          ? MetadataRecoveryState.complete
          : MetadataRecoveryState.degraded;
      final result = ReconnectRecoveryResult(
        machineId: machineId,
        transcript: transcript,
        metadata: metadata,
        resyncOutcome: resync?.outcome,
        sessionReady: sessionReady,
        statusesOk: statuses.ok,
        knownSessionsOk: knownSessions.ok,
        approvalsOk: approvals.ok,
        transportError: transportError ?? resync?.error,
      );
      if (result.transcript == TranscriptRecoveryState.fallbackNeeded) {
        await _chatCacheRepo.markMachineCachesStale(machineId);
      }
      debugPrint(
        '[ReconnectRecovery] machine=$machineId '
        'transcript=${result.transcript} metadata=${result.metadata} '
        'resyncOutcome=${result.resyncOutcome} sessionReady=${result.sessionReady} '
        'knownSessionsOk=${result.knownSessionsOk} statusesOk=${result.statusesOk} '
        'approvalsOk=${result.approvalsOk} '
        'lastSeqUsed=${resync?.lastSeqUsed} highestSeqApplied=${resync?.highestSeqApplied}',
      );
      return _emit(result);
    } catch (e) {
      final sessionReady =
          _wsRepo.relayConnected.value &&
          _wsRepo.isConnected &&
          _wsRepo.hasSession(machineId);
      final transcript = transcriptMode == TranscriptRecoveryMode.metadataOnly
          ? TranscriptRecoveryState.skipped
          : sessionReady
          ? TranscriptRecoveryState.fallbackNeeded
          : TranscriptRecoveryState.failed;
      if (transcript == TranscriptRecoveryState.fallbackNeeded) {
        await _chatCacheRepo.markMachineCachesStale(machineId);
      }
      debugPrint('[ReconnectRecovery] recover $machineId failed: $e');
      return _emit(
        ReconnectRecoveryResult(
          machineId: machineId,
          transcript: transcript,
          metadata: MetadataRecoveryState.skipped,
          sessionReady: sessionReady,
          statusesOk: false,
          knownSessionsOk: false,
          approvalsOk: false,
          transportError: e,
        ),
      );
    }
  }

  ReconnectRecoveryResult _emit(ReconnectRecoveryResult result) {
    _notifications.add(result);
    return result;
  }

  Future<void> dispose() async {
    await _notifications.close();
  }
}
