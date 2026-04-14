import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:record/record.dart';

import '../../data/local/session_database.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/repositories/runtime_preference_repository.dart';
import '../../data/repositories/session_chat_cache_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../data/services/ws/models/acp_session_models.dart';
import '../../data/services/ws/session_config_mapper.dart';
import '../../data/services/ws/transport_error_classifier.dart';
import '../../usecases/transcribe_audio.dart';
import '../../utils/app_toast.dart';
import '../../domain/enums.dart';
import '../../domain/mode_option.dart';
import '../../domain/paired_machine.dart';
import '../../domain/runtime_option.dart';
import '../../domain/session.dart';
import '../../domain/ui_effect.dart';
import '../../routing/routes.dart';

const _copilotModeAgentId =
    'https://agentclientprotocol.com/protocol/session-modes#agent';
const _geminiModeDefaultId = 'default';
const _gooseModeAutoId = 'auto';

class NewSessionViewModel extends GetxController {
  static const _createSessionTimeout = Duration(seconds: 15);
  static const _runtimeListTimeout = Duration(seconds: 12);

  final PairedMachineRepository _machineRepo;
  final WsSessionRepository _wsRepo;
  final EventRepository _eventRepo;
  final RuntimePreferenceRepository _runtimePrefs;
  final SessionChatCacheRepository _chatCacheRepo;
  final TranscribeAudioUseCase _transcribe;

  NewSessionViewModel({
    required PairedMachineRepository machineRepo,
    required WsSessionRepository wsRepo,
    required EventRepository eventRepo,
    required RuntimePreferenceRepository runtimePrefs,
    required SessionChatCacheRepository chatCacheRepo,
    required TranscribeAudioUseCase transcribe,
  }) : _machineRepo = machineRepo,
       _wsRepo = wsRepo,
       _eventRepo = eventRepo,
       _runtimePrefs = runtimePrefs,
       _chatCacheRepo = chatCacheRepo,
       _transcribe = transcribe;

  RxBool get relayConnected => _wsRepo.relayConnected;
  Rx<ConnState> get relayConnectionState => _wsRepo.connectionState;

  static RuntimeOption? resolveSelectedRuntime({
    required List<RuntimeOption> options,
    RuntimeOption? current,
    String? rememberedRuntimeId,
  }) {
    if (current != null) {
      for (final option in options) {
        if (option.id == current.id) {
          return option;
        }
      }
    }

    if (rememberedRuntimeId != null && rememberedRuntimeId.isNotEmpty) {
      for (final option in options) {
        if (option.id == rememberedRuntimeId) {
          return option;
        }
      }
    }

    if (options.isEmpty) return null;
    return options.first;
  }

  static ModeOption? resolveSelectedMode({
    required String runtimeId,
    required List<ModeOption> options,
    ModeOption? current,
    String? currentRuntimeId,
    String? rememberedModeId,
    String? runtimeDefaultModeId,
  }) {
    if (options.isEmpty) return null;

    if (current != null && currentRuntimeId == runtimeId) {
      for (final option in options) {
        if (option.id == current.id) {
          return option;
        }
      }
    }

    if (rememberedModeId != null && rememberedModeId.isNotEmpty) {
      for (final option in options) {
        if (option.id == rememberedModeId) {
          return option;
        }
      }
    }

    final defaultModeId = _defaultModeIdForRuntimeId(
      runtimeId: runtimeId,
      runtimeDefaultModeId: runtimeDefaultModeId,
    );
    for (final option in options) {
      if (option.id == defaultModeId) {
        return option;
      }
    }

    return options.first;
  }

  static PairedMachine? resolveSelectedMachine({
    required List<PairedMachine> machines,
    required Set<String> connectedMachineIds,
    PairedMachine? current,
    bool selectFirstOnlineWhenMultiple = false,
  }) {
    if (current != null) {
      for (final machine in machines) {
        if (machine.machineId == current.machineId &&
            connectedMachineIds.contains(machine.machineId)) {
          return machine;
        }
      }
    }

    final onlineMachines = machines
        .where((machine) => connectedMachineIds.contains(machine.machineId))
        .toList();
    if (onlineMachines.isEmpty) {
      return null;
    }
    if (onlineMachines.length == 1 || selectFirstOnlineWhenMultiple) {
      return onlineMachines.first;
    }
    return null;
  }

  static bool isRecoverableTransportError(Object error) {
    return isRecoverableSessionTransportError(error);
  }

