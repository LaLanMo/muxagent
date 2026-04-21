import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/auth_request.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/repositories/reconnect_recovery_coordinator.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../data/services/local/crypto_service.dart';
import '../../domain/paired_machine.dart';
import '../../domain/ui_effect.dart';
import '../../i18n/tx.dart';
import '../../routing/routes.dart';

enum MachineConnectionDisplayState { online, connecting, serverLost, offline }

class SettingsTabViewModel extends GetxController {
  final CryptoService _crypto;
  final PairedMachineRepository _machineRepo;
  final WsSessionRepository _wsRepo;
  final Future<ReconnectRecoveryResult> Function(PairedMachine) _connectMachine;
  final PairingLinkParser _pairingLinkParser;

  SettingsTabViewModel({
    required CryptoService crypto,
    required PairedMachineRepository machineRepo,
    required WsSessionRepository wsRepo,
    required Future<ReconnectRecoveryResult> Function(PairedMachine)
    connectMachine,
    required PairingLinkParser pairingLinkParser,
  }) : _crypto = crypto,
       _machineRepo = machineRepo,
       _wsRepo = wsRepo,
       _connectMachine = connectMachine,
       _pairingLinkParser = pairingLinkParser;

  final hasMasterKey = false.obs;
  final appVersion = ''.obs;
  final connectingMachines = <String>{}.obs;
  final uiEffect = Rxn<UiEffect>();

  RxBool get relayConnected => _wsRepo.relayConnected;
  ValueListenable<List<PairedMachine>> get machinesListenable =>
      _machineRepo.machinesListenable;
  List<PairedMachine> get machines => _machineRepo.machines;
  ValueListenable<Set<String>> get activeSessionIdsListenable =>
      _wsRepo.activeSessionIdsListenable;

  bool isMachineConnected(String machineId) {
    return _wsRepo.activeSessionIds.contains(machineId);
  }

  MachineConnectionDisplayState machineConnectionState(String machineId) {
    if (_wsRepo.activeSessionIds.contains(machineId)) {
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
    unawaited(_machineRepo.refresh());
  }

  Future<void> _load() async {
    hasMasterKey.value = await _crypto.hasMasterKey();
    appVersion.value = await _loadAppVersion();
  }

  Future<String> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isEmpty) {
        return Tx.commonUnknown.tr;
      }
      return packageInfo.version;
    } catch (_) {
      return Tx.commonUnknown.tr;
    }
  }

  void navigateToScan() {
    Get.toNamed(Routes.scan);
  }

  void navigateToSttSettings() {
    Get.toNamed(Routes.sttSettings);
  }

  void navigateToLanguage() {
    Get.toNamed(Routes.language);
  }

  Future<void> connectMachine(PairedMachine machine) async {
    if (isMachineConnected(machine.machineId)) return;
    if (connectingMachines.contains(machine.machineId)) return;
    connectingMachines.add(machine.machineId);
    try {
      final result = await _connectMachine(machine);
      if (result.sessionReady) {
        uiEffect.value = ShowToast(
          Tx.connectedTo(machine.hostname ?? Tx.settingsMachineFallback.tr),
        );
      } else {
        uiEffect.value = ShowToast(Tx.settingsFailedToConnect.tr);
      }
    } catch (e) {
      uiEffect.value = ShowToast(Tx.connectionFailed(e));
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

  void openGithubRepo() {
    launchUrl(
      Uri.parse('https://github.com/LaLanMo/muxagent'),
      mode: LaunchMode.externalApplication,
    );
  }

  void openAuthorX() {
    launchUrl(
      Uri.parse('https://x.com/hexarrior'),
      mode: LaunchMode.externalApplication,
    );
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
        title: Text(Tx.settingsPasteConnectionUrl.tr),
        content: buildPasteUrlTextField(controller: textController),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(Tx.commonCancel.tr),
          ),
          TextButton(
            onPressed: () {
              final url = textController.text.trim();
              if (url.isEmpty) return;
              final result = _pairingLinkParser.parseText(url);
              if (!result.isSuccess) {
                uiEffect.value = ShowToast(_errorMessageFor(result.failure!));
                return;
              }
              Get.back();
              Get.toNamed(Routes.auth, arguments: result.authRequest);
            },
            child: Text(Tx.commonConnect.tr),
          ),
        ],
      ),
    );
  }

  static TextField buildPasteUrlTextField({
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        hintText: 'muxagent://auth?id=...&relay=...',
      ),
      maxLines: 3,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.none,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
    );
  }

  String _errorMessageFor(PairingLinkParseFailure failure) {
    switch (failure) {
      case PairingLinkParseFailure.emptyInput:
      case PairingLinkParseFailure.malformedUri:
      case PairingLinkParseFailure.invalidScheme:
      case PairingLinkParseFailure.invalidTarget:
        return Tx.settingsInvalidUrl.tr;
      case PairingLinkParseFailure.missingId:
      case PairingLinkParseFailure.missingRelay:
        return Tx.settingsMissingIdRelay.tr;
    }
  }
}
