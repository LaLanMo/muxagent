import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../domain/stt_config.dart';
import '../../../domain/stt_result.dart';

class SttService {
  Future<SttResult> transcribe(
    SttConfig config,
    Uint8List audioData,
    String mimeType,
  ) async {
    final stopwatch = Stopwatch()..start();

    final ext = _extensionForMime(mimeType);
    final uri = Uri.parse(config.endpoint);

    debugPrint('[STT] endpoint: $uri');
    debugPrint('[STT] model: ${config.model}');
    debugPrint('[STT] audioData: ${audioData.length} bytes, mimeType: $mimeType, ext: $ext');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${config.apiKey}'
      ..fields['model'] = config.model
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        audioData,
        filename: 'audio.$ext',
        contentType: MediaType.parse(mimeType),
      ));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    stopwatch.stop();

    debugPrint('[STT] response: ${streamed.statusCode} $body');

    if (streamed.statusCode != 200) {
      throw Exception(
        'STT API error ${streamed.statusCode}: $body',
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final text = json['text'] as String? ?? '';

    return SttResult(text: text, duration: stopwatch.elapsed);
  }

  String _extensionForMime(String mimeType) {
    switch (mimeType) {
      case 'audio/mp4':
      case 'audio/m4a':
      case 'audio/x-m4a':
        return 'm4a';
      case 'audio/wav':
      case 'audio/x-wav':
        return 'wav';
      case 'audio/webm':
        return 'webm';
      case 'audio/mpeg':
        return 'mp3';
      default:
        return 'm4a';
    }
  }
}
