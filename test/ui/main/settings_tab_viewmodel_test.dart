import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/ui/main/settings_tab_viewmodel.dart';

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

void main() {
  group('SettingsTabViewModel machine status', () {
    late RxList<PairedMachine> machines;
    late RxSet<String> activeSessionIds;
    late RxBool relayConnected;
    late SettingsTabViewModel viewModel;
    var connectCalls = 0;

    setUp(() {
      Get.testMode = true;
      machines = <PairedMachine>[_buildMachine('machine-1')].obs;
      activeSessionIds = <String>{}.obs;
      relayConnected = true.obs;
      connectCalls = 0;
      viewModel = SettingsTabViewModel(
        crypto: _FakeCryptoService(),
        machines: machines,
        activeSessionIds: activeSessionIds,
        relayConnected: relayConnected,
        connectMachine: (_) async {
          connectCalls += 1;
        },
      );
    });

    test('prefers online over connecting when a session is already active', () {
      activeSessionIds.add('machine-1');
      viewModel.connectingMachines.add('machine-1');

      expect(
        viewModel.machineConnectionState('machine-1'),
        MachineConnectionDisplayState.online,
      );
    });

    test(
      'reports serverLost when relay is disconnected and no session exists',
      () {
        relayConnected.value = false;

        expect(
          viewModel.machineConnectionState('machine-1'),
          MachineConnectionDisplayState.serverLost,
        );
      },
    );

    test(
      'does not enqueue a reconnect when the machine is already connected',
      () async {
        activeSessionIds.add('machine-1');

        await viewModel.connectMachine(machines.first);

        expect(connectCalls, 0);
        expect(viewModel.connectingMachines, isEmpty);
      },
    );
  });
}
