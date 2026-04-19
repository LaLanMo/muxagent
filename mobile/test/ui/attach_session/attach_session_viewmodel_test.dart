import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:muxagent/data/local/session_database.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/runtime_preference_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/models/acp_session_models.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/domain/runtime_option.dart';
import 'package:muxagent/domain/ui_effect.dart';
import 'package:muxagent/ui/attach_session/attach_session_viewmodel.dart';

import '../../support/fake_paired_machine_repository.dart';

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
  final ValueNotifier<Set<String>> _activeSessionIdsNotifier;
  final Set<String> _activeIds;
  final AppRuntimeListResponseDto runtimeListResponse;
  final AppSessionAttachResponseDto attachResponse;
  final List<String> attachCalls = [];
  final List<String> ensureConnectedCalls = [];
  final List<Object?> resetConnectionReasons = [];
  Completer<AppSessionAttachResponseDto>? attachCompleter;
  Object? attachError;

  _FakeWsSessionRepository({
    required Set<String> initialActiveIds,
    required this.runtimeListResponse,
    required this.attachResponse,
  }) : _activeIds = {...initialActiveIds},
       _activeSessionIdsNotifier = ValueNotifier(
         Set.unmodifiable({...initialActiveIds}),
       ),
       super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  Set<String> get activeSessionIds => Set.unmodifiable(_activeIds);

  @override
  ValueListenable<Set<String>> get activeSessionIdsListenable =>
      _activeSessionIdsNotifier;

  @override
  bool hasSession(String machineId) => _activeIds.contains(machineId);

  @override
  RxBool get relayConnected => relayConnectedValue;

  @override
  Rx<ConnState> get connectionState => connectionStateValue;

  @override
  Future<void> ensureConnected({required String relayHttpUrl}) async {
    ensureConnectedCalls.add(relayHttpUrl);
  }

  @override
  Future<void> startSession({required PairedMachine machine}) async {
    _activeIds.add(machine.machineId);
    _activeSessionIdsNotifier.value = Set.unmodifiable(_activeIds);
  }

  @override
  Future<AppRuntimeListResponseDto> listRuntimes({
    required String machineId,
  }) async {
    return runtimeListResponse;
  }

  @override
  Future<AppSessionAttachResponseDto> attachSession({
    required String machineId,
    required String sessionId,
    required String runtime,
  }) async {
    attachCalls.add('$machineId:$sessionId:$runtime');
    if (attachError != null) {
      throw attachError!;
    }
    if (attachCompleter != null) {
      return attachCompleter!.future;
    }
    return attachResponse;
  }

  @override
  Future<void> resetConnection({Object? reason}) async {
    resetConnectionReasons.add(reason);
  }

  void dispose() {
    _activeSessionIdsNotifier.dispose();
  }
}

PairedMachine buildMachine(String id, {String? hostname}) {
  return PairedMachine(
    machineId: id,
    relayHttpUrl: 'https://relay.test',
    machineSignPubB64: 'sign-$id',
    machineEncPubB64: 'enc-$id',
    hostname: hostname ?? id,
  );
}

RuntimeOption buildRuntime() {
  return const RuntimeOption(
    id: 'claude-code',
    label: 'Claude Code',
    ready: true,
    defaultModeId: 'default',
    modeOptions: [],
  );
}

