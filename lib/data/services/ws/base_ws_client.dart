import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef WsMessageHandler = void Function(String raw);
typedef WsErrorHandler = void Function(Object error);
typedef WsDoneHandler = void Function();

/// Lightweight WebSocket wrapper used by higher-level clients.
class BaseWsClient {
  WebSocket? _socket;
  StreamSubscription? _subscription;

  bool get isConnected => _socket != null;

  Future<void> connect(
    String url, {
    required WsMessageHandler onMessage,
    WsErrorHandler? onError,
    WsDoneHandler? onDone,
  }) async {
    if (_socket != null) {
      return;
    }
    final socket = await WebSocket.connect(url);
    _socket = socket;
    _subscription = socket.listen(
      (data) {
        if (data is String) {
          onMessage(data);
        }
      },
      onError: (error) {
        _clearConnection();
        onError?.call(error);
      },
      onDone: () {
        _clearConnection();
        onDone?.call();
      },
    );
  }

  void sendJson(Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null) {
      throw Exception('socket not connected');
    }
    socket.add(jsonEncode(payload));
  }

  void sendRaw(String payload) {
    final socket = _socket;
    if (socket == null) {
      throw Exception('socket not connected');
    }
    socket.add(payload);
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _socket?.close();
    _clearConnection();
  }

  void _clearConnection() {
    _subscription = null;
    _socket = null;
  }
}
