import 'dart:async';

import 'package:get/get.dart';
import 'package:muxagent/data/services/ws/models/ws_models.dart';

import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/fs_entry.dart';
import '../../domain/paired_machine.dart';
import '../../domain/prompt_content_block.dart';
import '../services/ws/models/acp_session_models.dart';
import '../services/ws/models/rpc_request_models.dart';
import '../services/ws/models/rpc_result_models.dart';
import '../services/ws/rpc_result_mapper.dart';
import '../services/ws/relay_ws_client.dart';
import '../services/ws/ws_types.dart';
import 'session_manager.dart';

enum ReplayResyncStatus { ok, gap, reset }

typedef ResyncPageConsumer = FutureOr<void> Function(ReplayPage page);

class ReplayPage {
  final int streamEpoch;
  final List<WsEvent> events;

  const ReplayPage({required this.streamEpoch, required this.events});
}

class ReplaySummary {
  final ReplayResyncStatus status;
  final int streamEpoch;
  final int replayedThroughSeq;

  const ReplaySummary({
    required this.status,
    required this.streamEpoch,
    required this.replayedThroughSeq,
  });
}

class ReplayHeadSnapshot {
  final int streamEpoch;
  final int replayedThroughSeq;

  const ReplayHeadSnapshot({
    required this.streamEpoch,
    required this.replayedThroughSeq,
  });
}

const _pagedResyncMaxBytes = 256 * 1024;
const _pagedResyncMaxEvents = 128;
const _pagedResyncMaxPages = 64;

class WsSessionRepository {
  final RelayWsClient _relay;
  final SessionManager _sessions;

  WsSessionRepository({
    required RelayWsClient relay,
    required SessionManager sessions,
  }) : _relay = relay,
       _sessions = sessions;

  /// Raw WS event stream for EventRepository to consume.
  Stream<WsEvent> get events => _relay.events;

  Stream<WsMachineStatus> get machineStatus => _relay.machineStatus;

  Stream<Set<String>> get activeSessions => _sessions.activeSessions;

  Set<String> get activeSessionIds => _sessions.activeSessionIds;

  bool hasSession(String machineId) => _sessions.hasSession(machineId);

  RxBool get relayConnected => _relay.relayConnected;
  Rx<ConnState> get connectionState => _relay.connectionState;

  bool get isConnected => _relay.isConnected;

  Future<void> connect({required String relayHttpUrl}) {
    return _relay.connect(relayHttpUrl: relayHttpUrl);
  }

  Future<void> ensureConnected({required String relayHttpUrl}) async {
    await _relay.connect(relayHttpUrl: relayHttpUrl);
  }

  Future<void> startSession({required PairedMachine machine}) {
    return _relay.startSession(machine: machine);
  }

  Future<void> endSession(String machineId) {
    return _relay.endSession(machineId);
  }

  Future<AppRuntimeListResponseDto> listRuntimes({
    required String machineId,
  }) async {
    return _relay.callRpcDecoded(
      machineId: machineId,
      method: 'runtime.list',
      decode: AppRuntimeListResponseDto.fromJson,
    );
  }

  Future<AppSessionCreateResponseDto> createSession({
    required String machineId,
    required String cwd,
    required String runtime,
    bool useWorktree = false,
    String? permissionMode,
  }) async {
    return _relay.callRpcDecoded(
      machineId: machineId,
      method: 'session.create',
      params: RpcSessionCreateParamsDto(
        cwd: cwd,
        runtime: runtime,
        useWorktree: useWorktree,
        permissionMode: permissionMode,
      ).toJson(),
      decode: AppSessionCreateResponseDto.fromJson,
    );
  }

  Future<AppSessionLoadResponseDto> loadSession({
    required String machineId,
    required String sessionId,
    required String cwd,
    required String runtime,
    String? permissionMode,
    String? model,
  }) async {
    return _relay.callRpcDecoded(
      machineId: machineId,
      method: 'session.load',
      params: RpcSessionLoadParamsDto(
        sessionId: sessionId,
        cwd: cwd,
        runtime: runtime,
        permissionMode: permissionMode,
        model: model,
      ).toJson(),
      decode: AppSessionLoadResponseDto.fromJson,
    );
  }

  Future<List<FsEntry>> listFiles({
    required String machineId,
    required String sessionId,
    required String path,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'fs.list',
      params: RpcFsListParamsDto(sessionId: sessionId, path: path).toJson(),
      decode: RpcFsListResponseDto.fromJson,
    );
    return RpcResultMapper.toFsEntries(response.entries);
  }

