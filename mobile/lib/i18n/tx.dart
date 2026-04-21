import 'package:get/get.dart';

class Tx {
  static const commonCancel = 'common.cancel';
  static const commonSave = 'common.save';
  static const commonConnect = 'common.connect';
  static const commonDone = 'common.done';
  static const commonRetry = 'common.retry';
  static const commonError = 'common.error';
  static const commonUnknown = 'common.unknown';
  static const commonUnknownHost = 'common.unknown_host';
  static const commonUnknownMachine = 'common.unknown_machine';
  static const commonUnknownRelay = 'common.unknown_relay';
  static const commonLoading = 'common.loading';
  static const commonUntitled = 'common.untitled';
  static const commonNow = 'common.now';
  static const commonJustNow = 'common.just_now';
  static const commonYesterday = 'common.yesterday';
  static const commonLastWeek = 'common.last_week';
  static const commonLastMonth = 'common.last_month';
  static const commonReconnecting = 'common.reconnecting';
  static const commonServerUnreachable = 'common.server_unreachable';
  static const commonConnectionLost = 'common.connection_lost';
  static const commonCopiedToClipboard = 'common.copied_to_clipboard';

  static const statusOnline = 'status.online';
  static const statusOffline = 'status.offline';
  static const statusConnecting = 'status.connecting';
  static const statusReconnecting = 'status.reconnecting';
  static const statusRunning = 'status.running';
  static const statusAwaiting = 'status.awaiting';
  static const statusFailed = 'status.failed';
  static const statusDone = 'status.done';
  static const statusPending = 'status.pending';
  static const statusApproval = 'status.approval';
  static const statusIdle = 'status.idle';
  static const statusSuccess = 'status.success';

  static const welcomeTagline = 'welcome.tagline';
  static const welcomeOr = 'welcome.or';
  static const welcomeScanQr = 'welcome.scan_qr';
  static const welcomeRunDaemon = 'welcome.run_daemon';
  static const welcomeEnterServerUrl = 'welcome.enter_server_url';
  static const welcomeViewGithub = 'welcome.view_github';
  static const welcomeInstallCopied = 'welcome.install_copied';
  static const welcomeUrlRequired = 'welcome.url_required';
  static const welcomeInvalidAuthUrl = 'welcome.invalid_auth_url';
  static const welcomeInvalidUrlMissing = 'welcome.invalid_url_missing';
  static const welcomeInvalidUrl = 'welcome.invalid_url';

  static const scanTitle = 'scan.title';
  static const scanInstruction = 'scan.instruction';
  static const scanInvalidQr = 'scan.invalid_qr';
  static const scanParseFailed = 'scan.parse_failed';

  static const authPairMachine = 'auth.pair_machine';
  static const authCheckingRequest = 'auth.checking_request';
  static const authCheckingRequestBody = 'auth.checking_request_body';
  static const authPairingMachine = 'auth.pairing_machine';
  static const authPairingMachineBody = 'auth.pairing_machine_body';
  static const authMachinePaired = 'auth.machine_paired';
  static const authPairingComplete = 'auth.pairing_complete';
  static const authRequestExpired = 'auth.request_expired';
  static const authRequestExpiredBody = 'auth.request_expired_body';
  static const authRequestExpiredStatus = 'auth.request_expired_status';
  static const authGoBack = 'auth.go_back';
  static const authPairingFailed = 'auth.pairing_failed';
  static const authUnknownError = 'auth.unknown_error';
  static const authMachineFound = 'auth.machine_found';
  static const authMachineDetails = 'auth.machine_details';
  static const authName = 'auth.name';
  static const authHost = 'auth.host';
  static const authRelay = 'auth.relay';
  static const authStatus = 'auth.status';
  static const authPairThisMachine = 'auth.pair_this_machine';
  static const authMissingRequest = 'auth.missing_request';
  static const authCheckFailed = 'auth.check_failed';
  static const authApproveFailed = 'auth.approve_failed';

