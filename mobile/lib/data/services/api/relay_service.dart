import 'base_api_client.dart';
import 'models/auth_status_response.dart';

export 'models/auth_status_response.dart';

/// Service for communicating with the relay server
class RelayService {
  final BaseApiClient _client;

  RelayService({BaseApiClient? client}) : _client = client ?? BaseApiClient();

  /// Get auth request status
  Future<AuthStatusResponse> getAuthStatus(
    String relayUrl,
    String requestId,
  ) async {
    final uri = Uri.parse(relayUrl);
    _client.updateEndpoint(
      host: uri.host,
      port: uri.port,
      scheme: uri.scheme,
    );
    return _client.sendRequest<AuthStatusResponse>(
      path: '/v1/auth/$requestId',
      method: 'GET',
      fromJson: AuthStatusResponse.fromJson,
    );
  }

  /// Approve auth request
  Future<void> approveAuthRequest(
    String relayUrl,
    String requestId, {
    required String masterId,
    required String masterSignPub,
    required String masterEncPub,
    required String approvalSignature,
    Map<String, dynamic>? keyringUpdate,
  }) async {
    final uri = Uri.parse(relayUrl);
    _client.updateEndpoint(
      host: uri.host,
      port: uri.port,
      scheme: uri.scheme,
    );
    await _client.sendRequest<void>(
      path: '/v1/auth/$requestId/approve',
      method: 'POST',
      fromJson: (_) {},
      jsonBody: {
        'master_id': masterId,
        'master_sign_pub': masterSignPub,
        'master_enc_pub': masterEncPub,
        'approval_signature': approvalSignature,
        if (keyringUpdate != null) 'keyring_update': keyringUpdate,
      },
    );
  }

  /// Register FCM device token with relay for push notifications
  Future<void> registerDeviceToken(
    String relayUrl,
    String connectToken,
    String fcmToken,
    String platform,
  ) async {
    final uri = Uri.parse(relayUrl);
    _client.updateEndpoint(
      host: uri.host,
      port: uri.port,
      scheme: uri.scheme,
    );
    await _client.sendRequest<void>(
      path: '/v1/device/token',
      method: 'PUT',
      fromJson: (_) {},
      jsonBody: {
        'connect_token': connectToken,
        'fcm_token': fcmToken,
        'platform': platform,
      },
    );
  }

  /// Unregister FCM device token from relay
  Future<void> unregisterDeviceToken(
    String relayUrl,
    String connectToken,
    String fcmToken,
  ) async {
    final uri = Uri.parse(relayUrl);
    _client.updateEndpoint(
      host: uri.host,
      port: uri.port,
      scheme: uri.scheme,
    );
    await _client.sendRequest<void>(
      path: '/v1/device/token',
      method: 'DELETE',
      fromJson: (_) {},
      jsonBody: {
        'connect_token': connectToken,
        'fcm_token': fcmToken,
      },
    );
  }

  void dispose() => _client.dispose();
}