  Future<List<FsEntry>> searchFiles({
    required String machineId,
    required String sessionId,
    required String query,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'fs.search',
      params: RpcFsSearchParamsDto(sessionId: sessionId, query: query).toJson(),
      decode: RpcFsSearchResponseDto.fromJson,
    );
    return RpcResultMapper.toFsEntries(response.results);
  }

  Future<ReplaySummary> consumeResyncPages({
    required String machineId,
    required int lastSeq,
    int? streamEpoch,
    required ResyncPageConsumer onPage,
  }) async {
    try {
      return await _consumeResyncPagesPaged(
        machineId: machineId,
        lastSeq: lastSeq,
        streamEpoch: streamEpoch,
        onPage: onPage,
      );
    } catch (e) {
      if (!_isUnknownMethodError(e, 'events.resyncPage')) {
        rethrow;
      }
    }

    return _consumeResyncPagesLegacy(
      machineId: machineId,
      lastSeq: lastSeq,
      streamEpoch: streamEpoch,
      onPage: onPage,
    );
  }

  Future<ReplaySummary> _consumeResyncPagesLegacy({
    required String machineId,
    required int lastSeq,
    int? streamEpoch,
    required ResyncPageConsumer onPage,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'events.resync',
      params: RpcResyncEventsParamsDto(
        lastSeq: lastSeq,
        streamEpoch: streamEpoch,
      ).toJson(),
      decode: RpcResyncResponseDto.fromJson,
    );
    final status = switch (response.status) {
      RpcResyncStatusDto.ok => ReplayResyncStatus.ok,
      RpcResyncStatusDto.gap => ReplayResyncStatus.gap,
      RpcResyncStatusDto.reset => ReplayResyncStatus.reset,
    };
    if (status == ReplayResyncStatus.ok && response.events.isNotEmpty) {
      await onPage(
        ReplayPage(
          streamEpoch: response.streamEpoch,
          events: _mapReplayWsEvents(
            machineId: machineId,
            eventsPayload: response.events,
          ),
        ),
      );
    }
    return ReplaySummary(
      status: status,
      streamEpoch: response.streamEpoch,
      replayedThroughSeq: response.replayedThroughSeq,
    );
  }

  Future<ReplaySummary> _consumeResyncPagesPaged({
    required String machineId,
    required int lastSeq,
    int? streamEpoch,
    required ResyncPageConsumer onPage,
  }) async {
    var pageAfterSeq = lastSeq;
    ReplayResyncStatus? status;
    int? responseEpoch;
    var replayedThroughSeq = lastSeq;
    final payloads = <Map<String, dynamic>>[];
    var truncatedByPageLimit = true;

    for (var pageIndex = 0; pageIndex < _pagedResyncMaxPages; pageIndex++) {
      final response = await _relay.callRpcDecoded(
        machineId: machineId,
        method: 'events.resyncPage',
        params: RpcResyncEventsPageParamsDto(
          lastSeq: pageAfterSeq,
          streamEpoch: streamEpoch,
          maxBytes: _pagedResyncMaxBytes,
          maxEvents: _pagedResyncMaxEvents,
        ).toJson(),
        decode: RpcResyncPageResponseDto.fromJson,
      );
      final pageStatus = switch (response.status) {
        RpcResyncStatusDto.ok => ReplayResyncStatus.ok,
        RpcResyncStatusDto.gap => ReplayResyncStatus.gap,
        RpcResyncStatusDto.reset => ReplayResyncStatus.reset,
      };
      status ??= pageStatus;
      responseEpoch ??= response.streamEpoch;
      if (responseEpoch != response.streamEpoch) {
        throw Exception('inconsistent resync pagination epoch');
      }
      replayedThroughSeq = response.replayedThroughSeq;
      if (pageStatus == ReplayResyncStatus.ok && response.events.isNotEmpty) {
        await onPage(
          ReplayPage(
            streamEpoch: response.streamEpoch,
            events: _mapReplayWsEvents(
              machineId: machineId,
              eventsPayload: response.events,
            ),
          ),
        );
      }

      if (status != ReplayResyncStatus.ok || !response.hasMore) {
        truncatedByPageLimit = false;
        break;
      }
      if (response.nextAfterSeq <= pageAfterSeq) {
        throw Exception('invalid resync pagination cursor');
      }
      pageAfterSeq = response.nextAfterSeq;
    }

    if (truncatedByPageLimit) {
      throw Exception('resync pagination exceeded page budget');
    }

    if (status == null || responseEpoch == null) {
      throw Exception('missing resync pagination response');
    }

    return ReplaySummary(
      status: status,
      streamEpoch: responseEpoch,
      replayedThroughSeq: replayedThroughSeq,
    );
  }

