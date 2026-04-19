import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/repositories/runtime_preference_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../data/services/ws/models/acp_session_models.dart';
import '../../data/services/ws/session_config_mapper.dart';
import '../../domain/enums.dart';
import '../../domain/paired_machine.dart';
import '../../domain/runtime_option.dart';
import '../../domain/session.dart';
import '../../domain/ui_effect.dart';
import '../../routing/routes.dart';
import '../../ui/new_session/new_session_viewmodel.dart';

class AttachSessionViewModel extends GetxController {
  static const _attachTimeout = Duration(seconds: 15);
  static const _runtimeListTimeout = Duration(seconds: 12);

  final PairedMachineRepository _machineRepo;
  final WsSessionRepository _wsRepo;
  final EventRepository _eventRepo;
  final RuntimePreferenceRepository _runtimePrefs;

  AttachSessionViewModel({
    required PairedMachineRepository machineRepo,
    required WsSessionRepository wsRepo,
    required EventRepository eventRepo,
    required RuntimePreferenceRepository runtimePrefs,
  }) : _machineRepo = machineRepo,
       _wsRepo = wsRepo,
       _eventRepo = eventRepo,
       _runtimePrefs = runtimePrefs;

  RxBool get relayConnected => _wsRepo.relayConnected;
  Rx<ConnState> get relayConnectionState => _wsRepo.connectionState;
  ValueListenable<List<PairedMachine>> get machinesListenable =>
      _machineRepo.machinesListenable;
  ValueListenable<Set<String>> get activeSessionIdsListenable =>
      _wsRepo.activeSessionIdsListenable;
  List<PairedMachine> get machines => _machineRepo.machines;

  final sessionIdController = TextEditingController();
  final sessionIdFocusNode = FocusNode();
  final sessionIdText = ''.obs;
  final selectedMachine = Rxn<PairedMachine>();
  final availableRuntimes = <RuntimeOption>[].obs;
  final selectedRuntime = Rxn<RuntimeOption>();
  final isLoadingRuntimes = false.obs;
  final isLoading = false.obs;
  final isRuntimeDropdownOpen = false.obs;
  final isMachineDropdownOpen = false.obs;
  final uiEffect = Rxn<UiEffect>();

  VoidCallback? _activeSessionIdsListener;
  VoidCallback? _machinesListener;
  Worker? _relayConnectedWorker;
  int _runtimeLoadToken = 0;
  bool _shouldAutoSelectMachineOnReconnect = false;

  @override
  void onInit() {
    super.onInit();
    sessionIdController.addListener(_handleSessionIdChanged);
    ever(selectedMachine, _loadRuntimes);
    _subscribeToMachineCatalog();
    _subscribeToSessionPresence();
    _subscribeToRelayConnection();
    unawaited(_machineRepo.refresh());
  }

  @override
  void onClose() {
    if (_machinesListener != null) {
      _machineRepo.machinesListenable.removeListener(_machinesListener!);
    }
    if (_activeSessionIdsListener != null) {
      _wsRepo.activeSessionIdsListenable.removeListener(
        _activeSessionIdsListener!,
      );
    }
    _relayConnectedWorker?.dispose();
    sessionIdController.removeListener(_handleSessionIdChanged);
    sessionIdController.dispose();
    sessionIdFocusNode.dispose();
    super.onClose();
  }

  void _handleSessionIdChanged() {
    sessionIdText.value = sessionIdController.text.trim();
  }

  void _subscribeToMachineCatalog() {
    _syncMachineSelection();
    _machinesListener = _handleMachineCatalogChanged;
    _machineRepo.machinesListenable.addListener(_machinesListener!);
  }

  void _subscribeToSessionPresence() {
    _syncMachineSelection();
    _activeSessionIdsListener = () {
      _syncMachineSelection(
        selectFirstOnlineWhenMultiple: _shouldAutoSelectMachineOnReconnect,
      );
    };
    _wsRepo.activeSessionIdsListenable.addListener(_activeSessionIdsListener!);
  }

  void _subscribeToRelayConnection() {
    _shouldAutoSelectMachineOnReconnect = !_wsRepo.relayConnected.value;
    _relayConnectedWorker = ever<bool>(_wsRepo.relayConnected, (connected) {
      if (!connected) {
        _shouldAutoSelectMachineOnReconnect = true;
        return;
      }
      _syncMachineSelection(selectFirstOnlineWhenMultiple: true);
    });
  }

  bool isMachineConnected(String machineId) {
    return _wsRepo.activeSessionIds.contains(machineId);
  }

