import 'package:get/get.dart';
import 'package:muxagent/data/services/ws/models/ws_models.dart';

import '../../domain/paired_machine.dart';
import '../services/ws/relay_ws_client.dart';
import 'session_manager.dart';

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

  bool get isConnected => _relay.isConnected;

  Future<void> connect({required String relayHttpUrl}) {
    return _relay.connect(relayHttpUrl: relayHttpUrl);
  }

  Future<void> ensureConnected({required String relayHttpUrl}) async {
    if (_relay.isConnected) {
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
