import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/paired_machine_repository.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/stt_repository.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/api/stt_service.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/model_info.dart';
import 'package:muxagent/domain/usage_info.dart';
import 'package:muxagent/ui/chat/chat_viewmodel.dart';
import 'package:muxagent/ui/session_settings/session_settings_screen.dart';
import 'package:muxagent/usecases/transcribe_audio.dart';

class _NoopRelayWsClient extends RelayWsClient {
  _NoopRelayWsClient()
    : super(
        crypto: CryptoService(),
        tokens: TokenService(crypto: CryptoService()),
        sessions: SessionManager(),
      );
}

class _FakeWsSessionRepository extends WsSessionRepository {
  final relayConnectedValue = true.obs;
  final connectionStateValue = ConnState.connected.obs;

  _FakeWsSessionRepository()
    : super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  RxBool get relayConnected => relayConnectedValue;

  @override
  Rx<ConnState> get connectionState => connectionStateValue;
}

class _FakePairedMachineRepository extends PairedMachineRepository {}

class _TestChatViewModel extends ChatViewModel {
  final EventRepository eventRepo;
  UsageInfo? testUsage;

  _TestChatViewModel._({
    required super.wsRepo,
    required this.eventRepo,
    required super.recovery,
    required super.chatCacheRepo,
  }) : super(
         eventRepo: eventRepo,
         transcribe: TranscribeAudioUseCase(
           repo: SttRepository(service: SttService()),
         ),
       );

  factory _TestChatViewModel({required WsSessionRepository wsRepo}) {
    final eventRepo = EventRepository(wsRepo: wsRepo);
    final chatCacheRepo = SessionChatCacheRepository();
    final recovery = ReconnectRecoveryCoordinator(
      machines: _FakePairedMachineRepository(),
      wsRepo: wsRepo,
      eventRepo: eventRepo,
      chatCacheRepo: chatCacheRepo,
    );
    return _TestChatViewModel._(
      wsRepo: wsRepo,
      eventRepo: eventRepo,
      recovery: recovery,
      chatCacheRepo: chatCacheRepo,
    );
  }

  @override
  // ignore: must_call_super
  void onInit() {
    sessionId = 'session-1';
  }

  @override
  UsageInfo? get usageInfo => testUsage;

  @override
  Future<void> changeModel(String value) async {
    currentModel.value = value;
  }
}

UsageInfo _usage() {
  final usage = UsageInfo()
    ..costAmount = 0.128
    ..totalTokens = 12450
    ..inputTokens = 8200
    ..outputTokens = 1850
    ..cachedReadTokens = 2100
    ..cachedWriteTokens = 300
    ..contextUsed = 89000
    ..contextSize = 200000;
  return usage;
}

void main() {
  group('SessionSettingsScreen', () {
    late _FakeWsSessionRepository wsRepo;
    late _TestChatViewModel chatVm;

    setUp(() {
      Get.testMode = true;
      wsRepo = _FakeWsSessionRepository();
      chatVm = _TestChatViewModel(wsRepo: wsRepo);
      Get.put<ChatViewModel>(chatVm);
    });

    tearDown(() {
      chatVm.eventRepo.dispose();
      Get.reset();
    });

    testWidgets('renders the v2 sections and usage values', (tester) async {
      chatVm.availableModels.value = const [
        ModelInfo(
          value: 'default',
          name: 'Default (recommended)',
          description: 'Opus 4.6 · Most capable for complex work',
        ),
        ModelInfo(
          value: 'sonnet',
          name: 'Sonnet',
          description: 'Sonnet 4.6 · Best for everyday tasks',
        ),
        ModelInfo(
          value: 'opus',
          name: 'Opus',
          description: 'Custom model',
        ),
      ];
      chatVm.currentModel.value = 'opus';
      chatVm.testUsage = _usage();
      chatVm.usageVersion.value = 1;

      await tester.pumpWidget(
        const GetMaterialApp(home: SessionSettingsScreen()),
      );
      await tester.pump();

      expect(find.text('MODEL'), findsOneWidget);
      expect(find.text('COST & TOKENS'), findsOneWidget);
      expect(find.text('Default (recommended)'), findsOneWidget);
      expect(find.text('Sonnet'), findsOneWidget);
      expect(find.text('Opus'), findsOneWidget);
      expect(find.text('\$0.128'), findsOneWidget);
      expect(find.text('12,450'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('CONTEXT WINDOW'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      expect(find.text('CONTEXT WINDOW'), findsOneWidget);
      expect(find.text('89,000 / 200,000'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);

      await tester.tap(find.text('Sonnet'));
      await tester.pump();

      expect(chatVm.currentModel.value, 'sonnet');
    });

    testWidgets('shows the empty model fallback', (tester) async {
      chatVm.testUsage = _usage();
      chatVm.usageVersion.value = 1;

      await tester.pumpWidget(
        const GetMaterialApp(home: SessionSettingsScreen()),
      );
      await tester.pump();

      expect(find.text('No model options available'), findsOneWidget);
    });
  });
}
