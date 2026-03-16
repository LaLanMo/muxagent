import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/repositories/paired_machine_repository.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PairedMachineRepository', () {
    late PairedMachineRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = PairedMachineRepository();
    });

    test('returns an empty list when no machines are stored', () async {
      expect(await repository.listMachines(), isEmpty);
    });

    test('reads stored machines through the storage DTO boundary', () async {
      SharedPreferences.setMockInitialValues({
        'paired_machines': jsonEncode([
          {
            'machine_id': 'machine-1',
            'relay_http_url': 'https://relay.example',
            'machine_sign_pub': 'sign-pub',
            'machine_enc_pub': 'enc-pub',
            'hostname': 'devbox',
          },
        ]),
      });
      repository = PairedMachineRepository();

      final machines = await repository.listMachines();

      expect(machines, hasLength(1));
      expect(machines.single.machineId, 'machine-1');
      expect(machines.single.relayHttpUrl, 'https://relay.example');
      expect(machines.single.hostname, 'devbox');
    });

    test('saveMachine persists and replaces by machine id', () async {
      await repository.saveMachine(
        PairedMachine(
          machineId: 'machine-1',
          relayHttpUrl: 'https://relay-one.example',
          machineSignPubB64: 'sign-one',
          machineEncPubB64: 'enc-one',
          hostname: 'one',
        ),
      );
      await repository.saveMachine(
        PairedMachine(
          machineId: 'machine-1',
          relayHttpUrl: 'https://relay-two.example',
          machineSignPubB64: 'sign-two',
          machineEncPubB64: 'enc-two',
          hostname: 'two',
        ),
      );

      final machines = await repository.listMachines();

      expect(machines, hasLength(1));
      expect(machines.single.relayHttpUrl, 'https://relay-two.example');
      expect(machines.single.machineSignPubB64, 'sign-two');
      expect(machines.single.hostname, 'two');
    });

    test('removeMachine deletes only the matching machine id', () async {
      await repository.saveMachine(
        PairedMachine(
          machineId: 'machine-1',
          relayHttpUrl: 'https://relay-one.example',
          machineSignPubB64: 'sign-one',
          machineEncPubB64: 'enc-one',
        ),
      );
      await repository.saveMachine(
        PairedMachine(
          machineId: 'machine-2',
          relayHttpUrl: 'https://relay-two.example',
          machineSignPubB64: 'sign-two',
          machineEncPubB64: 'enc-two',
        ),
      );

      await repository.removeMachine('machine-1');

      final machines = await repository.listMachines();
      expect(machines.map((m) => m.machineId).toList(), ['machine-2']);
    });
  });
}
