import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/models/auth_request.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/services/local/crypto_service.dart';
import '../../routing/routes.dart';

class SettingsViewModel extends GetxController {
  final CryptoService _crypto = Get.find<CryptoService>();
  final PairedMachineRepository _machineRepo =
      Get.find<PairedMachineRepository>();

  final hasMasterKey = false.obs;
  final machineCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    hasMasterKey.value = await _crypto.hasMasterKey();
    final machines = await _machineRepo.listMachines();
    machineCount.value = machines.length;
  }

  void navigateToScan() {
    Get.toNamed(Routes.scan);
  }

  void showPasteUrlDialog() async {
    final textController = TextEditingController();

    // Auto-fill from clipboard if it contains a muxagent URL
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
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final url = textController.text.trim();
              if (url.isEmpty) return;
              if (!url.toLowerCase().startsWith('muxagent://auth')) {
                Get.snackbar('Error', 'Invalid URL format');
                return;
              }
              final authRequest = AuthRequest.fromQrUrl(url);
              if (!authRequest.isValid) {
                Get.snackbar('Error', 'Missing id or relay parameter');
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