  void _syncMachineSelection({bool selectFirstOnlineWhenMultiple = false}) {
    final resolved = NewSessionViewModel.resolveSelectedMachine(
      machines: machines,
      connectedMachineIds: _wsRepo.activeSessionIds,
      current: selectedMachine.value,
      selectFirstOnlineWhenMultiple: selectFirstOnlineWhenMultiple,
    );

    if (resolved == null) {
      final current = selectedMachine.value;
      if (current != null &&
          !_wsRepo.activeSessionIds.contains(current.machineId) &&
          !isLoading.value) {
        selectedMachine.value = null;
      }
      return;
    }

    if (selectedMachine.value?.machineId != resolved.machineId) {
      selectedMachine.value = resolved;
    }
    _shouldAutoSelectMachineOnReconnect = false;
  }

  void _handleMachineCatalogChanged() {
    _syncMachineSelection(
      selectFirstOnlineWhenMultiple: _shouldAutoSelectMachineOnReconnect,
    );
  }

  void selectMachine(PairedMachine machine) {
    if (!isMachineConnected(machine.machineId)) return;
    isMachineDropdownOpen.value = false;
    selectedMachine.value = machine;
  }

  void selectRuntime(RuntimeOption runtime) {
    isRuntimeDropdownOpen.value = false;
    selectedRuntime.value = runtime;
    unawaited(_rememberRuntimeSelection(runtime.id));
  }

  void toggleRuntimeDropdown() {
    if (isLoadingRuntimes.value || availableRuntimes.isEmpty) return;
    closeMachineDropdown();
    sessionIdFocusNode.unfocus();
    isRuntimeDropdownOpen.value = !isRuntimeDropdownOpen.value;
  }

  void closeRuntimeDropdown() {
    isRuntimeDropdownOpen.value = false;
  }

  void toggleMachineDropdown() {
    if (machines.isEmpty) return;
    closeRuntimeDropdown();
    sessionIdFocusNode.unfocus();
    isMachineDropdownOpen.value = !isMachineDropdownOpen.value;
  }

  void closeMachineDropdown() {
    isMachineDropdownOpen.value = false;
  }

  void dismissTransientInputs() {
    closeRuntimeDropdown();
    closeMachineDropdown();
    sessionIdFocusNode.unfocus();
  }

  void focusSessionIdInput() {
    closeRuntimeDropdown();
    closeMachineDropdown();
    if (!sessionIdFocusNode.hasFocus) {
      sessionIdFocusNode.requestFocus();
    }
  }

  Future<void> _loadRuntimes(PairedMachine? machine) async {
    final token = ++_runtimeLoadToken;
    closeRuntimeDropdown();

    if (machine == null) {
      availableRuntimes.clear();
      selectedRuntime.value = null;
      isLoadingRuntimes.value = false;
      return;
    }

    isLoadingRuntimes.value = true;
    try {
      if (!_wsRepo.relayConnected.value) {
        await _wsRepo.resetConnection(reason: 'runtime.list reconnect');
      }
      await _wsRepo.ensureConnected(relayHttpUrl: machine.relayHttpUrl);
      if (!_wsRepo.hasSession(machine.machineId)) {
        await _wsRepo.startSession(machine: machine);
      }

      if (token != _runtimeLoadToken) return;

      final response = await _loadRuntimesWithRecovery(machine);
      if (token != _runtimeLoadToken) return;
      final all = response.runtimes
          .map(SessionConfigMapper.runtimeOptionFromDto)
          .toList();
      final visible = all.where((item) => item.ready).toList();
      final options = visible.isNotEmpty ? visible : all;
      final rememberedRuntimeId = await _runtimePrefs
          .getLastSelectedRuntimeId();
      if (token != _runtimeLoadToken) return;
      availableRuntimes.value = options;
      selectedRuntime.value = NewSessionViewModel.resolveSelectedRuntime(
        options: options,
        current: selectedRuntime.value,
        rememberedRuntimeId: rememberedRuntimeId,
      );
    } catch (e) {
      if (token != _runtimeLoadToken) return;
      availableRuntimes.clear();
      selectedRuntime.value = null;
      debugPrint('[AttachSessionVM] load runtimes failed: $e');
    } finally {
      if (token == _runtimeLoadToken) {
        isLoadingRuntimes.value = false;
      }
    }
  }

  Future<AppRuntimeListResponseDto> _loadRuntimesWithRecovery(
    PairedMachine machine,
  ) async {
    try {
      return await _callListRuntimes(machine.machineId);
    } on TimeoutException {
      await _recoverRelaySession(machine, 'runtime.list timeout');
      try {
        return await _callListRuntimes(machine.machineId);
      } on TimeoutException {
        throw Exception(
          'Runtime list timed out after reconnect. Relay session appears stale.',
        );
      }
    } catch (e) {
      if (!NewSessionViewModel.isRecoverableTransportError(e)) {
        rethrow;
      }
      await _recoverRelaySession(machine, e);
      return _callListRuntimes(machine.machineId);
    }
  }

