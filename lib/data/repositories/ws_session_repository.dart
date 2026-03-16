import 'package:get/get.dart';
import 'package:muxagent/data/services/ws/models/ws_models.dart';

import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/event.dart';
import '../../domain/fs_entry.dart';
import '../../domain/paired_machine.dart';
import '../../domain/prompt_content_block.dart';
import '../services/ws/models/acp_session_models.dart';
import '../services/ws/event_envelope_parser.dart';
import '../services/ws/models/rpc_request_models.dart';
import '../services/ws/models/rpc_result_models.dart';
import '../services/ws/rpc_result_mapper.dart';
import '../services/ws/relay_ws_client.dart';
import '../services/ws/ws_types.dart';
import 'session_manager.dart';

class ResyncBatch {
  final List<AgentEvent> events;
  final bool complete;

  const ResyncBatch({required this.events, required this.complete});
}

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
    if (_relay.relayConnected.value) {
      return;
    }
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

  Future<ResyncBatch> resyncEvents({
    required String machineId,
    required int lastSeq,
  }) async {
    final response = await _relay.callRpcDecoded(
      machineId: machineId,
      method: 'events.resync',
      params: RpcResyncEventsParamsDto(lastSeq: lastSeq).toJson(),
      decode: RpcResyncResponseDto.fromJson,
    );
    final events = <AgentEvent>[];
    for (final payload in response.events) {
      final enrichedPayload = Map<String, dynamic>.from(payload);
      enrichedPayload.putIfAbsent('machineId', () => machineId);
      final event = EventEnvelopeParser.parse(
        WsEvent(type: WsMessageType.event.value, payload: enrichedPayload),
      );
      if (event != null && event.type != null) {
        events.add(event);
      }
    }
    return ResyncBatch(events: events, complete: response.complete);
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
