import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/paired_machine_storage_dto.dart';
import '../../domain/paired_machine.dart';

class PairedMachineRepository {
  static const _storageKey = 'paired_machines';

  final ValueNotifier<List<PairedMachine>> _machinesNotifier = ValueNotifier(
    const <PairedMachine>[],
  );
  bool _loaded = false;
  Future<void>? _refreshing;

  ValueListenable<List<PairedMachine>> get machinesListenable =>
      _machinesNotifier;
  List<PairedMachine> get machines => _machinesNotifier.value;

  Future<void> refresh() async {
    if (_refreshing != null) {
      await _refreshing;
      return;
    }
    final refresh = _loadFromStorage();
    _refreshing = refresh;
    try {
      await refresh;
    } finally {
      _refreshing = null;
    }
  }

  Future<List<PairedMachine>> listMachines() async {
    await _ensureLoaded();
    return machines;
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
    await _ensureLoaded();
    final updated = <PairedMachine>[
      for (final existing in machines)
        if (existing.machineId != machine.machineId) existing,
      machine,
    ];
    await _persistMachines(updated);
  }

  Future<void> removeMachine(String machineId) async {
    await _ensureLoaded();
    final updated = machines
        .where((machine) => machine.machineId != machineId)
        .toList();
    await _persistMachines(updated);
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await refresh();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _setMachines(_decodeMachines(prefs.getString(_storageKey)));
  }

  Future<void> _persistMachines(List<PairedMachine> nextMachines) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      nextMachines
          .map(PairedMachineStorageDto.fromDomain)
          .map((m) => m.toJson())
          .toList(),
    );
    await prefs.setString(_storageKey, payload);
    _setMachines(nextMachines);
  }

  List<PairedMachine> _decodeMachines(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map(
          (entry) => PairedMachineStorageDto.fromJson(
            entry.cast<String, dynamic>(),
          ).toDomain(),
        )
        .toList(growable: false);
  }

  void _setMachines(List<PairedMachine> nextMachines) {
    _loaded = true;
    _machinesNotifier.value = List<PairedMachine>.unmodifiable(nextMachines);
  }
}