  ValueListenable<List<PairedMachine>> get machinesListenable =>
      _machineRepo.machinesListenable;
  List<PairedMachine> get machines => _machineRepo.machines;
  final selectedMachine = Rxn<PairedMachine>();
  final isLoading = false.obs;
  final uiEffect = Rxn<UiEffect>();
  final availableRuntimes = <RuntimeOption>[].obs;
  final selectedRuntime = Rxn<RuntimeOption>();
  final isLoadingRuntimes = false.obs;
  final availableModes = <ModeOption>[].obs;
  final selectedMode = Rxn<ModeOption>();
  final useWorktree = false.obs;

  final hasSttConfig = false.obs;
  final isVoiceRecording = false.obs;
  final isTranscribing = false.obs;
  AudioRecorder? _voiceRecorder;

  final cwdController = TextEditingController();
  final promptController = TextEditingController();

  final recentCwds = <RecentCwd>[].obs;
  final filteredCwds = <RecentCwd>[].obs;
  final isCwdDropdownOpen = false.obs;
  final cwdFocusNode = FocusNode();
  final promptFocusNode = FocusNode();

  ValueListenable<Set<String>> get activeSessionIdsListenable =>
      _wsRepo.activeSessionIdsListenable;

  VoidCallback? _activeSessionIdsListener;
  VoidCallback? _machinesListener;
  Worker? _relayConnectedWorker;
  int _runtimeLoadToken = 0;
  final _rememberedModeIds = <String, String>{};
  String _selectedModeRuntimeId = '';
  bool _shouldAutoSelectMachineOnReconnect = false;

