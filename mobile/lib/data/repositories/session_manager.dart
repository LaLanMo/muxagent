import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';

import '../services/ws/models/rpc_transport_models.dart';
import '../services/ws/session_crypto.dart';

class SessionState {
  // begin session: session-init sent, waiting for session-ack.
  // active session: session key established and RPC allowed.
  SessionCrypto? session;
  String? clientEphemeralPubB64;
  KeyPair? clientEphemeralKeyPair;
  Completer<void>? sessionCompleter;
  Timer? sessionTimer;
  final Map<String, Completer<RpcResponseEnvelopeDto>> pendingRpc = {};
  final Map<String, Timer> pendingTimers = {};
}

class SessionManager {
  final Duration rpcTimeout;
  final Duration sessionInitTimeout;
  final Map<String, SessionState> _sessions = {};
  final Set<String> _activeSessions = {};
  final ValueNotifier<Set<String>> _activeSessionIdsListenable = ValueNotifier(
    const <String>{},
  );

  SessionManager({
    this.rpcTimeout = const Duration(seconds: 10),
    this.sessionInitTimeout = const Duration(seconds: 10),
  });

  SessionState getOrCreate(String machineId) {
    return _sessions.putIfAbsent(machineId, SessionState.new);
  }

  Set<String> get activeSessionIds => Set.unmodifiable(_activeSessions);

  ValueListenable<Set<String>> get activeSessionIdsListenable =>
      _activeSessionIdsListenable;

  bool hasSession(String machineId) => _sessions[machineId]?.session != null;

  SessionState? getState(String machineId) => _sessions[machineId];

  SessionCrypto? getSession(String machineId) => _sessions[machineId]?.session;

  String? getClientEphemeralPub(String machineId) =>
      _sessions[machineId]?.clientEphemeralPubB64;

  KeyPair? getClientEphemeralKeyPair(String machineId) =>
      _sessions[machineId]?.clientEphemeralKeyPair;

  void beginSession({
    required String machineId,
    required String clientEphemeralPubB64,
    required KeyPair clientEphemeralKeyPair,
    required Completer<void> completer,
  }) {
    final state = getOrCreate(machineId);
    if (state.session != null || state.sessionCompleter != null) {
      throw StateError('session already in progress');
    }
    state.clientEphemeralPubB64 = clientEphemeralPubB64;
    state.clientEphemeralKeyPair = clientEphemeralKeyPair;
    state.sessionCompleter = completer;
    state.sessionTimer?.cancel();
    state.sessionTimer = Timer(sessionInitTimeout, () {
      failSession(machineId, 'session init timeout');
    });
  }

  void activateSession(String machineId, SessionCrypto session) {
    final state = getOrCreate(machineId);
    state.session = session;
    state.sessionTimer?.cancel();
    _setActive(machineId, true);
  }

  void completeSession(String machineId) {
    final state = _sessions[machineId];
    if (state == null) return;
    state.sessionTimer?.cancel();
    final completer = state.sessionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    state.sessionCompleter = null;
  }

  void failSession(String machineId, Object error) {
    final state = _sessions[machineId];
    if (state == null) return;
    state.sessionTimer?.cancel();
    final completer = state.sessionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
    state.sessionCompleter = null;
    state.clientEphemeralKeyPair = null;
    state.clientEphemeralPubB64 = null;
    if (state.session == null) {
      for (final timer in state.pendingTimers.values) {
        timer.cancel();
      }
      _sessions.remove(machineId);
      _setActive(machineId, false);
    }
  }

  Completer<RpcResponseEnvelopeDto> registerPendingRpc(
    String machineId,
    String msgId,
  ) {
    final state = getOrCreate(machineId);
    final completer = Completer<RpcResponseEnvelopeDto>();
    state.pendingRpc[msgId] = completer;
    state.pendingTimers[msgId]?.cancel();
    state.pendingTimers[msgId] = Timer(rpcTimeout, () {
      failPendingRpc(machineId, msgId, 'rpc timeout');
    });
    return completer;
  }

  void resolvePendingRpc(
    String machineId,
    String msgId,
    RpcResponseEnvelopeDto payload,
  ) {
    final state = _sessions[machineId];
    if (state == null) return;
    final completer = state.pendingRpc.remove(msgId);
    state.pendingTimers.remove(msgId)?.cancel();
    if (completer != null && !completer.isCompleted) {
      completer.complete(payload);
    }
  }

  void failPendingRpc(String machineId, String msgId, Object error) {
    final state = _sessions[machineId];
    if (state == null) return;
    final completer = state.pendingRpc.remove(msgId);
    state.pendingTimers.remove(msgId)?.cancel();
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }

  void endSession(String machineId) {
    final state = _sessions.remove(machineId);
    if (state == null) return;
    _disposeSessionState(state, StateError('session ended'));
    _setActive(machineId, false);
  }

  void invalidateSession(String machineId, Object error) {
    final state = _sessions.remove(machineId);
    if (state == null) return;
    _disposeSessionState(state, error);
    _setActive(machineId, false);
  }

  void endAll(Object? error) {
    for (final entry in _sessions.entries) {
      final state = entry.value;
      if (error != null) {
        final completer = state.sessionCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(error);
        }
        for (final rpc in state.pendingRpc.values) {
          if (!rpc.isCompleted) {
            rpc.completeError(error);
          }
        }
      }
      state.sessionTimer?.cancel();
      for (final timer in state.pendingTimers.values) {
        timer.cancel();
      }
    }
    _sessions.clear();
    if (_activeSessions.isNotEmpty) {
      _activeSessions.clear();
      _emitActiveSessions();
    }
  }

  void failPendingSessions(Object error) {
    for (final entry in _sessions.entries) {
      final machineId = entry.key;
      final state = entry.value;
      if (state.session == null && state.sessionCompleter != null) {
        failSession(machineId, error);
      }
    }
  }

  void dispose() {
    _activeSessionIdsListenable.dispose();
  }

  void _setActive(String machineId, bool active) {
    final changed = active
        ? _activeSessions.add(machineId)
        : _activeSessions.remove(machineId);
    if (changed) {
      _emitActiveSessions();
    }
  }

  void _emitActiveSessions() {
    final activeIds = Set.unmodifiable({..._activeSessions});
    _activeSessionIdsListenable.value = activeIds;
  }

  void _disposeSessionState(SessionState state, Object error) {
    state.sessionTimer?.cancel();
    final sessionCompleter = state.sessionCompleter;
    if (sessionCompleter != null && !sessionCompleter.isCompleted) {
      sessionCompleter.completeError(error);
    }
    state.sessionCompleter = null;
    for (final entry in state.pendingRpc.entries) {
      final completer = entry.value;
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    for (final timer in state.pendingTimers.values) {
      timer.cancel();
    }
    state.pendingTimers.clear();
    state.pendingRpc.clear();
    state.session = null;
    state.clientEphemeralKeyPair = null;
    state.clientEphemeralPubB64 = null;
  }
}
