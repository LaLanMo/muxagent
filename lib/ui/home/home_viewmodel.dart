import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/auth_request.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../data/services/local/crypto_service.dart';
import '../../domain/paired_machine.dart';
import '../../routing/routes.dart';

class HomeViewModel extends GetxController {
  final CryptoService _crypto = Get.find<CryptoService>();
  final PairedMachineRepository _machines = Get.find<PairedMachineRepository>();
  final WsSessionRepository _sessions = Get.find<WsSessionRepository>();

  final hasMasterKey = false.obs;
  final urlController = TextEditingController();
  final urlError = RxnString();
  final machines = <PairedMachine>[].obs;
  final connectionStatus = RxnString();
  final activeSessionIds = <String>{}.obs;
  StreamSubscription<Set<String>>? _sessionSub;

  @override
  void onInit() {
    super.onInit();
    _checkMasterKey();
    _loadMachines();
    activeSessionIds
      ..clear()
      ..addAll(_sessions.activeSessionIds);
    _sessionSub = _sessions.activeSessions.listen((ids) {
      activeSessionIds
        ..clear()
        ..addAll(ids);
    });
  }

  @override
  void onClose() {
    _sessionSub?.cancel();
    urlController.dispose();
    super.onClose();
  }

  Future<void> _checkMasterKey() async {
    hasMasterKey.value = await _crypto.hasMasterKey();
  }

  Future<void> _loadMachines() async {
    machines.value = await _machines.listMachines();
  }

  void onScanPressed() {
    Get.toNamed(Routes.scan);
  }

  void onManualConnect() {
    final url = urlController.text.trim();
    if (url.isEmpty) {
      urlError.value = 'Please enter a URL';
      return;
    }

    if (!url.startsWith('muxagent://auth')) {
      urlError.value = 'Invalid URL format. Must start with muxagent://auth';
      return;
    }

    final authRequest = AuthRequest.fromQrUrl(url);
    if (!authRequest.isValid) {
      urlError.value = 'Invalid URL: missing id or relay parameter';
      return;
    }

    urlError.value = null;
    urlController.clear();
    Get.toNamed(Routes.auth, arguments: authRequest);
  }

  void clearUrlError() {
    urlError.value = null;
  }

  Future<void> refreshMachines() async {
    await _loadMachines();
  }

  Future<void> deleteMachine(PairedMachine machine) async {
    if (_sessions.hasSession(machine.machineId)) {
      await _sessions.endSession(machine.machineId);
    }
    await _machines.removeMachine(machine.machineId);
    await _loadMachines();
    connectionStatus.value = 'Deleted ${machine.hostname ?? machine.machineId}';
  }

  List<PairedMachine> get connectedMachines => machines
      .where((machine) => activeSessionIds.contains(machine.machineId))
      .toList();

  List<PairedMachine> get availableMachines => machines
      .where((machine) => !activeSessionIds.contains(machine.machineId))
      .toList();

  Future<void> connectMachine(PairedMachine machine) async {
    if (_sessions.hasSession(machine.machineId)) {
      connectionStatus.value =
          '${machine.hostname ?? machine.machineId} already connected';
      return;
    }
    try {
      connectionStatus.value = 'Connecting...';
      await _sessions.ensureConnected(relayHttpUrl: machine.relayHttpUrl);
      await _sessions.startSession(machine: machine);
      connectionStatus.value =
          'Connected to ${machine.hostname ?? machine.machineId}';
    } catch (e) {
      connectionStatus.value = 'Connection failed: $e';
    }
  }

  Future<void> testEcho(PairedMachine machine) async {
    if (!_sessions.hasSession(machine.machineId)) {
      connectionStatus.value =
          'Not connected to ${machine.hostname ?? machine.machineId}';
      return;
    }
    try {
      connectionStatus.value = 'Sending echo...';
      final response = await _sessions.callRpc(
        machineId: machine.machineId,
        method: 'echo',
        params: {'message': 'hello'},
      );
      final error = response['error'] as String?;
      if (error != null && error.isNotEmpty) {
        connectionStatus.value = 'Error: $error';
      } else {
        connectionStatus.value =
            'Echo: ${response['result'] ?? response.toString()}';
      }
    } catch (e) {
      connectionStatus.value = 'Connection failed: $e';
    }
  }

  Future<void> disconnectMachine(PairedMachine machine) async {
    await _sessions.endSession(machine.machineId);
    connectionStatus.value =
        'Disconnected ${machine.hostname ?? machine.machineId}';
  }

  Future<void> disconnectAll() async {
    await _sessions.close();
    connectionStatus.value = 'Disconnected all sessions';
  }
}