  @override
  void onInit() {
    super.onInit();
    _subscribeToMachineCatalog();
    _subscribeToSessionPresence();
    _subscribeToRelayConnection();
    unawaited(_machineRepo.refresh());
    _checkSttConfig();

    cwdController.addListener(_filterCwds);

    ever(selectedMachine, (machine) {
      _loadRecentCwds();
      _loadRuntimes(machine);
    });
    ever(selectedRuntime, _syncModesForRuntime);
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
    _voiceRecorder?.dispose();
    cwdFocusNode.dispose();
    promptFocusNode.dispose();
    cwdController.dispose();
    promptController.dispose();
    super.onClose();
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
    final activeSessionIds = _wsRepo.activeSessionIds;
    final resolved = resolveSelectedMachine(
      machines: machines,
      connectedMachineIds: activeSessionIds,
      current: selectedMachine.value,
      selectFirstOnlineWhenMultiple: selectFirstOnlineWhenMultiple,
    );

    if (resolved == null) {
      final current = selectedMachine.value;
      if (current != null &&
          !activeSessionIds.contains(current.machineId) &&
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
    selectedMachine.value = machine;
  }

  void selectRuntime(RuntimeOption runtime) {
    selectedRuntime.value = runtime;
    unawaited(_rememberRuntimeSelection(runtime.id));
  }

  void selectMode(ModeOption mode) {
    selectedMode.value = mode;
    final runtimeId = selectedRuntime.value?.id ?? '';
    _selectedModeRuntimeId = runtimeId;
    unawaited(_rememberModeSelection(runtimeId: runtimeId, modeId: mode.id));
  }

  void toggleWorktree() => useWorktree.value = !useWorktree.value;

  Future<void> _loadRecentCwds() async {
    final machineId = selectedMachine.value?.machineId;
    final list = await SessionDatabase.recentCwds(machineId: machineId);
    recentCwds.value = list;
    _filterCwds();
  }

  Future<void> _loadRuntimes(PairedMachine? machine) async {
    final token = ++_runtimeLoadToken;
    if (machine == null) {
      availableRuntimes.clear();
      selectedRuntime.value = null;
      availableModes.clear();
      selectedMode.value = null;
      _rememberedModeIds.clear();
      _selectedModeRuntimeId = '';
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
      final rememberedModeIds = await _runtimePrefs.getLastSelectedModeIds(
        options.map((option) => option.id),
      );
      if (token != _runtimeLoadToken) return;
      _rememberedModeIds
        ..clear()
        ..addAll(rememberedModeIds);
      availableRuntimes.value = options;
      selectedRuntime.value = resolveSelectedRuntime(
        options: options,
        current: selectedRuntime.value,
        rememberedRuntimeId: rememberedRuntimeId,
      );
    } catch (e) {
      if (token != _runtimeLoadToken) return;
      availableRuntimes.clear();
      selectedRuntime.value = null;
      _rememberedModeIds.clear();
      debugPrint('[NewSessionVM] load runtimes failed: $e');
    } finally {
      if (token == _runtimeLoadToken) {
        isLoadingRuntimes.value = false;
      }
    }
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
  }

  void openCwdDropdown() {
    isCwdDropdownOpen.value = true;
    if (!cwdFocusNode.hasFocus) {
      cwdFocusNode.requestFocus();
    }
  }

  void closeCwdDropdown({bool unfocus = false}) {
    isCwdDropdownOpen.value = false;
    if (unfocus) {
      cwdFocusNode.unfocus();
    }
  }

  void dismissTransientInputs() {
    closeCwdDropdown(unfocus: true);
    promptFocusNode.unfocus();
  }

  void focusPromptInput() {
    closeCwdDropdown(unfocus: true);
    promptFocusNode.requestFocus();
  }

  void selectCwd(RecentCwd cwd) {
    cwdController.text = cwd.path;
    cwdController.selection = TextSelection.collapsed(
      offset: cwdController.text.length,
    );
    closeCwdDropdown();
    if (!cwdFocusNode.hasFocus) {
      cwdFocusNode.requestFocus();
    }
  }

  void commitCwdAndFocusPrompt() {
    closeCwdDropdown(unfocus: true);
    promptFocusNode.requestFocus();
  }

  Future<void> _checkSttConfig() async {
    hasSttConfig.value = await _transcribe.hasConfig();
  }

  Future<void> startVoiceInput() async {
    isVoiceRecording.value = true;

    _voiceRecorder = AudioRecorder();
    if (!await _voiceRecorder!.hasPermission()) {
      AppToast.show('Microphone permission denied');
      isVoiceRecording.value = false;
      _voiceRecorder = null;
      return;
    }

    final path =
        '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _voiceRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (e) {
      AppToast.show('Failed to start recording');
      isVoiceRecording.value = false;
      await _voiceRecorder!.dispose();
      _voiceRecorder = null;
      return;
    }

    if (!await _voiceRecorder!.isRecording()) {
      AppToast.show('Microphone unavailable');
      isVoiceRecording.value = false;
      await _voiceRecorder!.dispose();
      _voiceRecorder = null;
      return;
    }
  }

  Future<void> stopVoiceInput() async {
    if (_voiceRecorder == null) {
      isVoiceRecording.value = false;
      return;
    }

    final path = await _voiceRecorder!.stop();
    await _voiceRecorder!.dispose();
    _voiceRecorder = null;

    if (path == null) {
      isVoiceRecording.value = false;
      AppToast.show('Recording failed');
      return;
    }

    final file = File(path);
    final size = await file.length();
    if (size < 100) {
      isVoiceRecording.value = false;
      AppToast.show('No audio captured — microphone may be unavailable');
      try {
        await file.delete();
      } catch (_) {}
      return;
    }

    isTranscribing.value = true;
    isVoiceRecording.value = false;
    try {
      final bytes = await file.readAsBytes();
      final result = await _transcribe.call(bytes, 'audio/m4a');
      if (result.text.isNotEmpty) {
        final current = promptController.text;
        if (current.isNotEmpty && !current.endsWith(' ')) {
          promptController.text = '$current ${result.text}';
        } else {
          promptController.text = '$current${result.text}';
        }
        promptController.selection = TextSelection.collapsed(
          offset: promptController.text.length,
        );
      }
    } catch (e) {
      AppToast.show('Transcription failed: $e');
    } finally {
      isTranscribing.value = false;
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<void> startSession() async {
    final machine = selectedMachine.value;
    if (machine == null) return;

    isLoading.value = true;

    try {
      if (!_wsRepo.relayConnected.value) {
        await _wsRepo.resetConnection(reason: 'relay disconnected');
      }

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
      // Runtime is auto-selected during load when at least one option exists.
      final selectedRuntimeId = selectedRuntime.value?.id ?? '';
      if (selectedRuntimeId.isEmpty) {
        throw Exception('Please select a runtime');
      }

      final createResponse = await _createSessionWithRecovery(
        machine: machine,
        cwd: cwd,
        runtime: selectedRuntimeId,
        permissionMode: selectedMode.value?.id,
        useWorktree: useWorktree.value,
      );

      final sessionId = createResponse.acp.sessionId;
      if (sessionId.isEmpty) {
        throw Exception('Failed to create session: no sessionId returned');
      }
      final runtime = createResponse.app.runtime;
      final effectiveRuntime = runtime.isNotEmpty ? runtime : selectedRuntimeId;
      await _rememberRuntimeSelection(effectiveRuntime);
      final configSnapshot = SessionConfigMapper.snapshotFromConfigOptions(
        runtimeId: effectiveRuntime,
        configOptions: createResponse.acp.configOptions ?? const [],
        modes: createResponse.acp.modes,
      );

      final initialMode =
          configSnapshot.currentMode?.id ?? (selectedMode.value?.id ?? '');
      await _rememberModeSelection(
        runtimeId: effectiveRuntime,
        modeId: initialMode,
      );

      // Register session in EventRepository
      await _eventRepo.registerSession(
        AgentSession(
          id: sessionId,
          title: '',
          status: SessionStatus.idle,
          machineId: machine.machineId,
          runtime: effectiveRuntime,
          cwd: createResponse.app.cwd,
          mode: initialMode.isNotEmpty ? initialMode : null,
          configSnapshot: configSnapshot,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await _chatCacheRepo.seedEmptyCache(
        sessionId: sessionId,
        machineId: machine.machineId,
      );

      // Navigate to chat immediately — don't wait for prompt to finish.
      final prompt = promptController.text.trim();
      Get.offNamed(
        Routes.chat,
        arguments: {
          'sessionId': sessionId,
          'machineId': machine.machineId,
          'runtime': effectiveRuntime,
          'cwd': createResponse.app.cwd,
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

  Future<AppSessionCreateResponseDto> _createSessionWithRecovery({
    required PairedMachine machine,
    required String cwd,
    required String runtime,
    required bool useWorktree,
    String? permissionMode,
  }) async {
    try {
      return await _callCreateSession(
        machineId: machine.machineId,
        cwd: cwd,
        runtime: runtime,
        permissionMode: permissionMode,
        useWorktree: useWorktree,
      );
    } on TimeoutException {
      await _recoverRelaySession(machine, 'session.create timeout');
      try {
        return await _callCreateSession(
          machineId: machine.machineId,
          cwd: cwd,
          runtime: runtime,
          permissionMode: permissionMode,
          useWorktree: useWorktree,
        );
      } on TimeoutException {
        throw Exception(
          'Session create timed out after reconnect. Relay session appears stale.',
        );
      }
    }
  }

  Future<AppSessionCreateResponseDto> _callCreateSession({
    required String machineId,
    required String cwd,
    required String runtime,
    required bool useWorktree,
    String? permissionMode,
  }) {
    return _wsRepo
        .createSession(
          machineId: machineId,
          cwd: cwd,
          runtime: runtime,
          useWorktree: useWorktree,
          permissionMode: permissionMode,
        )
        .timeout(
          _createSessionTimeout,
          onTimeout: () => throw TimeoutException(
            'session.create timeout',
            _createSessionTimeout,
          ),
        );
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
      if (!isRecoverableTransportError(e)) {
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
      debugPrint('[NewSessionVM] failed to store runtime preference: $e');
    }
  }

  Future<void> _rememberModeSelection({
    required String runtimeId,
    required String modeId,
  }) async {
    if (runtimeId.isEmpty || modeId.isEmpty) return;
    _rememberedModeIds[runtimeId] = modeId;
    try {
      await _runtimePrefs.setLastSelectedModeId(
        runtimeId: runtimeId,
        modeId: modeId,
      );
    } catch (e) {
      debugPrint('[NewSessionVM] failed to store mode preference: $e');
    }
  }

  void _syncModesForRuntime(RuntimeOption? runtime) {
    final options = _orderedModesForRuntime(runtime);
    availableModes.value = options;
    if (options.isEmpty) {
      selectedMode.value = null;
      _selectedModeRuntimeId = runtime?.id ?? '';
      return;
    }

    final runtimeId = runtime?.id ?? '';

    selectedMode.value = resolveSelectedMode(
      runtimeId: runtimeId,
      options: options,
      current: selectedMode.value,
      currentRuntimeId: _selectedModeRuntimeId,
      rememberedModeId: _rememberedModeIds[runtimeId],
      runtimeDefaultModeId: runtime?.defaultModeId,
    );
    _selectedModeRuntimeId = runtimeId;
  }

  List<ModeOption> _orderedModesForRuntime(RuntimeOption? runtime) {
    return ModeOption.orderedForRuntime(
      runtime?.id ?? '',
      runtime?.modeOptions ?? const <ModeOption>[],
    );
  }

  static String _defaultModeIdForRuntimeId({
    required String runtimeId,
    String? runtimeDefaultModeId,
  }) {
    switch (runtimeId) {
      case 'claude-code':
        return 'bypassPermissions';
      case 'codex':
        return 'full-access';
      case 'copilot':
        return _copilotModeAgentId;
      case 'gemini':
        return _geminiModeDefaultId;
      case 'goose':
        return _gooseModeAutoId;
      case 'opencode':
        return 'build';
      default:
        return runtimeDefaultModeId ?? '';
    }
  }
}
