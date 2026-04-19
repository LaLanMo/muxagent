import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/repositories/reconnect_recovery_coordinator.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../data/services/ws/models/ws_models.dart';
import '../../data/services/ws/ws_types.dart';
import '../../domain/enums.dart';
import '../../domain/paired_machine.dart';
import '../../routing/routes.dart';

class MainShellViewModel extends GetxController with WidgetsBindingObserver {
  final PairedMachineRepository _machineRepo;
  final ReconnectRecoveryCoordinator _recovery;
  final WsSessionRepository _wsRepo;
  final EventRepository _eventRepo;

  MainShellViewModel({
    required PairedMachineRepository machineRepo,
    required ReconnectRecoveryCoordinator recovery,
    required WsSessionRepository wsRepo,
    required EventRepository eventRepo,
  }) : _machineRepo = machineRepo,
       _recovery = recovery,
       _wsRepo = wsRepo,
       _eventRepo = eventRepo;

  RxBool get relayConnected => _wsRepo.relayConnected;
  Rx<ConnState> get relayConnectionState => _wsRepo.connectionState;
  ValueListenable<List<PairedMachine>> get machinesListenable =>
      _machineRepo.machinesListenable;
  List<PairedMachine> get machines => _machineRepo.machines;

  final tabIndex = 0.obs;

  StreamSubscription<WsMachineStatus>? _machineStatusSub;
  VoidCallback? _machinesListener;
  bool _isReconnecting = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _subscribeToMachineCatalog();
    unawaited(_loadMachines());
    _subscribeToMachineStatus();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _machineStatusSub?.cancel();
    if (_machinesListener != null) {
      _machineRepo.machinesListenable.removeListener(_machinesListener!);
    }
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconnectAllMachines();
    }
  }

  Future<void> _reconnectAllMachines() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    try {
      // Detect TCP half-open: relay thinks connected but socket is dead
      if (_wsRepo.relayConnected.value && !_wsRepo.isConnected) {
        await _wsRepo.resetConnection(reason: 'stale connection on resume');
      }
      for (final machine in machines) {
        if (!_wsRepo.hasSession(machine.machineId)) {
          await _connectMachineInBackground(machine);
        }
      }
    } finally {
      _isReconnecting = false;
    }
  }

  void switchTab(int index) {
    tabIndex.value = index;
  }

  int get pendingApprovalCount => _eventRepo.pendingApprovals.length;

  bool isMachineConnected(String machineId) {
    return _wsRepo.activeSessionIds.contains(machineId);
  }

  String machineDisplayName(String machineId) {
    for (final machine in machines) {
      if (machine.machineId == machineId) {
        return machine.hostname ?? machineId;
      }
    }
    return machineId;
  }

  Future<void> refreshMachines() async {
    await _machineRepo.refresh();
  }

  void navigateToNewSession() {
    Get.toNamed(Routes.newSession);
  }

  void navigateToChat(
    String sessionId,
    String machineId,
    String runtime,
    String cwd,
    String title,
  ) {
    Get.toNamed(
      Routes.chat,
      arguments: chatRouteArguments(
        sessionId: sessionId,
        machineId: machineId,
        runtime: runtime,
        cwd: cwd,
        title: title,
      ),
    );
  }

  @visibleForTesting
  static Map<String, dynamic> chatRouteArguments({
    required String sessionId,
    required String machineId,
    required String runtime,
    required String cwd,
    required String title,
  }) {
    return {
      'sessionId': sessionId,
      'machineId': machineId,
      'runtime': runtime,
      'cwd': cwd,
      'sessionTitle': title,
    };
  }

  // --- Private ---

  Future<void> _loadMachines() async {
    await _machineRepo.refresh();
    _connectKnownMachines();
  }

  void _subscribeToMachineCatalog() {
    _machinesListener = _handleMachineCatalogChanged;
    _machineRepo.machinesListenable.addListener(_machinesListener!);
  }

  void _handleMachineCatalogChanged() {
    _connectKnownMachines();
  }

  void _connectKnownMachines() {
    for (final machine in machines) {
      if (!_wsRepo.hasSession(machine.machineId)) {
        unawaited(_connectMachineInBackground(machine));
      }
    }
  }

  Future<void> _connectMachineInBackground(PairedMachine machine) async {
    final result = await connectMachine(machine);
    if (!result.sessionReady) {
      debugPrint(
        '[MainShell] connect ${machine.machineId} did not establish a session'
        '${result.transportError != null ? ': ${result.transportError}' : ''}',
      );
    }
  }

  Future<ReconnectRecoveryResult> connectMachine(PairedMachine machine) async {
    try {
      return await _recovery.recoverMachine(
        machine.machineId,
        transcriptMode: TranscriptRecoveryMode.metadataOnly,
      );
    } catch (e) {
      return ReconnectRecoveryResult(
        machineId: machine.machineId,
        transcript: TranscriptRecoveryState.failed,
        metadata: MetadataRecoveryState.skipped,
        sessionReady: false,
        statusesOk: false,
        knownSessionsOk: false,
        approvalsOk: false,
        transportError: e,
      );
    }
  }

  void _subscribeToMachineStatus() {
    _machineStatusSub = _wsRepo.machineStatus.listen((status) {
      if (status.type == WsMessageType.machineOnline.value) {
        final machine = machines.firstWhereOrNull(
          (m) => m.machineId == status.machineId,
        );
        if (machine != null && !_wsRepo.hasSession(machine.machineId)) {
          _connectMachineInBackground(machine);
        }
      }
    });
  }
}
