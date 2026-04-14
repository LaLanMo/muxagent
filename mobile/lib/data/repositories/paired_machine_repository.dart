import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/paired_machine_storage_dto.dart';
import '../../domain/paired_machine.dart';

class PairedMachineRepository {
  static const _storageKey = 'paired_machines';

  Future<List<PairedMachine>> listMachines() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map>()
        .map(
          (entry) => PairedMachineStorageDto.fromJson(
            entry.cast<String, dynamic>(),
          ).toDomain(),
        )
        .toList();
  }

  Future<PairedMachine?> getMachine(String machineId) async {
    final machines = await listMachines();
    for (final machine in machines) {
      if (machine.machineId == machineId) {
        return machine;
      }
    }
    return null;
  }

  Future<void> saveMachine(PairedMachine machine) async {
    final prefs = await SharedPreferences.getInstance();
    final machines = await listMachines();
    final updated = <PairedMachine>[
      for (final existing in machines)
        if (existing.machineId != machine.machineId) existing,
      machine,
    ];
    final payload = jsonEncode(
      updated
          .map(PairedMachineStorageDto.fromDomain)
          .map((m) => m.toJson())
          .toList(),
    );
    await prefs.setString(_storageKey, payload);
  }

  Future<void> removeMachine(String machineId) async {
    final prefs = await SharedPreferences.getInstance();
    final machines = await listMachines();
    final updated = machines
        .where((machine) => machine.machineId != machineId)
        .toList();
    final payload = jsonEncode(
      updated
          .map(PairedMachineStorageDto.fromDomain)
          .map((m) => m.toJson())
          .toList(),
    );
    await prefs.setString(_storageKey, payload);
  }
}
