import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/stt_repository.dart';
import 'package:muxagent/data/services/api/stt_service.dart';
import 'package:muxagent/domain/stt_config.dart';
import 'package:muxagent/ui/stt_settings/stt_settings_page.dart';
import 'package:muxagent/ui/stt_settings/stt_settings_viewmodel.dart';
import 'package:muxagent/usecases/transcribe_audio.dart';

import '../../support/localization_test_utils.dart';

class _NoopSttRepository extends SttRepository {
  _NoopSttRepository() : super(service: SttService());
}

class _TestSttSettingsViewModel extends SttSettingsViewModel {
  final SttConfig? initialConfig;

  _TestSttSettingsViewModel({this.initialConfig})
    : super(
        repo: _NoopSttRepository(),
        transcribe: TranscribeAudioUseCase(repo: _NoopSttRepository()),
      );

  @override
  // ignore: must_call_super
  void onInit() {
    endpointController.text = initialConfig?.endpoint ?? '';
    apiKeyController.text = initialConfig?.apiKey ?? '';
    modelController.text = initialConfig?.model ?? 'whisper-1';
    canTest.value =
        endpointController.text.trim().isNotEmpty &&
        apiKeyController.text.trim().isNotEmpty;
  }

  @override
  Future<void> saveConfig() async {}
}

void main() {
  setUp(() {
    registerTestTranslations();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('stt settings renders locked test state without config', (
    tester,
  ) async {
    Get.put<SttSettingsViewModel>(_TestSttSettingsViewModel());

    await tester.pumpWidget(localizedTestApp(child: const SttSettingsPage()));
    await tester.pump();

    expect(find.text('Speech to Text'), findsOneWidget);
    expect(find.text('ENDPOINT URL'), findsOneWidget);
    expect(find.text('API KEY'), findsOneWidget);
    expect(find.text('MODEL NAME'), findsOneWidget);
    expect(find.text('TEST'), findsOneWidget);
    expect(find.text('Add API key to enable'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('stt settings renders record action when config exists', (
    tester,
  ) async {
    Get.put<SttSettingsViewModel>(
      _TestSttSettingsViewModel(
        initialConfig: SttConfig(
          endpoint: 'https://api.example.com/v1/audio/transcriptions',
          apiKey: 'sk-test',
          model: 'whisper-1',
        ),
      ),
    );

    await tester.pumpWidget(localizedTestApp(child: const SttSettingsPage()));
    await tester.pump();

    expect(find.text('Stored securely in device Keychain'), findsOneWidget);
    expect(find.text('Record Test Clip'), findsOneWidget);
    expect(find.text('Add API key to enable'), findsNothing);
  });
}
