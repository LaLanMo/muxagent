import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:record/record.dart';

import '../../data/local/session_database.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/paired_machine_repository.dart';
import '../../data/repositories/runtime_preference_repository.dart';
import '../../data/repositories/ws_session_repository.dart';
import '../../usecases/transcribe_audio.dart';
import '../../utils/app_toast.dart';
import '../../domain/enums.dart';
import '../../domain/mode_option.dart';
import '../../domain/paired_machine.dart';
import '../../domain/runtime_option.dart';
import '../../domain/session.dart';
import '../../domain/ui_effect.dart';
import '../../routing/routes.dart';

class NewSessionViewModel extends GetxController {
  static const _createSessionTimeout = Duration(seconds: 15);

  final PairedMachineRepository _machineRepo;
  final WsSessionRepository _wsRepo;
  final EventRepository _eventRepo;
  final RuntimePreferenceRepository _runtimePrefs;
  final TranscribeAudioUseCase _transcribe;

  NewSessionViewModel({
    required PairedMachineRepository machineRepo,
    required WsSessionRepository wsRepo,
    required EventRepository eventRepo,
    required RuntimePreferenceRepository runtimePrefs,
    required TranscribeAudioUseCase transcribe,
  }) : _machineRepo = machineRepo,
       _wsRepo = wsRepo,
       _eventRepo = eventRepo,
       _runtimePrefs = runtimePrefs,
       _transcribe = transcribe;

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

  final machines = <PairedMachine>[].obs;
  final selectedMachine = Rxn<PairedMachine>();
  final isLoading = false.obs;
  final activeSessionIds = <String>{}.obs;
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

  StreamSubscription<Set<String>>? _sessionSub;
  int _runtimeLoadToken = 0;
  final _rememberedModeIds = <String, String>{};
  String _selectedModeRuntimeId = '';

  @override
  void onInit() {
    super.onInit();
    _subscribeToActiveSessions();
    _loadMachines();
    _checkSttConfig();

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

    ever(selectedMachine, (machine) {
      _loadRecentCwds();
      _loadRuntimes(machine);
    });
    ever(selectedRuntime, _syncModesForRuntime);
  }

  @override
  void onClose() {
    _sessionSub?.cancel();
    _voiceRecorder?.dispose();
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
      if (sel != null && !ids.contains(sel.machineId) && !isLoading.value) {
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

      final result = await _wsRepo.callRpc(
        machineId: machine.machineId,
        method: 'runtime.list',
      );
      if (token != _runtimeLoadToken) return;

      final raw = result['runtimes'] as List<dynamic>? ?? const [];
      final all = raw
          .whereType<Map>()
          .map(
            (item) => RuntimeOption.fromJson(Map<String, dynamic>.from(item)),
          )
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

      final createParams = <String, dynamic>{
        'cwd': cwd,
        if (useWorktree.value) 'useWorktree': true,
        // Always send runtime explicitly
        'runtime': selectedRuntimeId,
        if (selectedMode.value != null)
          'permissionMode': selectedMode.value!.id,
      };

      final createResult = await _createSessionWithRecovery(
        machine: machine,
        params: createParams,
      );

      final sessionId = createResult['sessionId'] as String?;
      if (sessionId == null || sessionId.isEmpty) {
        throw Exception('Failed to create session: no sessionId returned');
      }
      final runtime = createResult['runtime'] as String? ?? '';
      await _rememberRuntimeSelection(
        runtime.isNotEmpty ? runtime : selectedRuntimeId,
      );
      final configOptions = createResult['configOptions'] as List<dynamic>?;
      debugPrint(
        '[NewSessionVM] createResult keys: ${createResult.keys.toList()}',
      );
      debugPrint(
        '[NewSessionVM] configOptions type: ${configOptions.runtimeType}',
      );
      if (configOptions != null) {
        for (final item in configOptions) {
          debugPrint(
            '[NewSessionVM]   item type: ${item.runtimeType} keys: ${item is Map ? item.keys.toList() : "N/A"}',
          );
        }
      }

      final initialMode = _extractCurrentMode(configOptions).isNotEmpty
          ? _extractCurrentMode(configOptions)
          : (selectedMode.value?.id ?? '');
      await _rememberModeSelection(
        runtimeId: runtime.isNotEmpty ? runtime : selectedRuntimeId,
        modeId: initialMode,
      );

      // Register session in EventRepository
      await _eventRepo.registerSession(
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
            'mode': initialMode,
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
          'runtime': runtime,
          'cwd': cwd,
          'sessionTitle': '',
          'isNewSession': true,
          if (configOptions != null) 'configOptions': configOptions,
          if (prompt.isNotEmpty) 'initialPrompt': prompt,
        },
      );
    } catch (e) {
      uiEffect.value = ShowToast(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> _createSessionWithRecovery({
    required PairedMachine machine,
    required Map<String, dynamic> params,
  }) async {
    try {
      return await _callCreateSession(machine.machineId, params);
    } on TimeoutException {
      await _recoverRelaySession(machine, 'session.create timeout');
      try {
        return await _callCreateSession(machine.machineId, params);
      } on TimeoutException {
        throw Exception(
          'Session create timed out after reconnect. Relay session appears stale.',
        );
      }
    }
  }

  Future<Map<String, dynamic>> _callCreateSession(
    String machineId,
    Map<String, dynamic> params,
  ) {
    return _wsRepo
        .callRpc(machineId: machineId, method: 'session.create', params: params)
        .timeout(
          _createSessionTimeout,
          onTimeout: () => throw TimeoutException(
            'session.create timeout',
            _createSessionTimeout,
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

  String _extractCurrentMode(List<dynamic>? configOptions) {
    if (configOptions == null) return '';
    for (final item in configOptions) {
      if (item is! Map) continue;
      final raw = Map<String, dynamic>.from(item);
      if ((raw['category'] as String? ?? '') == 'mode') {
        return raw['currentValue'] as String? ?? '';
      }
    }
    return '';
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
      default:
        return runtimeDefaultModeId ?? '';
    }
  }
}