  List<WsEvent> _mapReplayWsEvents({
    required String machineId,
    required List<Map<String, dynamic>> eventsPayload,
  }) {
    final events = <WsEvent>[];
    for (final payload in eventsPayload) {
      final enrichedPayload = Map<String, dynamic>.from(payload);
      enrichedPayload.putIfAbsent('machineId', () => machineId);
      events.add(
        WsEvent(type: WsMessageType.event.value, payload: enrichedPayload),
      );
    }
    return events;
  }

  Future<ReplayHeadSnapshot> fetchReplayHead({
    required String machineId,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'events.head',
      params: const {},
      decode: RpcReplayHeadResponseDto.fromJson,
    );
    return ReplayHeadSnapshot(
      streamEpoch: response.streamEpoch,
      replayedThroughSeq: response.replayedThroughSeq,
    );
  }

  bool _isUnknownMethodError(Object error, String method) {
    final text = error.toString();
    return text.contains('unknown method: $method') ||
        text.contains('method "$method" not found') ||
        text.contains("method '$method' not found") ||
        text.contains('method not found');
  }

  Future<List<ResolvedSessionSnapshot>> resolveSessions({
    required String machineId,
    required Iterable<String> sessionIds,
    String? runtime,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'session.resolve',
      params: RpcSessionResolveParamsDto(
        sessionIds: sessionIds.toList(),
        runtime: runtime,
      ).toJson(),
      decode: RpcSessionResolveResponseDto.fromJson,
    );
    return RpcResultMapper.toResolvedSessions(response.sessions);
  }

  Future<List<ApprovalRequest>> listPendingApprovals({
    required String machineId,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'approvals.pending',
      params: const {},
      decode: RpcPendingApprovalsResponseDto.fromJson,
    );
    return RpcResultMapper.toPendingApprovals(response.approvals);
  }

  Future<void> setMode({
    required String machineId,
    required String sessionId,
    required String permissionMode,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'session.setMode',
      params: RpcSessionSetModeParamsDto(
        sessionId: sessionId,
        permissionMode: permissionMode,
      ).toJson(),
      decode: RpcOkResponseDto.fromJson,
    );
    if (!response.ok) {
      throw Exception('session.setMode was not acknowledged');
    }
  }

  Future<void> setConfigOption({
    required String machineId,
    required String sessionId,
    required String configId,
    required String value,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'session.setConfigOption',
      params: RpcSessionSetConfigOptionParamsDto(
        sessionId: sessionId,
        configId: configId,
        value: value,
      ).toJson(),
      decode: RpcOkResponseDto.fromJson,
    );
    if (!response.ok) {
      throw Exception('session.setConfigOption was not acknowledged');
    }
  }

  Future<void> promptSession({
    required String machineId,
    required String sessionId,
    required List<PromptContentBlock> content,
  }) async {
    final params = RpcSessionPromptParamsDto(
      sessionId: sessionId,
      content: content.map(PromptContentBlockDto.fromDomain).toList(),
    );
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'session.prompt',
      params: params.toJson(),
      decode: RpcAcceptedResponseDto.fromJson,
    );
    if (!response.accepted) {
      throw Exception('session.prompt was not accepted');
    }
  }

  Future<void> replyApproval({
    required String machineId,
    required String sessionId,
    required String requestId,
    required String optionId,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'approval.reply',
      params: RpcApprovalReplyParamsDto(
        sessionId: sessionId,
        requestId: requestId,
        optionId: optionId,
      ).toJson(),
      decode: RpcOkResponseDto.fromJson,
    );
    if (!response.ok) {
      throw Exception('approval.reply was not acknowledged');
    }
  }

  Future<void> cancelSession({
    required String machineId,
    required String sessionId,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'session.cancel',
      params: RpcSessionCancelParamsDto(sessionId: sessionId).toJson(),
      decode: RpcOkResponseDto.fromJson,
    );
    if (!response.ok) {
      throw Exception('session.cancel was not acknowledged');
    }
  }

  Future<void> close() => _relay.close();

  Future<void> resetConnection({Object? reason}) {
    return _relay.resetConnection(reason: reason);
  }
}