  static const activeTitle = 'active.title';
  static const activeAllClear = 'active.all_clear';
  static const activeNoAttention = 'active.no_attention';
  static const activeStartNewSession = 'active.start_new_session';
  static const activeApprovalSection = 'active.approval_section';
  static const activeRunningSection = 'active.running_section';

  static const historyTitle = 'history.title';
  static const historyAll = 'history.all';
  static const historyNoSessionsFound = 'history.no_sessions_found';
  static const historyNoCompletedSessions = 'history.no_completed_sessions';
  static const historyTryDifferentMachine = 'history.try_different_machine';
  static const historyToday = 'history.today';
  static const historyYesterday = 'history.yesterday';
  static const historyLastWeek = 'history.last_week';

  static const settingsTitle = 'settings.title';
  static const settingsMachines = 'settings.machines';
  static const settingsPairing = 'settings.pairing';
  static const settingsConfiguration = 'settings.configuration';
  static const settingsAbout = 'settings.about';
  static const settingsScanQrCode = 'settings.scan_qr_code';
  static const settingsEnterUrl = 'settings.enter_url';
  static const settingsSpeechToText = 'settings.speech_to_text';
  static const settingsLanguage = 'settings.language';
  static const settingsVersion = 'settings.version';
  static const settingsStarGithub = 'settings.star_github';
  static const settingsFollowX = 'settings.follow_x';
  static const settingsPrivacyPolicy = 'settings.privacy_policy';
  static const settingsTermsOfUse = 'settings.terms_of_use';
  static const settingsTapToReconnect = 'settings.tap_to_reconnect';
  static const settingsConnectedTo = 'settings.connected_to';
  static const settingsMachineFallback = 'settings.machine_fallback';
  static const settingsFailedToConnect = 'settings.failed_to_connect';
  static const settingsConnectionFailed = 'settings.connection_failed';
  static const settingsPasteConnectionUrl = 'settings.paste_connection_url';
  static const settingsInvalidUrl = 'settings.invalid_url';
  static const settingsMissingIdRelay = 'settings.missing_id_relay';

  static const languageTitle = 'language.title';
  static const languageAppLanguage = 'language.app_language';
  static const languageFooter = 'language.footer';

  static const attachTitle = 'attach.title';
  static const attachSessionId = 'attach.session_id';
  static const attachRuntime = 'attach.runtime';
  static const attachMachine = 'attach.machine';
  static const attachExplanationTitle = 'attach.explanation_title';
  static const attachExplanationBody = 'attach.explanation_body';
  static const attachLoadingRuntimes = 'attach.loading_runtimes';
  static const attachNoRuntimes = 'attach.no_runtimes';
  static const attachSelectRuntime = 'attach.select_runtime';
  static const attachSelectMachine = 'attach.select_machine';
  static const attachSessionIdRequired = 'attach.session_id_required';
  static const attachSelectMachineToast = 'attach.select_machine_toast';
  static const attachSelectRuntimeToast = 'attach.select_runtime_toast';
  static const attachRuntimeListStale = 'attach.runtime_list_stale';
  static const attachSessionAttachStale = 'attach.session_attach_stale';