  Future<AppRuntimeListResponseDto> _callListRuntimes(String machineId) {
    return _wsRepo
        .listRuntimes(machineId: machineId)
        .timeout(
          _runtimeListTimeout,
          onTimeout: () => throw TimeoutException(
            'runtime.list timeout',
            _runtimeListTimeout,
          ),
        );
  }

  Future<void> attachSession() async {
    final sessionId = sessionIdController.text.trim();
    final machine = selectedMachine.value;
    final runtime = selectedRuntime.value;

    if (sessionId.isEmpty) {
      uiEffect.value = ShowToast('Session ID is required');
      return;
    }
    if (machine == null) {
      uiEffect.value = ShowToast('Please select a machine');
      return;
    }
    if (runtime == null) {
      uiEffect.value = ShowToast('Please select a runtime');
      return;
    }

    isLoading.value = true;
    try {
      if (!_wsRepo.relayConnected.value) {
        await _wsRepo.resetConnection(reason: 'relay disconnected');
      }
      await _wsRepo.ensureConnected(relayHttpUrl: machine.relayHttpUrl);
      if (!_wsRepo.hasSession(machine.machineId)) {
        await _wsRepo.startSession(machine: machine);
      }

      final response = await _attachSessionWithRecovery(
        machine: machine,
        sessionId: sessionId,
        runtime: runtime.id,
      );

      await _rememberRuntimeSelection(response.runtime);
      final createdAt = response.createdAt?.toLocal() ?? DateTime.now();
      final updatedAt = response.updatedAt?.toLocal() ?? createdAt;
      await _eventRepo.registerSession(
        AgentSession(
          id: response.sessionId,
          title: response.title,
          status: SessionStatus.fromValue(response.status),
          machineId: machine.machineId,
          runtime: response.runtime,
          cwd: response.cwd,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );

      navigateToChat(
        sessionId: response.sessionId,
        machineId: machine.machineId,
        runtime: response.runtime,
        cwd: response.cwd,
        sessionTitle: response.title,
      );
    } catch (e) {
      uiEffect.value = ShowToast(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  @visibleForTesting
  void navigateToChat({
    required String sessionId,
    required String machineId,
    required String runtime,
    required String cwd,
    required String sessionTitle,
  }) {
    Get.offNamed(
      Routes.chat,
      arguments: {
        'sessionId': sessionId,
        'machineId': machineId,
        'runtime': runtime,
        'cwd': cwd,
        'sessionTitle': sessionTitle,
        'isNewSession': false,
      },
    );
  }

  Future<AppSessionAttachResponseDto> _attachSessionWithRecovery({
    required PairedMachine machine,
    required String sessionId,
    required String runtime,
  }) async {
    try {
      return await _callAttachSession(
        machineId: machine.machineId,
        sessionId: sessionId,
        runtime: runtime,
      );
    } on TimeoutException {
      await _recoverRelaySession(machine, 'session.attach timeout');
      try {
        return await _callAttachSession(
          machineId: machine.machineId,
          sessionId: sessionId,
          runtime: runtime,
        );
      } on TimeoutException {
        throw Exception(
          'Session attach timed out after reconnect. Relay session appears stale.',
        );
      }
    } catch (e) {
      if (!NewSessionViewModel.isRecoverableTransportError(e)) {
        rethrow;
      }
      await _recoverRelaySession(machine, e);
      return _callAttachSession(
        machineId: machine.machineId,
        sessionId: sessionId,
        runtime: runtime,
      );
    }
  }

  Future<AppSessionAttachResponseDto> _callAttachSession({
    required String machineId,
    required String sessionId,
    required String runtime,
  }) {
    return _wsRepo
        .attachSession(
          machineId: machineId,
          sessionId: sessionId,
          runtime: runtime,
        )
        .timeout(
          _attachTimeout,
          onTimeout: () =>
              throw TimeoutException('session.attach timeout', _attachTimeout),
        );
  }

  Future<void> _recoverRelaySession(
    PairedMachine machine,
    Object reason,
  ) async {
    await _wsRepo.resetConnection(reason: reason);
    await _wsRepo.ensureConnected(relayHttpUrl: machine.relayHttpUrl);
    await _wsRepo.startSession(machine: machine);
    selectedMachine.value = machine;
  }

  Future<void> _rememberRuntimeSelection(String runtimeId) async {
    if (runtimeId.isEmpty) return;
    try {
      await _runtimePrefs.setLastSelectedRuntimeId(runtimeId);
    } catch (e) {
      debugPrint('[AttachSessionVM] failed to store runtime preference: $e');
    }
  }
}
