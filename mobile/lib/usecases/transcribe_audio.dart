import 'dart:typed_data';

import 'package:get/get.dart';

import '../data/repositories/stt_repository.dart';
import '../domain/stt_result.dart';
import '../i18n/tx.dart';

class TranscribeAudioUseCase {
  final SttRepository _repo;

  TranscribeAudioUseCase({required SttRepository repo}) : _repo = repo;

  Future<bool> hasConfig() => _repo.hasConfig();

  /// Transcribes audio data via the configured STT API.
  /// Throws if not configured or API fails.
  Future<SttResult> call(Uint8List audioData, String mimeType) async {
    final hasConfig = await _repo.hasConfig();
    if (!hasConfig) {
      throw Exception(Tx.sttNotConfigured.tr);
    }
    return _repo.transcribe(audioData, mimeType);
  }
}