  static const newTitle = 'new.title';
  static const newRuntime = 'new.runtime';
  static const newMachine = 'new.machine';
  static const newWorkingDirectory = 'new.working_directory';
  static const newInitialPrompt = 'new.initial_prompt';
  static const newGitWorktree = 'new.git_worktree';
  static const newAttachExisting = 'new.attach_existing';
  static const newAlreadyStarted = 'new.already_started';
  static const newLoadingRuntimes = 'new.loading_runtimes';
  static const newNoRuntimes = 'new.no_runtimes';
  static const newSelectRuntime = 'new.select_runtime';
  static const newSelectMachine = 'new.select_machine';
  static const newUseRuntimeDefaultMode = 'new.use_runtime_default_mode';
  static const newMode = 'new.mode';
  static const newWorkingDirectorySemantic = 'new.working_directory_semantic';
  static const newNoRecentDirectories = 'new.no_recent_directories';
  static const newRecent = 'new.recent';
  static const newUseWorktree = 'new.use_worktree';
  static const newWorktreeBody = 'new.worktree_body';
  static const newInitialPromptSemantic = 'new.initial_prompt_semantic';
  static const newPromptHint = 'new.prompt_hint';
  static const newStartSession = 'new.start_session';
  static const newWorkingDirectoryRequired = 'new.working_directory_required';
  static const newWorkingDirectoryAbsolute = 'new.working_directory_absolute';
  static const newSelectRuntimeToast = 'new.select_runtime_toast';
  static const newCreateNoSessionId = 'new.create_no_session_id';
  static const newRecordingPermissionDenied = 'new.recording_permission_denied';
  static const newRecordingStartFailed = 'new.recording_start_failed';
  static const newMicrophoneUnavailable = 'new.microphone_unavailable';
  static const newRecordingFailed = 'new.recording_failed';
  static const newNoAudioCaptured = 'new.no_audio_captured';
  static const newTranscriptionFailed = 'new.transcription_failed';
  static const newSessionCreateStale = 'new.session_create_stale';
  static const newRuntimeListStale = 'new.runtime_list_stale';

  static const sttTitle = 'stt.title';
  static const sttEndpointUrl = 'stt.endpoint_url';
  static const sttEndpointHelper = 'stt.endpoint_helper';
  static const sttApiKey = 'stt.api_key';
  static const sttStoredSecurely = 'stt.stored_securely';
  static const sttModelName = 'stt.model_name';
  static const sttModelHelper = 'stt.model_helper';
  static const sttTest = 'stt.test';
  static const sttRecordPrompt = 'stt.record_prompt';
  static const sttApiKeyEnableTesting = 'stt.api_key_enable_testing';
  static const sttStopRecording = 'stt.stop_recording';
  static const sttRecordTestClip = 'stt.record_test_clip';
  static const sttEmptyTranscription = 'stt.empty_transcription';
  static const sttAddApiKeyToEnable = 'stt.add_api_key_to_enable';
  static const sttTranscribing = 'stt.transcribing';
  static const sttEndpointApiKeyRequired = 'stt.endpoint_api_key_required';
  static const sttSettingsSaved = 'stt.settings_saved';
  static const sttEndpointApiKeyEnable = 'stt.endpoint_api_key_enable';
  static const sttMicPermissionDenied = 'stt.mic_permission_denied';
  static const sttStartRecordingFailed = 'stt.start_recording_failed';
  static const sttMicUnavailableSettings = 'stt.mic_unavailable_settings';
  static const sttRecordingNoAudio = 'stt.recording_no_audio';
  static const sttNoAudioPermissionSettings =
      'stt.no_audio_permission_settings';
  static const sttNotConfigured = 'stt.not_configured';

  static const sessionSettingsTitle = 'session_settings.title';
  static const sessionSettingsModel = 'session_settings.model';
  static const sessionSettingsCostTokens = 'session_settings.cost_tokens';
  static const sessionSettingsContextWindow = 'session_settings.context_window';
  static const sessionSettingsNoModels = 'session_settings.no_models';
  static const sessionSettingsCost = 'session_settings.cost';
  static const sessionSettingsTotalTokens = 'session_settings.total_tokens';
  static const sessionSettingsInput = 'session_settings.input';
  static const sessionSettingsOutput = 'session_settings.output';
  static const sessionSettingsCacheRead = 'session_settings.cache_read';
  static const sessionSettingsCacheWrite = 'session_settings.cache_write';

  static const permissionRequest = 'permission.request';
  static const permissionRequired = 'permission.required';

