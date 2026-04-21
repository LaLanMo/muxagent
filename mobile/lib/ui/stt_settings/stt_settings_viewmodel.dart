import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:record/record.dart';

import '../../data/repositories/stt_repository.dart';
import '../../domain/stt_config.dart';
import '../../domain/stt_result.dart';
import '../../domain/ui_effect.dart';
import '../../i18n/tx.dart';
import '../../usecases/transcribe_audio.dart';

class SttSettingsViewModel extends GetxController {
  final SttRepository _repo;
  final TranscribeAudioUseCase _transcribe;

  SttSettingsViewModel({
    required SttRepository repo,
    required TranscribeAudioUseCase transcribe,
  }) : _repo = repo,
       _transcribe = transcribe;

  final endpointController = TextEditingController();
  final apiKeyController = TextEditingController();
  final modelController = TextEditingController();

  final canTest = false.obs;
  final isTesting = false.obs;
  final isRecording = false.obs;
  final testResult = Rxn<SttResult>();
  final testError = RxnString();
  final uiEffect = Rxn<UiEffect>();

  AudioRecorder? _recorder;
  String? _tempPath;

  @override
  void onInit() {
    super.onInit();
    endpointController.addListener(_syncFormState);
    apiKeyController.addListener(_syncFormState);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _repo.loadConfig();
    if (config != null) {
      endpointController.text = config.endpoint;
      apiKeyController.text = config.apiKey;
      modelController.text = config.model;
    } else {
      modelController.text = 'whisper-1';
    }
    _syncFormState();
  }

  void _syncFormState() {
    canTest.value =
        endpointController.text.trim().isNotEmpty &&
        apiKeyController.text.trim().isNotEmpty;
  }

  Future<void> saveConfig() async {
    final endpoint = endpointController.text.trim();
    final apiKey = apiKeyController.text.trim();
    final model = modelController.text.trim();

    if (endpoint.isEmpty || apiKey.isEmpty) {
      uiEffect.value = ShowToast(Tx.sttEndpointApiKeyRequired.tr);
      return;
    }

    await _repo.saveConfig(
      SttConfig(
        endpoint: endpoint,
        apiKey: apiKey,
        model: model.isEmpty ? 'whisper-1' : model,
      ),
    );
    uiEffect.value = ShowToast(Tx.sttSettingsSaved.tr);
  }

  Future<void> startTestRecording() async {
    if (!canTest.value) {
      testResult.value = null;
      testError.value = Tx.sttEndpointApiKeyEnable.tr;
      return;
    }

    testResult.value = null;
    testError.value = null;

    _recorder = AudioRecorder();
    if (!await _recorder!.hasPermission()) {
      testError.value = Tx.sttMicPermissionDenied.tr;
      _recorder = null;
      return;
    }

    _tempPath =
        '${Directory.systemTemp.path}/stt_test_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _tempPath!,
      );
    } catch (e) {
      testError.value = Tx.sttStartRecordingFailedWith(e);
      await _recorder!.dispose();
      _recorder = null;
      return;
    }

    if (!await _recorder!.isRecording()) {
      testError.value = Tx.sttMicUnavailableSettings.tr;
      await _recorder!.dispose();
      _recorder = null;
      return;
    }

    isRecording.value = true;
  }

  Future<void> stopTestRecording() async {
    if (_recorder == null) return;

    final path = await _recorder!.stop();
    isRecording.value = false;
    await _recorder!.dispose();
    _recorder = null;

    if (path == null) {
      testError.value = Tx.sttRecordingNoAudio.tr;
      return;
    }

    final file = File(path);
    final size = await file.length();
    if (size < 100) {
      testError.value = Tx.sttNoAudioPermissionSettings.tr;
      try {
        await file.delete();
      } catch (_) {}
      return;
    }

    // Save config first so the use case can find it
    await saveConfig();
    await _runTest(path);
  }

  Future<void> _runTest(String filePath) async {
    isTesting.value = true;
    testResult.value = null;
    testError.value = null;

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final result = await _transcribe.call(bytes, 'audio/m4a');
      testResult.value = result;
    } catch (e) {
      testError.value = e.toString();
    } finally {
      isTesting.value = false;
      // Clean up temp file
      try {
        await File(filePath).delete();
      } catch (_) {}
    }
  }

  @override
  void onClose() {
    endpointController.dispose();
    apiKeyController.dispose();
    modelController.dispose();
    _recorder?.dispose();
    super.onClose();
  }
}
