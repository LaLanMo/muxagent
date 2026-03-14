import 'package:get/get.dart';
import 'package:muxagent/data/services/ws/models/ws_models.dart';

import '../../domain/approval.dart';
import '../../domain/enums.dart';
import '../../domain/fs_entry.dart';
import '../../domain/paired_machine.dart';
import '../services/ws/models/acp_session_models.dart';
import '../services/ws/models/rpc_result_models.dart';
import '../services/ws/rpc_result_mapper.dart';
import '../services/ws/relay_ws_client.dart';
import 'session_manager.dart';

class ResyncBatch {
  final List<Map<String, dynamic>> events;
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
    final result = await callRpc(machineId: machineId, method: 'runtime.list');
    return AppRuntimeListResponseDto.fromJson(result);
  }

  Future<AppSessionCreateResponseDto> createSession({
    required String machineId,
    required String cwd,
    required String runtime,
    bool useWorktree = false,
    String? permissionMode,
  }) async {
    final result = await callRpc(
      machineId: machineId,
      method: 'session.create',
      params: {
        'cwd': cwd,
        'runtime': runtime,
        if (useWorktree) 'useWorktree': true,
        if (permissionMode != null && permissionMode.isNotEmpty)
          'permissionMode': permissionMode,
      },
    );
    return AppSessionCreateResponseDto.fromJson(result);
  }

  Future<AppSessionLoadResponseDto> loadSession({
    required String machineId,
    required String sessionId,
    required String cwd,
    required String runtime,
    String? permissionMode,
    String? model,
  }) async {
    final result = await callRpc(
      machineId: machineId,
      method: 'session.load',
      params: {
        'sessionId': sessionId,
        'cwd': cwd,
        'runtime': runtime,
        if (permissionMode != null && permissionMode.isNotEmpty)
          'permissionMode': permissionMode,
        if (model != null && model.isNotEmpty && model != 'default')
          'model': model,
      },
    );
    return AppSessionLoadResponseDto.fromJson(result);
  }

  Future<List<FsEntry>> listFiles({
    required String machineId,
    required String sessionId,
    required String path,
  }) async {
    final result = await callRpc(
      machineId: machineId,
      method: 'fs.list',
      params: {'sessionId': sessionId, 'path': path},
    );
    final response = RpcFsListResponseDto.fromJson(result);
    return RpcResultMapper.toFsEntries(response.entries);
  }

  Future<List<FsEntry>> searchFiles({
    required String machineId,
    required String sessionId,
    required String query,
  }) async {
    final result = await callRpc(
      machineId: machineId,
      method: 'fs.search',
      params: {'sessionId': sessionId, 'query': query},
    );
    final response = RpcFsSearchResponseDto.fromJson(result);
    return RpcResultMapper.toFsEntries(response.results);
  }

  Future<ResyncBatch> resyncEvents({
    required String machineId,
    required int lastSeq,
  }) async {
    final result = await callRpc(
      machineId: machineId,
      method: 'events.resync',
      params: {'lastSeq': lastSeq},
    );
    final response = RpcResyncResponseDto.fromJson(result);
    return ResyncBatch(events: response.events, complete: response.complete);
  }

  Future<List<ResolvedSessionSnapshot>> resolveSessions({
    required String machineId,
    required Iterable<String> sessionIds,
    String? runtime,
  }) async {
    final result = await callRpc(
      machineId: machineId,
      method: 'session.resolve',
      params: {
        'sessionIds': sessionIds.toList(),
        if (runtime != null && runtime.isNotEmpty) 'runtime': runtime,
      },
    );
    final response = RpcSessionResolveResponseDto.fromJson(result);
    return RpcResultMapper.toResolvedSessions(response.sessions);
  }

  Future<List<ApprovalRequest>> listPendingApprovals({
    required String machineId,
  }) async {
    final result = await callRpc(
      machineId: machineId,
      method: 'approvals.pending',
      params: const {},
    );
    final response = RpcPendingApprovalsResponseDto.fromJson(result);
    return RpcResultMapper.toPendingApprovals(response.approvals);
  }

  Future<Map<String, dynamic>> callRpc({
    required String machineId,
    required String method,
    Map<String, dynamic>? params,
  }) async {
    final payload = await _relay.callRpc(
      machineId: machineId,
      method: method,
      params: params,
    );

    final error = payload['error'] as String?;
    if (error != null && error.isNotEmpty) {
      throw Exception(error);
    }

    final result = payload['result'];
    if (result == null) {
      return <String, dynamic>{};
    }
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    throw Exception('invalid rpc result for $method');
  }

  Future<void> close() => _relay.close();

  Future<void> resetConnection({Object? reason}) {
    return _relay.resetConnection(reason: reason);
  }
}
