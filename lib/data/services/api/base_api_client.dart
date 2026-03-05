import 'dart:convert';

import 'package:http/http.dart' as http;

/// Exception thrown when API requests fail
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() =>
      'ApiException: $message (status: $statusCode, body: $body)';
}

/// Base API client for making HTTP requests
class BaseApiClient {
  final http.Client _client;

  String _scheme = 'https';
  String _host = '';
  int? _port;

  BaseApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Update the endpoint configuration at runtime
  void updateEndpoint({
    required String host,
    int? port,
    String scheme = 'https',
  }) {
    _scheme = scheme;
    _host = host;
    _port = port;
  }

  /// Build a URI from the current endpoint configuration
  Uri _buildUri(String path, Map<String, String>? queryParams) {
    return Uri(
      scheme: _scheme,
      host: _host,
      port: _port,
      path: path,
      queryParameters: queryParams?.isNotEmpty == true ? queryParams : null,
    );
  }

  /// Send an HTTP request and deserialize the response
  ///
  /// [path] - The API endpoint path
  /// [method] - HTTP method (GET, POST, etc.)
  /// [fromJson] - Function to deserialize the JSON response
  /// [queryParams] - Optional query parameters
  /// [jsonBody] - Optional JSON body for POST/PUT requests
  Future<T> sendRequest<T>({
    required String path,
    required String method,
    required T Function(Map<String, dynamic>) fromJson,
    Map<String, String>? queryParams,
    Map<String, dynamic>? jsonBody,
  }) async {
    final uri = _buildUri(path, queryParams);

    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await _client.get(uri);
        break;
      case 'POST':
        response = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonBody != null ? jsonEncode(jsonBody) : null,
        );
        break;
      default:
        throw ApiException('Unsupported HTTP method: $method');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Try to extract the error message from the JSON envelope.
      var msg = 'Request failed (${response.statusCode})';
      if (response.body.isNotEmpty) {
        try {
          final errJson =
              jsonDecode(response.body) as Map<String, dynamic>;
          final serverMsg = errJson['message'] as String?;
          if (serverMsg != null && serverMsg.isNotEmpty) {
            msg = serverMsg;
          }
        } catch (_) {}
      }
      throw ApiException(
        msg,
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    // Handle void responses (empty body or no content expected)
    if (response.body.isEmpty) {
      return fromJson({});
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final code = json['code'] as int?;
      final message = json['message'] as String?;

      if (code != null && code != 0) {
        throw ApiException(
          message ?? 'Business error',
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      final data = json['data'] as Map<String, dynamic>? ?? {};
      return fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'Failed to parse response: $e',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  /// Clean up resources
  void dispose() {
    _client.close();
  }
}
