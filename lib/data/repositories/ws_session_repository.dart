import 'dart:async';

import 'package:muxagent/data/services/ws/models/ws_models.dart';

import '../../domain/paired_machine.dart';
import '../services/ws/relay_ws_client.dart';
import 'session_manager.dart';
import '../../utils/snackbar_util.dart';

class WsSessionRepository {
  final RelayWsClient _relay;
  final SessionManager _sessions;
  late final StreamSubscription<WsEvent> _eventSub;

  WsSessionRepository({
    required RelayWsClient relay,
    required SessionManager sessions,
  }) : _relay = relay,
       _sessions = sessions {
    _eventSub = _relay.events.listen(_handleEvent);
  }

  /// Raw WS event stream for EventRepository to consume.
  Stream<WsEvent> get events => _relay.events;

  Stream<Set<String>> get activeSessions => _sessions.activeSessions;

  Set<String> get activeSessionIds => _sessions.activeSessionIds;

  bool hasSession(String machineId) => _sessions.hasSession(machineId);

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
  }) {
    return _relay.callRpc(machineId: machineId, method: method, params: params);
  }

  Future<void> close() => _relay.close();

  void dispose() {
    _eventSub.cancel();
  }

  void _handleEvent(WsEvent event) {
    if (event.type == 'echo') {
      final payload = event.payload;
      final from = payload['from']?.toString() ?? 'daemon';
      final message = payload['message']?.toString() ?? '';
      SnackbarUtil.showInfo('Echo from $from', message);
    }
  }
}
