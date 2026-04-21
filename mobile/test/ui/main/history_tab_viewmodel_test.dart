import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/domain/session.dart';
import 'package:muxagent/ui/main/history_tab_viewmodel.dart';

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
  _FakeWsSessionRepository()
    : super(relay: _NoopRelayWsClient(), sessions: SessionManager());
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

AgentSession _buildSession(String id, String machineId) {
  final now = DateTime(2026, 4, 14, 12);
  return AgentSession(
    id: id,
    machineId: machineId,
    cwd: '~/project',
    title: 'Session $id',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('HistoryTabViewModel machine catalog', () {
    late _FakeWsSessionRepository wsRepo;
    late EventRepository eventRepo;
    late FakePairedMachineRepository machineRepo;
    late HistoryTabViewModel viewModel;

    setUp(() {
      registerTestTranslations();
      wsRepo = _FakeWsSessionRepository();
      eventRepo = EventRepository(wsRepo: wsRepo);
      eventRepo.sessions['session-1'] = _buildSession('session-1', 'machine-1');
      machineRepo = FakePairedMachineRepository([_buildMachine('machine-1')]);
      viewModel = HistoryTabViewModel(
        eventRepo: eventRepo,
        machineRepo: machineRepo,
      );
      viewModel.onInit();
    });

    tearDown(() {
      viewModel.onClose();
      eventRepo.dispose();
      machineRepo.dispose();
    });

    test('clears a stale machine filter when the machine disappears', () async {
      viewModel.setMachineFilter('machine-1');

      await machineRepo.removeMachine('machine-1');

      expect(viewModel.selectedMachineFilter.value, isNull);
      expect(viewModel.sessionGroups, isNotEmpty);
    });
  });
}