  static const chatUnsupportedRestore = 'chat.unsupported_restore';
  static const chatRestoreError = 'chat.restore_error';
  static const chatRestoreHistoryTimeout = 'chat.restore_history_timeout';
  static const chatRestoreMissingBoth = 'chat.restore_missing_both';
  static const chatRestoreMissingRuntime = 'chat.restore_missing_runtime';
  static const chatRestoreMissingCwd = 'chat.restore_missing_cwd';
  static const chatRefreshingHistory = 'chat.refreshing_history';
  static const chatCachedHistory = 'chat.cached_history';
  static const chatTypeMessage = 'chat.type_message';
  static const chatSendMessage = 'chat.send_message';
  static const chatReadOnly = 'chat.read_only';
  static const chatStoppedLocally = 'chat.stopped_locally';
  static const chatPlan = 'chat.plan';
  static const chatNoFilesFound = 'chat.no_files_found';
  static const chatReviewPlan = 'chat.review_plan';
  static const chatPlanReview = 'chat.plan_review';
  static const chatPlanFallback = 'chat.plan_fallback';
  static const chatReadyToCode = 'chat.ready_to_code';
  static const chatRequestedPermissions = 'chat.requested_permissions';
  static const chatPreviewingFileChanges = 'chat.previewing_file_changes';
  static const chatMoreFileChange = 'chat.more_file_change';
  static const chatMoreFileChanges = 'chat.more_file_changes';
  static const chatShowMoreLine = 'chat.show_more_line';
  static const chatShowMoreLines = 'chat.show_more_lines';
  static const chatCollapse = 'chat.collapse';
  static const chatFileChanged = 'chat.file_changed';
  static const chatFilesChanged = 'chat.files_changed';
  static const chatToolCall = 'chat.tool_call';
  static const chatToolCalls = 'chat.tool_calls';
  static const chatToolCallCompleted = 'chat.tool_call_completed';
  static const chatToolCallsCompleted = 'chat.tool_calls_completed';
  static const chatMoreFailed = 'chat.more_failed';

  static const toolTask = 'tool.task';
  static const toolSubagentTrace = 'tool.subagent_trace';
  static const toolInput = 'tool.input';
  static const toolOutput = 'tool.output';
  static const toolLocations = 'tool.locations';
  static const toolDiffs = 'tool.diffs';
  static const toolToolCalls = 'tool.tool_calls';
  static const toolToolExecution = 'tool.tool_execution';
  static const toolFileRead = 'tool.file_read';
  static const toolFileEdit = 'tool.file_edit';
  static const toolSearch = 'tool.search';
  static const toolFetch = 'tool.fetch';
  static const toolDelete = 'tool.delete';
  static const toolMove = 'tool.move';
  static const toolReasoning = 'tool.reasoning';
  static const toolModeChange = 'tool.mode_change';
  static const toolToolDetail = 'tool.tool_detail';
  static const toolCommand = 'tool.command';
  static const toolPath = 'tool.path';
  static const toolPattern = 'tool.pattern';
  static const toolUrl = 'tool.url';
  static const toolMode = 'tool.mode';
  static const toolGenericInput = 'tool.generic_input';
  static const toolGenericTool = 'tool.generic_tool';
  static const toolBash = 'tool.bash';
  static const toolRead = 'tool.read';
  static const toolEdit = 'tool.edit';
  static const toolThink = 'tool.think';
  static const toolSwitchMode = 'tool.switch_mode';
  static const toolKindRun = 'tool.kind_run';
  static const toolKindRead = 'tool.kind_read';
  static const toolKindEdit = 'tool.kind_edit';
  static const toolKindSearch = 'tool.kind_search';
  static const toolKindFetch = 'tool.kind_fetch';
  static const toolKindDelete = 'tool.kind_delete';
  static const toolKindMove = 'tool.kind_move';
  static const toolKindThink = 'tool.kind_think';
  static const toolKindMode = 'tool.kind_mode';
  static const toolKindTool = 'tool.kind_tool';
  static const toolFailedCaps = 'tool.failed_caps';
  static const toolRunningCaps = 'tool.running_caps';
  static const toolDoneCaps = 'tool.done_caps';
  static const toolToolsCaps = 'tool.tools_caps';

