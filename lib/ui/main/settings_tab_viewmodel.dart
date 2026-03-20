import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/auth_request.dart';
import '../../data/services/local/crypto_service.dart';
import '../../domain/paired_machine.dart';
import '../../domain/ui_effect.dart';
import '../../routing/routes.dart';

enum MachineConnectionDisplayState { online, connecting, serverLost, offline }

class SettingsTabViewModel extends GetxController {
  final CryptoService _crypto;
  final RxList<PairedMachine> machines;
  final RxSet<String> activeSessionIds;
  final RxBool relayConnected;
  final Future<void> Function(PairedMachine) _connectMachine;

  SettingsTabViewModel({
    required CryptoService crypto,
    required this.machines,
    required this.activeSessionIds,
    required this.relayConnected,
    required Future<void> Function(PairedMachine) connectMachine,
  }) : _crypto = crypto,
       _connectMachine = connectMachine;

  final hasMasterKey = false.obs;
  final connectingMachines = <String>{}.obs;
  final uiEffect = Rxn<UiEffect>();

  bool isMachineConnected(String machineId) {
    return activeSessionIds.contains(machineId);
  }

  MachineConnectionDisplayState machineConnectionState(String machineId) {
    if (activeSessionIds.contains(machineId)) {
      return MachineConnectionDisplayState.online;
    }
    if (connectingMachines.contains(machineId)) {
      return MachineConnectionDisplayState.connecting;
    }
    if (!relayConnected.value) {
      return MachineConnectionDisplayState.serverLost;
    }
    return MachineConnectionDisplayState.offline;
  }

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    hasMasterKey.value = await _crypto.hasMasterKey();
  }

  void navigateToScan() {
    Get.toNamed(Routes.scan);
  }

  void navigateToSttSettings() {
    Get.toNamed(Routes.sttSettings);
  }

  Future<void> connectMachine(PairedMachine machine) async {
    if (isMachineConnected(machine.machineId)) return;
    if (connectingMachines.contains(machine.machineId)) return;
    connectingMachines.add(machine.machineId);
    try {
      await _connectMachine(machine);
      if (isMachineConnected(machine.machineId)) {
        uiEffect.value = ShowToast(
          'Connected to ${machine.hostname ?? 'machine'}',
        );
      } else {
        uiEffect.value = ShowToast('Failed to connect');
      }
    } catch (e) {
      uiEffect.value = ShowToast('Connection failed: $e');
    } finally {
      connectingMachines.remove(machine.machineId);
    }
  }

  void openPrivacyPolicy() {
    launchUrl(Uri.parse('https://muxagent.com/en/privacy'));
  }

  void openTermsOfUse() {
    launchUrl(Uri.parse('https://muxagent.com/en/terms'));
  }

  void showPasteUrlDialog() async {
    final textController = TextEditingController();

    try {
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipData?.text != null &&
          clipData!.text!.startsWith('muxagent://auth')) {
        textController.text = clipData.text!;
      }
    } catch (_) {}

    Get.dialog(
      AlertDialog(
        title: const Text('Paste Connection URL'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'muxagent://auth?id=...&relay=...',
          ),
          maxLines: 3,
          autofocus: true,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final url = textController.text.trim();
              if (url.isEmpty) return;
              if (!url.toLowerCase().startsWith('muxagent://auth')) {
                uiEffect.value = ShowToast('Invalid URL format');
                return;
              }
              final authRequest = AuthRequest.fromQrUrl(url);
              if (!authRequest.isValid) {
                uiEffect.value = ShowToast('Missing id or relay parameter');
                return;
              }
              Get.back();
              Get.toNamed(Routes.auth, arguments: authRequest);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
