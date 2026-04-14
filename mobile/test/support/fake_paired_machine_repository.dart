import 'package:flutter/foundation.dart';
import 'package:muxagent/data/repositories/paired_machine_repository.dart';
import 'package:muxagent/domain/paired_machine.dart';

class FakePairedMachineRepository extends PairedMachineRepository {
  final ValueNotifier<List<PairedMachine>> _machinesNotifier;

  FakePairedMachineRepository([
    Iterable<PairedMachine> initialMachines = const [],
  ]) : _machinesNotifier = ValueNotifier(
         List<PairedMachine>.unmodifiable(initialMachines.toList()),
       );

  @override
  ValueListenable<List<PairedMachine>> get machinesListenable =>
      _machinesNotifier;

  @override
  List<PairedMachine> get machines => _machinesNotifier.value;

  @override
  Future<void> refresh() async {}

  @override
  Future<List<PairedMachine>> listMachines() async => machines;

  @override
  Future<PairedMachine?> getMachine(String machineId) async {
    for (final machine in machines) {
      if (machine.machineId == machineId) {
        return machine;
      }
    }
    return null;
  }

  @override
  Future<void> saveMachine(PairedMachine machine) async {
    setMachines([
      for (final existing in machines)
        if (existing.machineId != machine.machineId) existing,
      machine,
    ]);
  }

  @override
  Future<void> removeMachine(String machineId) async {
    setMachines(
      machines.where((machine) => machine.machineId != machineId),
    );
  }

  void setMachines(Iterable<PairedMachine> nextMachines) {
    _machinesNotifier.value = List<PairedMachine>.unmodifiable(
      nextMachines.toList(),
    );
  }

  void dispose() {
    _machinesNotifier.dispose();
  }
}