  static bool get isZh => Get.locale?.languageCode.toLowerCase() == 'zh';

  static String params(String key, Map<String, String> params) {
    return key.trParams(params);
  }

  static String connectedTo(String machine) {
    return settingsConnectedTo.trParams({'machine': machine});
  }

  static String connectionFailed(Object error) {
    return settingsConnectionFailed.trParams({'error': error.toString()});
  }

  static String scanParseFailedWith(Object error) {
    return scanParseFailed.trParams({'error': error.toString()});
  }

  static String authCheckFailedWith(Object error) {
    return authCheckFailed.trParams({'error': error.toString()});
  }

  static String authApproveFailedWith(Object error) {
    return authApproveFailed.trParams({'error': error.toString()});
  }

  static String sttStartRecordingFailedWith(Object error) {
    return sttStartRecordingFailed.trParams({'error': error.toString()});
  }

  static String transcriptionFailed(Object error) {
    return newTranscriptionFailed.trParams({'error': error.toString()});
  }

  static String chatRestoreErrorWith(String message) {
    return chatRestoreError.trParams({'message': message});
  }

  static String previewingFileChanges(int index, int count) {
    return chatPreviewingFileChanges.trParams({
      'index': index.toString(),
      'count': count.toString(),
    });
  }

  static String moreFileChanges(int count) {
    final key = count == 1 ? chatMoreFileChange : chatMoreFileChanges;
    return key.trParams({'count': count.toString()});
  }

  static String showMoreLines(int count) {
    final key = count == 1 ? chatShowMoreLine : chatShowMoreLines;
    return key.trParams({'count': count.toString()});
  }

  static String filesChanged(int count) {
    final key = count == 1 ? chatFileChanged : chatFilesChanged;
    return key.trParams({'count': count.toString()});
  }

  static String toolCalls(int count) {
    final key = count == 1 ? chatToolCall : chatToolCalls;
    return key.trParams({'count': count.toString()});
  }

  static String toolCallsCompleted(int count) {
    final key = count == 1 ? chatToolCallCompleted : chatToolCallsCompleted;
    return key.trParams({'count': count.toString()});
  }

  static String moreFailed(int count) {
    return chatMoreFailed.trParams({'count': count.toString()});
  }

  static String compactAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) {
      return isZh ? '${diff.inDays}天' : '${diff.inDays}d';
    }
    if (diff.inHours > 0) {
      return isZh ? '${diff.inHours}小时' : '${diff.inHours}h';
    }
    if (diff.inMinutes > 0) {
      return isZh ? '${diff.inMinutes}分钟' : '${diff.inMinutes}m';
    }
    return commonNow.tr;
  }

  static String relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return commonJustNow.tr;
    if (diff.inMinutes < 60) {
      return isZh ? '${diff.inMinutes}分钟前' : '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return isZh
          ? '${diff.inHours}小时前'
          : '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays == 1) return commonYesterday.tr;
    if (diff.inDays < 7) {
      return isZh ? '${diff.inDays}天前' : '${diff.inDays} days ago';
    }
    if (diff.inDays < 14) return commonLastWeek.tr;
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return isZh ? '$weeks周前' : '$weeks weeks ago';
    }
    return commonLastMonth.tr;
  }

  static String historyGroupLabel(DateTime dt, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return historyToday.tr;
    if (day == yesterday) return historyYesterday.tr;
    if (today.difference(day).inDays <= 7) return historyLastWeek.tr;
    if (day.year == now.year) return formatMonthDay(dt);
    return formatMonthDayYear(dt);
  }

  static String formatMonthDay(DateTime dt) {
    if (isZh) {
      return '${dt.month}月${dt.day}日';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  static String formatMonthDayYear(DateTime dt) {
    if (isZh) {
      return '${dt.year}年${dt.month}月${dt.day}日';
    }
    return '${formatMonthDay(dt)}, ${dt.year}';
  }
}
