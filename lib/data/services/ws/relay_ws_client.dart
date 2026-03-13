import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';

import '../../../domain/enums.dart';
import '../../../domain/master_key.dart';
import '../../../domain/paired_machine.dart';

import 'base_ws_client.dart';
import 'models/ws_models.dart';
import 'session_crypto.dart';
import '../../repositories/session_manager.dart';
import 'token_service.dart';
import 'ws_types.dart';

class RelayWsClient {
  final CryptoService _crypto;
  final TokenService _tokens;
  final SessionManager _sessions;
  final Ed25519 _ed25519 = Ed25519();
  final X25519 _x25519 = X25519();

  final BaseWsClient _ws = BaseWsClient();
  final relayConnected = false.obs;
  final connectionState = ConnState.disconnected.obs;
  Completer<void>? _registeredCompleter;
  Future<void>? _connectFuture;
  final _events = StreamController<WsEvent>.broadcast();
  final _errors = StreamController<WsErrorMessage>.broadcast();
  final _machineStatus = StreamController<WsMachineStatus>.broadcast();

  final Map<String, PairedMachine> _machines = {};
  MasterKey? _masterKey;

  RelayWsClient({
    required CryptoService crypto,
    required TokenService tokens,
    required SessionManager sessions,
  }) : _sessions = sessions,
       _crypto = crypto,
       _tokens = tokens;

  Stream<WsEvent> get events => _events.stream;
  Stream<WsErrorMessage> get errors => _errors.stream;
  Stream<WsMachineStatus> get machineStatus => _machineStatus.stream;

  bool get isConnected => _ws.isConnected;

  Future<void> connect({required String relayHttpUrl}) async {
    if (relayConnected.value) {
      connectionState.value = ConnState.connected;
      return;
    }
    if (_connectFuture != null) {
      connectionState.value = ConnState.reconnecting;
      return _connectFuture!;
    }
    final pendingRegistration = _registeredCompleter;
    if (_ws.isConnected && pendingRegistration != null) {
      connectionState.value = ConnState.reconnecting;
      return pendingRegistration.future;
    }
    connectionState.value = ConnState.reconnecting;

    final future = _connectInternal(relayHttpUrl);
    _connectFuture = future;
    try {
      await future;
    } finally {
      if (identical(_connectFuture, future)) {
        _connectFuture = null;
      }
    }
  }

  Future<void> _connectInternal(String relayHttpUrl) async {
    if (_ws.isConnected && !relayConnected.value) {
      await resetConnection(reason: 'stale relay registration');
    }

    if (_ws.isConnected) {
      return;
    }

    final masterKey = await _crypto.loadMasterKey();
    if (masterKey == null) {
      throw Exception('Master key not configured');
    }
    _masterKey = masterKey;

    final wsUrl = _wsUrlFromHttp(relayHttpUrl);
    await _ws.connect(
      wsUrl,
      onMessage: _handleMessage,
      onError: (err) {
        relayConnected.value = false;
        connectionState.value = ConnState.disconnected;
        _registeredCompleter?.completeError(err);
        _sessions.endAll(err);
      },
      onDone: () {
        relayConnected.value = false;
        connectionState.value = ConnState.disconnected;
        _registeredCompleter?.completeError('socket closed');
        _sessions.endAll('socket closed');
      },
    );

    final connectToken = await _tokens.buildConnectToken(
      key: masterKey,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
    );

    _registeredCompleter = Completer<void>();
    debugPrint('[WS] connect masterId=${masterKey.id}');
    debugPrint('[WS] connect token=$connectToken');
    debugPrint('[WS] sending register as client to $wsUrl');
    _ws.sendJson(
      WsRegister(
        type: WsMessageType.register.value,
        role: WsRole.client.value,
        connectToken: connectToken,
      ).toJson(),
    );
    await _registeredCompleter!.future;
    debugPrint('[WS] registered successfully');
  }

