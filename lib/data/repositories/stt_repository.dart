import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/stt_config.dart';
import '../../domain/stt_result.dart';
import '../services/api/stt_service.dart';

class SttRepository {
  final SttService _service;
  final _secureStorage = const FlutterSecureStorage();

  static const _keyEndpoint = 'stt_endpoint';
  static const _keyModel = 'stt_model';
  static const _keyApiKey = 'stt_api_key';

  SttRepository({required SttService service}) : _service = service;

  Future<SttConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final endpoint = prefs.getString(_keyEndpoint);
    final model = prefs.getString(_keyModel);
    final apiKey = await _secureStorage.read(key: _keyApiKey);

    if (endpoint == null || endpoint.isEmpty ||
        apiKey == null || apiKey.isEmpty) {
      return null;
    }

    return SttConfig(
      endpoint: endpoint,
      apiKey: apiKey,
      model: model ?? 'whisper-1',
    );
  }

  Future<void> saveConfig(SttConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEndpoint, config.endpoint);
    await prefs.setString(_keyModel, config.model);
    await _secureStorage.write(key: _keyApiKey, value: config.apiKey);
  }

  Future<bool> hasConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final endpoint = prefs.getString(_keyEndpoint);
    final apiKey = await _secureStorage.read(key: _keyApiKey);
    return endpoint != null && endpoint.isNotEmpty &&
           apiKey != null && apiKey.isNotEmpty;
  }

  Future<SttResult> transcribe(Uint8List audioData, String mimeType) async {
    final config = await loadConfig();
    if (config == null) {
      throw Exception('Speech-to-text is not configured');
    }
    return _service.transcribe(config, audioData, mimeType);
  }
}
