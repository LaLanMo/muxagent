enum WsMessageType {
  register('register'),
  challenge('challenge'),
  challengeResponse('challengeResponse'),
  registered('registered'),
  sessionInit('session-init'),
  sessionAck('session-ack'),
  sessionEnd('session-end'),
  rpc('rpc'),
  response('response'),
  event('event'),
  error('error');

  const WsMessageType(this.value);
  final String value;

  static WsMessageType? fromValue(String? raw) {
    if (raw == null) return null;
    for (final type in WsMessageType.values) {
      if (type.value == raw) return type;
    }
    return null;
  }
}

enum WsRole {
  client('client'),
  machine('machine');

  const WsRole(this.value);
  final String value;
}
