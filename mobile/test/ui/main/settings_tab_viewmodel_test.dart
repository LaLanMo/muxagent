import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/models/auth_request.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/domain/ui_effect.dart';
import 'package:muxagent/ui/main/settings_tab_viewmodel.dart';

import '../../support/fake_paired_machine_repository.dart';
import '../../support/localization_test_utils.dart';

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
  final ValueNotifier<Set<String>> _activeSessionIdsNotifier;
  Set<String> _activeIds = {};

  _FakeWsSessionRepository()
    : _activeSessionIdsNotifier = ValueNotifier(const <String>{}),
      super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  @override
  RxBool get relayConnected => relayConnectedValue;

  @override
  Set<String> get activeSessionIds => Set.unmodifiable(_activeIds);

  @override
  ValueListenable<Set<String>> get activeSessionIdsListenable =>
      _activeSessionIdsNotifier;

  void setActiveSessionIds(Set<String> ids) {
    _activeIds = {...ids};
    _activeSessionIdsNotifier.value = Set.unmodifiable(_activeIds);
  }

  void dispose() {
    _activeSessionIdsNotifier.dispose();
  }
}

class _FakeCryptoService extends CryptoService {
  _FakeCryptoService();

  @override
  Future<bool> hasMasterKey() async => true;
}

PairedMachine _buildMachine(String id) {
  return PairedMachine(
    machineId: id,
    relayHttpUrl: 'https://relay.test',
    machineSignPubB64: 'sign-$id',
    machineEncPubB64: 'enc-$id',
    hostname: 'host-$id',
  );
}

ReconnectRecoveryResult _buildRecoveryResult({
  required String machineId,
  required bool sessionReady,
}) {
  return ReconnectRecoveryResult(
    machineId: machineId,
    transcript: sessionReady
        ? TranscriptRecoveryState.complete
        : TranscriptRecoveryState.failed,
    metadata: sessionReady
        ? MetadataRecoveryState.complete
        : MetadataRecoveryState.skipped,
    sessionReady: sessionReady,
    statusesOk: sessionReady,
    knownSessionsOk: sessionReady,
    approvalsOk: sessionReady,
  );
}

void main() {
  group('SettingsTabViewModel machine status', () {
    late FakePairedMachineRepository machineRepo;
    late _FakeWsSessionRepository wsRepo;
    late SettingsTabViewModel viewModel;
    var connectCalls = 0;

    setUp(() {
      registerTestTranslations();
      machineRepo = FakePairedMachineRepository([_buildMachine('machine-1')]);
      wsRepo = _FakeWsSessionRepository();
      connectCalls = 0;
      viewModel = SettingsTabViewModel(
        crypto: _FakeCryptoService(),
        machineRepo: machineRepo,
        wsRepo: wsRepo,
        connectMachine: (machine) async {
          connectCalls += 1;
          return _buildRecoveryResult(
            machineId: machine.machineId,
            sessionReady: false,
          );
        },
        pairingLinkParser: const AuthRequestPairingLinkParser(),
      );
    });

    tearDown(() {
      machineRepo.dispose();
      wsRepo.dispose();
    });

    test('prefers online over connecting when a session is already active', () {
      wsRepo.setActiveSessionIds({'machine-1'});
      viewModel.connectingMachines.add('machine-1');

      expect(
        viewModel.machineConnectionState('machine-1'),
        MachineConnectionDisplayState.online,
      );
    });

    test(
      'reports serverLost when relay is disconnected and no session exists',
      () {
        wsRepo.relayConnected.value = false;

        expect(
          viewModel.machineConnectionState('machine-1'),
          MachineConnectionDisplayState.serverLost,
        );
      },
    );

    test(
      'does not enqueue a reconnect when the machine is already connected',
      () async {
        wsRepo.setActiveSessionIds({'machine-1'});

        await viewModel.connectMachine(machineRepo.machines.first);

        expect(connectCalls, 0);
        expect(viewModel.connectingMachines, isEmpty);
      },
    );

    test(
      'shows success when recovery reports the session ready before the mirror updates',
      () async {
        viewModel = SettingsTabViewModel(
          crypto: _FakeCryptoService(),
          machineRepo: machineRepo,
          wsRepo: wsRepo,
          connectMachine: (machine) async {
            connectCalls += 1;
            return _buildRecoveryResult(
              machineId: machine.machineId,
              sessionReady: true,
            );
          },
          pairingLinkParser: const AuthRequestPairingLinkParser(),
        );

        await viewModel.connectMachine(machineRepo.machines.first);

        expect(connectCalls, 1);
        expect(viewModel.uiEffect.value, isA<ShowToast>());
        expect(
          (viewModel.uiEffect.value as ShowToast).message,
          'Connected to host-machine-1',
        );
        expect(viewModel.connectingMachines, isEmpty);
      },
    );

    test(
      'shows failure when recovery completes without a ready session',
      () async {
        await viewModel.connectMachine(machineRepo.machines.first);

        expect(connectCalls, 1);
        expect(viewModel.uiEffect.value, isA<ShowToast>());
        expect(
          (viewModel.uiEffect.value as ShowToast).message,
          'Failed to connect',
        );
        expect(viewModel.connectingMachines, isEmpty);
      },
    );

    test('buildPasteUrlTextField disables IME helpers for auth URLs', () {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      final field = SettingsTabViewModel.buildPasteUrlTextField(
        controller: controller,
      );

      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.keyboardType, TextInputType.url);
      expect(field.textInputAction, TextInputAction.done);
      expect(field.textCapitalization, TextCapitalization.none);
      expect(field.smartDashesType, SmartDashesType.disabled);
      expect(field.smartQuotesType, SmartQuotesType.disabled);
      expect(field.spellCheckConfiguration, isNotNull);
    });
  });
}
