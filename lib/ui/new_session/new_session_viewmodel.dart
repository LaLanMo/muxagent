import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/local/session_database.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../domain/enums.dart';
import '../../domain/paired_machine.dart';
import '../../domain/permission_mode.dart';
import '../../domain/session.dart';
import '../../domain/ui_effect.dart';
import '../../routing/routes.dart';

class NewSessionViewModel extends GetxController {
  final PairedMachineRepository _machineRepo;
  final WsSessionRepository _wsRepo;
  final EventRepository _eventRepo;

  NewSessionViewModel({
    required PairedMachineRepository machineRepo,
    required WsSessionRepository wsRepo,
    required EventRepository eventRepo,
  })  : _machineRepo = machineRepo,
        _wsRepo = wsRepo,
        _eventRepo = eventRepo;

  final machines = <PairedMachine>[].obs;
  final selectedMachine = Rxn<PairedMachine>();
  final isLoading = false.obs;
  final activeSessionIds = <String>{}.obs;
  final uiEffect = Rxn<UiEffect>();
  final selectedMode = PermissionMode.bypassPermissions.obs;

  final cwdController = TextEditingController();
  final promptController = TextEditingController();

  final recentCwds = <RecentCwd>[].obs;
  final filteredCwds = <RecentCwd>[].obs;
  final isCwdDropdownOpen = false.obs;
  final cwdFocusNode = FocusNode();

  StreamSubscription<Set<String>>? _sessionSub;

  @override
  void onInit() {
    super.onInit();
    _subscribeToActiveSessions();
    _loadMachines();

    cwdFocusNode.addListener(() {
      if (cwdFocusNode.hasFocus) {
        if (filteredCwds.isNotEmpty) {
          isCwdDropdownOpen.value = true;
        }
      } else {
        // Delay so tap on dropdown row registers before closing
        Future.delayed(const Duration(milliseconds: 150), () {
          isCwdDropdownOpen.value = false;
        });
      }
    });

    cwdController.addListener(_filterCwds);

    ever(selectedMachine, (_) => _loadRecentCwds());
  }

  @override
  void onClose() {
    _sessionSub?.cancel();
    cwdFocusNode.dispose();
    cwdController.dispose();
    promptController.dispose();
    super.onClose();
  }

  void _subscribeToActiveSessions() {
    activeSessionIds
      ..clear()
      ..addAll(_wsRepo.activeSessionIds);
    _sessionSub = _wsRepo.activeSessions.listen((ids) {
      activeSessionIds
        ..clear()
        ..addAll(ids);
      // Clear selection if selected machine went offline
      final sel = selectedMachine.value;
      if (sel != null && !ids.contains(sel.machineId)) {
        selectedMachine.value = null;
      }
    });
  }

  bool isMachineConnected(String machineId) {
    return activeSessionIds.contains(machineId);
  }

  Future<void> _loadMachines() async {
    final list = await _machineRepo.listMachines();
    machines.value = list;

    // Auto-select first online machine if only one is online
    final onlineMachines = list
        .where((m) => isMachineConnected(m.machineId))
        .toList();
    if (onlineMachines.length == 1) {
      selectedMachine.value = onlineMachines.first;
    }

    _loadRecentCwds();
  }

  void selectMachine(PairedMachine machine) {
    if (!isMachineConnected(machine.machineId)) return;
    selectedMachine.value = machine;
  }

  void selectMode(PermissionMode mode) => selectedMode.value = mode;

  Future<void> _loadRecentCwds() async {
    final machineId = selectedMachine.value?.machineId;
    final list = await SessionDatabase.recentCwds(machineId: machineId);
    recentCwds.value = list;
    _filterCwds();
  }

  void _filterCwds() {
    final query = cwdController.text.trim().toLowerCase();
    if (query.isEmpty) {
      filteredCwds.value = List.of(recentCwds);
    } else {
      filteredCwds.value = recentCwds
          .where((c) => c.path.toLowerCase().contains(query))
          .toList();
    }
    if (cwdFocusNode.hasFocus && filteredCwds.isNotEmpty) {
      isCwdDropdownOpen.value = true;
    } else if (filteredCwds.isEmpty) {
      isCwdDropdownOpen.value = false;
    }
  }

  void selectCwd(RecentCwd cwd) {
    cwdController.text = cwd.path;
    isCwdDropdownOpen.value = false;
    cwdFocusNode.unfocus();
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
      if (cwd.isEmpty) {
        throw Exception('Working directory is required');
      }
      if (!cwd.startsWith('/') && !cwd.startsWith('~')) {
        throw Exception(
          'Working directory must be an absolute path or start with ~',
        );
      }
      final createParams = <String, dynamic>{
        'cwd': cwd,
        'permissionMode': selectedMode.value.id,
      };

      final createResult = await _wsRepo.callRpc(
        machineId: machine.machineId,
        method: 'session.create',
        params: createParams,
      );

      final sessionId = createResult['sessionId'] as String?;
      if (sessionId == null || sessionId.isEmpty) {
        throw Exception('Failed to create session: no sessionId returned');
      }
      final runtime = createResult['runtime'] as String? ?? '';

      // Register session in EventRepository
      _eventRepo.registerSession(
        AgentSession(
          id: sessionId,
          title: '',
          status: SessionStatus.idle,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {
            'machineId': machine.machineId,
            'runtime': runtime,
            'cwd': cwd,
            'mode': selectedMode.value.id,
          },
        ),
      );

      // Navigate to chat immediately — don't wait for prompt to finish.
      final prompt = promptController.text.trim();
      Get.offNamed(
        Routes.chat,
        arguments: {
          'sessionId': sessionId,
          'machineId': machine.machineId,
          'cwd': cwd,
          'sessionTitle': '',
          'isNewSession': true,
          if (prompt.isNotEmpty) 'initialPrompt': prompt,
        },
      );
    } catch (e) {
      uiEffect.value = ShowToast(e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