  Future<void> startSession({required PairedMachine machine}) async {
    if (!_ws.isConnected) {
      throw Exception('not connected');
    }
    final masterKey = _masterKey;
    if (masterKey == null) {
      throw Exception('master key missing');
    }

    _machines[machine.machineId] = machine;
    final machineToken = await _tokens.buildMachineToken(
      key: masterKey,
      machineId: machine.machineId,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 3)),
    );

    final keyPair = await _x25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final clientEphemeralPubB64 = base64Encode(publicKey.bytes);
    final sessionCompleter = Completer<void>();
    try {
      _sessions.beginSession(
        machineId: machine.machineId,
        clientEphemeralPubB64: clientEphemeralPubB64,
        clientEphemeralKeyPair: keyPair,
        completer: sessionCompleter,
      );
    } on StateError catch (e) {
      throw Exception(
        'session already in progress for ${machine.machineId}: ${e.message}',
      );
    }

    final sessionInitMessage =
        'muxagent-session-init-v1|${machine.machineId}|$clientEphemeralPubB64';
    final signature = await _crypto.signMessage(sessionInitMessage, masterKey);

    debugPrint('[WS] sending session_init for ${machine.machineId}');
    _ws.sendJson(
      WsSessionInit(
        type: WsMessageType.sessionInit.value,
        machineId: machine.machineId,
        machineToken: machineToken,
        clientEphemeralPub: clientEphemeralPubB64,
        signature: signature,
        force: true,
      ).toJson(),
    );
    await sessionCompleter.future;
    debugPrint('[WS] session established for ${machine.machineId}');
  }

  Future<void> endSession(String machineId) async {
    if (!_ws.isConnected) {
      _sessions.endSession(machineId);
      return;
    }
    _ws.sendJson(
      WsSessionEnd(
        type: WsMessageType.sessionEnd.value,
        machineId: machineId,
      ).toJson(),
    );
    _sessions.endSession(machineId);
  }

  Future<Map<String, dynamic>> callRpc({
    required String machineId,
    required String method,
    Map<String, dynamic>? params,
  }) async {
    final session = _sessions.getSession(machineId);
    if (session == null) {
      throw Exception('no active session');
    }
    final msgId = _randomId();
    final payload = WsRpcPayload(
      method: method,
      params: params ?? <String, dynamic>{},
    ).toJson();
    final payloadBytes = utf8.encode(jsonEncode(payload));
    final encrypted = await session.encrypt(
      WsMessageType.rpc.value,
      msgId,
      Uint8List.fromList(payloadBytes),
    );
    final completer = _sessions.registerPendingRpc(machineId, msgId);
    _ws.sendJson(
      WsEncryptedMessage(
        type: WsMessageType.rpc.value,
        machineId: machineId,
        msgId: msgId,
        nonce: encrypted.nonceB64,
        ciphertext: encrypted.ciphertextB64,
      ).toJson(),
    );
    return completer.future;
  }

  Future<void> resetConnection({Object? reason}) async {
    final error = reason ?? 'connection reset';
    relayConnected.value = false;
    connectionState.value = ConnState.disconnected;
    final completer = _registeredCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
    _registeredCompleter = null;
    await _ws.close();
    _sessions.endAll(error);
  }

  Future<void> close() async {
    await resetConnection();
    await _events.close();
    await _errors.close();
    await _machineStatus.close();
  }

  void _handleMessage(String raw) async {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = WsMessageType.fromValue(msg['type'] as String?);
    if (type == null) {
      return;
    }

    try {
      switch (type) {
        case WsMessageType.registered:
          relayConnected.value = true;
          connectionState.value = ConnState.connected;
          _registeredCompleter?.complete();
          _registeredCompleter = null;
          return;
        case WsMessageType.sessionAck:
          await _handleSessionAck(WsSessionAck.fromJson(msg));
          return;
        case WsMessageType.sessionEnd:
          _sessions.endSession(WsSessionEnd.fromJson(msg).machineId);
          return;
        case WsMessageType.response:
          await _handleResponse(WsEncryptedMessage.fromJson(msg));
          return;
        case WsMessageType.event:
          await _handleEvent(WsEncryptedMessage.fromJson(msg));
          return;
        case WsMessageType.rpc:
          await _handleRpc(WsEncryptedMessage.fromJson(msg));
          return;
        case WsMessageType.machineOnline:
        case WsMessageType.machineOffline:
          _machineStatus.add(WsMachineStatus.fromJson(msg));
          return;
        case WsMessageType.error:
          final error = WsErrorMessage.fromJson(msg);
          debugPrint('[WS] error from relay: ${error.error}');
          if (_registeredCompleter != null) {
            _registeredCompleter?.completeError(error.error);
            _sessions.endAll(error.error);
          } else {
            _errors.add(error);
            _sessions.failPendingSessions(error.error);
          }
          return;
        default:
          return;
      }
    } catch (_) {
      return;
    }
  }

  Future<void> _handleSessionAck(WsSessionAck msg) async {
    final machineId = msg.machineId;
    final machineEphemeralPub = msg.machineEphemeralPub;
    final signature = msg.signature;
    if (machineId.isEmpty || machineEphemeralPub.isEmpty || signature.isEmpty) {
      _sessions.failSession(machineId, 'invalid session-ack');
      return;
    }
    final masterKey = _masterKey;
    final clientEphemeralKeyPair = _sessions.getClientEphemeralKeyPair(
      machineId,
    );
    final clientEphemeralPubB64 = _sessions.getClientEphemeralPub(machineId);
    if (masterKey == null ||
        clientEphemeralKeyPair == null ||
        clientEphemeralPubB64 == null) {
      _sessions.failSession(machineId, 'session state missing');
      return;
    }
    final sessionAckMessage =
        'muxagent-session-ack-v1|$machineId|$machineEphemeralPub';
    final verified = await _verifySignature(
      machineId,
      sessionAckMessage,
      signature,
    );
    if (!verified) {
      _sessions.failSession(machineId, 'invalid session-ack signature');
      return;
    }

    Uint8List remotePubBytes;
    try {
      remotePubBytes = base64Decode(machineEphemeralPub);
    } catch (_) {
      _sessions.failSession(machineId, 'invalid machine ephemeral pub');
      return;
    }
    if (remotePubBytes.length != 32) {
      _sessions.failSession(machineId, 'invalid machine ephemeral pub');
      return;
    }
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: clientEphemeralKeyPair,
      remotePublicKey: SimplePublicKey(
        remotePubBytes,
        type: KeyPairType.x25519,
      ),
    );
    final sharedBytes = await sharedSecret.extractBytes();
    final transcript = '$clientEphemeralPubB64|$machineEphemeralPub|$machineId';
    final sessionKey = await SessionCrypto.deriveSessionKey(
      Uint8List.fromList(sharedBytes),
      transcript,
    );
    _sessions.activateSession(
      machineId,
      SessionCrypto(machineId: machineId, key: sessionKey),
    );
    _sessions.completeSession(machineId);
  }

  Future<void> _handleResponse(WsEncryptedMessage msg) async {
    final machineId = msg.machineId;
    final msgId = msg.msgId;
    final nonce = msg.nonce;
    final ciphertext = msg.ciphertext;
    final session = _sessions.getSession(machineId);
    if (session == null) {
      return;
    }
    Uint8List plaintext;
    try {
      plaintext = await session.decrypt(
        WsMessageType.response.value,
        msgId,
        nonce,
        ciphertext,
      );
    } catch (_) {
      return;
    }
    final decoded = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    _sessions.resolvePendingRpc(machineId, msgId, decoded);
  }

  Future<void> _handleEvent(WsEncryptedMessage msg) async {
    final machineId = msg.machineId;
    final msgId = msg.msgId;
    final nonce = msg.nonce;
    final ciphertext = msg.ciphertext;
    final session = _sessions.getSession(machineId);
    if (session == null) {
      return;
    }
    Uint8List plaintext;
    try {
      plaintext = await session.decrypt(
        WsMessageType.event.value,
        msgId,
        nonce,
        ciphertext,
      );
    } catch (_) {
      return;
    }
    final decoded = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    _events.add(WsEvent(type: WsMessageType.event.value, payload: decoded));
  }

  Future<bool> _verifySignature(
    String machineId,
    String message,
    String signatureB64,
  ) async {
    final machine = _machines[machineId];
    if (machine == null) {
      return false;
    }
    Uint8List signatureBytes;
    Uint8List publicKeyBytes;
    try {
      signatureBytes = base64Decode(signatureB64);
      publicKeyBytes = base64Decode(machine.machineSignPubB64);
    } catch (_) {
      return false;
    }
    final signature = Signature(
      signatureBytes,
      publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
    );
    return _ed25519.verify(utf8.encode(message), signature: signature);
  }

  String _wsUrlFromHttp(String httpUrl) {
    final uri = Uri.parse(httpUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.port,
      path: '/ws',
    ).toString();
  }

  String _randomId() {
    final rand = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = rand.nextInt(256);
    }
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<void> _handleRpc(WsEncryptedMessage msg) async {
    final machineId = msg.machineId;
    final msgId = msg.msgId;
    final nonce = msg.nonce;
    final ciphertext = msg.ciphertext;
    final session = _sessions.getSession(machineId);
    if (session == null) {
      return;
    }
    Uint8List plaintext;
    try {
      plaintext = await session.decrypt(
        WsMessageType.rpc.value,
        msgId,
        nonce,
        ciphertext,
      );
    } catch (_) {
      return;
    }
    final decoded = WsRpcPayload.fromJson(
      jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>,
    );
    final method = decoded.method;
    final params = decoded.params ?? {};

    if (method == 'echo') {
      _events.add(WsEvent(type: 'echo', payload: params));
      await _sendResponse(machineId, msgId, params, null);
    } else {
      await _sendResponse(machineId, msgId, null, 'unknown method: $method');
    }
  }

  Future<void> _sendResponse(
    String machineId,
    String msgId,
    Map<String, dynamic>? result,
    String? error,
  ) async {
    final session = _sessions.getSession(machineId);
    if (session == null) {
      return;
    }
    final responsePayload = {'result': result, 'error': error ?? ''};
    final payloadBytes = utf8.encode(jsonEncode(responsePayload));
    final encrypted = await session.encrypt(
      WsMessageType.response.value,
      msgId,
      Uint8List.fromList(payloadBytes),
    );
    _ws.sendJson(
      WsEncryptedMessage(
        type: WsMessageType.response.value,
        machineId: machineId,
        msgId: msgId,
        nonce: encrypted.nonceB64,
        ciphertext: encrypted.ciphertextB64,
      ).toJson(),
    );
  }
}