ShowToast? _currentToast(_TestAttachSessionViewModel viewModel) {
  final effect = viewModel.uiEffect.value;
  return effect is ShowToast ? effect : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AttachSessionViewModel', () {
    late String dbPath;
    late _FakeWsSessionRepository wsRepo;
    late FakePairedMachineRepository machineRepo;
    late EventRepository eventRepo;
    late _TestAttachSessionViewModel viewModel;

    setUp(() async {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({});
      dbPath = p.join(
        Directory.systemTemp.path,
        'muxagent-attach-session-vm-test.db',
      );
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await SessionDatabase.resetForTest(databasePathOverride: dbPath);

      wsRepo = _FakeWsSessionRepository(
        initialActiveIds: const {'machine-1'},
        runtimeListResponse: const AppRuntimeListResponseDto(
          runtimes: [
            AppRuntimeInfoDto(
              id: 'claude-code',
              label: 'Claude Code',
              ready: true,
            ),
          ],
        ),
        attachResponse: AppSessionAttachResponseDto(
          ok: true,
          sessionId: 'session-123',
          runtime: 'claude-code',
          cwd: '/workspace',
          title: 'Attached title',
          status: 'idle',
          createdAt: DateTime.parse('2026-04-19T12:00:00Z'),
          updatedAt: DateTime.parse('2026-04-19T12:05:00Z'),
        ),
      );
      machineRepo = FakePairedMachineRepository([buildMachine('machine-1')]);
      eventRepo = EventRepository(wsRepo: wsRepo);
      viewModel = _TestAttachSessionViewModel(
        machineRepo: machineRepo,
        wsRepo: wsRepo,
        eventRepo: eventRepo,
        runtimePrefs: RuntimePreferenceRepository(),
      );
    });

    tearDown(() async {
      viewModel.onClose();
      eventRepo.dispose();
      machineRepo.dispose();
      wsRepo.dispose();
      await SessionDatabase.resetForTest();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      Get.reset();
    });

    test('attaches and navigates to chat as an existing session', () async {
      viewModel.onInit();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      viewModel.sessionIdController.text = 'session-123';
      viewModel.selectedMachine.value = buildMachine('machine-1');
      viewModel.selectedRuntime.value = buildRuntime();

      await viewModel.attachSession();

      expect(wsRepo.attachCalls, ['machine-1:session-123:claude-code']);
      final session = eventRepo.sessionById('session-123');
      expect(session, isNotNull);
      expect(session?.cwd, '/workspace');
      expect(viewModel.lastNavigation, {
        'sessionId': 'session-123',
        'machineId': 'machine-1',
        'runtime': 'claude-code',
        'cwd': '/workspace',
        'sessionTitle': 'Attached title',
        'isNewSession': false,
      });
    });

    test('validates required fields before attaching', () async {
      await viewModel.attachSession();
      expect(_currentToast(viewModel)?.message, 'Session ID is required');
      expect(wsRepo.attachCalls, isEmpty);
      expect(viewModel.isLoading.value, isFalse);

      viewModel.sessionIdController.text = 'session-123';
      await viewModel.attachSession();
      expect(_currentToast(viewModel)?.message, 'Please select a machine');
      expect(wsRepo.attachCalls, isEmpty);

      viewModel.selectedMachine.value = buildMachine('machine-1');
      await viewModel.attachSession();
      expect(_currentToast(viewModel)?.message, 'Please select a runtime');
      expect(wsRepo.attachCalls, isEmpty);
      expect(viewModel.isLoading.value, isFalse);
    });

    test(
      'sets loading while attach is in flight and clears it on success',
      () async {
        final completer = Completer<AppSessionAttachResponseDto>();
        wsRepo.attachCompleter = completer;
        viewModel.sessionIdController.text = 'session-123';
        viewModel.selectedMachine.value = buildMachine('machine-1');
        viewModel.selectedRuntime.value = buildRuntime();

        final future = viewModel.attachSession();
        await Future<void>.delayed(Duration.zero);

        expect(viewModel.isLoading.value, isTrue);
        expect(wsRepo.attachCalls, ['machine-1:session-123:claude-code']);

        completer.complete(wsRepo.attachResponse);
        await future;

        expect(viewModel.isLoading.value, isFalse);
        expect(viewModel.lastNavigation?['sessionId'], 'session-123');
      },
    );

    test('clears loading and reports attach errors', () async {
      wsRepo.attachError = Exception('attach failed');
      viewModel.sessionIdController.text = 'session-123';
      viewModel.selectedMachine.value = buildMachine('machine-1');
      viewModel.selectedRuntime.value = buildRuntime();

      await viewModel.attachSession();

      expect(viewModel.isLoading.value, isFalse);
      expect(wsRepo.attachCalls, ['machine-1:session-123:claude-code']);
      expect(_currentToast(viewModel)?.message, 'Exception: attach failed');
      expect(viewModel.lastNavigation, isNull);
    });
  });
}

class _TestAttachSessionViewModel extends AttachSessionViewModel {
  Map<String, dynamic>? lastNavigation;

  _TestAttachSessionViewModel({
    required super.machineRepo,
    required super.wsRepo,
    required super.eventRepo,
    required super.runtimePrefs,
  });

  @override
  void navigateToChat({
    required String sessionId,
    required String machineId,
    required String runtime,
    required String cwd,
    required String sessionTitle,
  }) {
    lastNavigation = {
      'sessionId': sessionId,
      'machineId': machineId,
      'runtime': runtime,
      'cwd': cwd,
      'sessionTitle': sessionTitle,
      'isNewSession': false,
    };
  }
}
