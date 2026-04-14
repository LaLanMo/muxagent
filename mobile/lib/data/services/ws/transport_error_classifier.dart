bool isRelaySocketError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('socket closed') ||
      message.contains('socket not connected') ||
      message.contains('connection reset') ||
      message.contains('stale relay socket');
}

bool isRecoverableSessionTransportError(Object error) {
  final message = error.toString().toLowerCase();
  return isRelaySocketError(error) ||
      message.contains('rpc timeout') ||
      message.contains('no active session') ||
      message.contains('machine offline') ||
      message.contains('session ended') ||
      message.contains('broken pipe') ||
      message.contains('transport stopped') ||
      message.contains('process exited');
}
