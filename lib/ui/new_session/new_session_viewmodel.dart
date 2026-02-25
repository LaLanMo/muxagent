import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../domain/enums.dart';
import '../../domain/paired_machine.dart';
import '../../domain/session.dart';
import '../../routing/routes.dart';

class NewSessionViewModel extends GetxController {
  final PairedMachineRepository _machineRepo =
      Get.find<PairedMachineRepository>();
  final WsSessionRepository _wsRepo = Get.find<WsSessionRepository>();
  final EventRepository _eventRepo = Get.find<EventRepository>();

  final machines = <PairedMachine>[].obs;
  final selectedMachine = Rxn<PairedMachine>();
  final isLoading = false.obs;

  final cwdController = TextEditingController();
  final promptController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _loadMachines();
  }

  @override
  void onClose() {
    cwdController.dispose();
    promptController.dispose();
    super.onClose();
  }

  Future<void> _loadMachines() async {
    final list = await _machineRepo.listMachines();
    machines.value = list;

    // Auto-select first machine if only one
    if (list.length == 1) {
      selectedMachine.value = list.first;
    }
  }

  void selectMachine(PairedMachine machine) {
    selectedMachine.value = machine;
  }

  Future<void> startSession() async {
    final machine = selectedMachine.value;
    if (machine == null) return;

    isLoading.value = true;

    try {
      // Ensure connected
      await _wsRepo.ensureConnected(relayHttpUrl: machine.relayHttpUrl);
      if (!_wsRepo.hasSession(machine.machineId)) {
        await _wsRepo.startSession(machine: machine);
      }

      // Create session via RPC
      final cwd = cwdController.text.trim();
      final createParams = <String, dynamic>{};
      if (cwd.isNotEmpty) {
        createParams['cwd'] = cwd;
      }

      final createResult = await _wsRepo.callRpc(
        machineId: machine.machineId,
        method: 'session.create',
        params: createParams,
      );

      final sessionId = createResult['result']?['sessionId'] as String?;
      if (sessionId == null || sessionId.isEmpty) {
        throw Exception('Failed to create session: no sessionId returned');
      }

      // Register session in EventRepository
      _eventRepo.registerSession(AgentSession(
        id: sessionId,
        title: '',
        status: SessionStatus.idle,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {'machineId': machine.machineId},
      ));

      // Send initial prompt if provided
      final prompt = promptController.text.trim();
      if (prompt.isNotEmpty) {
        await _wsRepo.callRpc(
          machineId: machine.machineId,
          method: 'session.prompt',
          params: {
            'sessionId': sessionId,
            'text': prompt,
          },
        );
      }

      // Navigate to chat
      Get.offNamed(Routes.chat, arguments: {
        'sessionId': sessionId,
        'machineId': machine.machineId,
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
