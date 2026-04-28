import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'package:muxagent/data/repositories/event_repository.dart';
import 'package:muxagent/data/repositories/paired_machine_repository.dart';
import 'package:muxagent/data/repositories/reconnect_recovery_coordinator.dart';
import 'package:muxagent/data/repositories/session_chat_cache_repository.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/message.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/main.dart' as app;
import 'package:muxagent/routing/routes.dart';
import 'package:muxagent/ui/auth/auth_viewmodel.dart';
import 'package:muxagent/ui/chat/chat_viewmodel.dart';
import 'package:muxagent/ui/new_session/new_session_viewmodel.dart';
import 'package:muxagent/ui/welcome/welcome_viewmodel.dart';

const _authUrl = String.fromEnvironment('MUXAGENT_AUTH_URL');
const _cwd = String.fromEnvironment('MUXAGENT_E2E_CWD');
const _runtime = String.fromEnvironment(
  'MUXAGENT_E2E_RUNTIME',
  defaultValue: 'codex',
);
const _prompt = 'mobile e2e permission prompt';
const _loadReplayMarker = 'History: replayed message';
const _runFinishedMarker = 'Done!';
const _missingE2eConfig = _authUrl == '' || _cwd == '';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'pairs, prompts, approves, and reopens via session.load',
    (tester) async {
      await app.main();
      await tester.pump();

      await _pairIfNeeded(tester);
      await _waitForHome(tester);

      final machineRepo = Get.find<PairedMachineRepository>();
      await machineRepo.refresh();
      await _waitUntil(
        tester,
        () => machineRepo.machines.isNotEmpty,
        timeout: const Duration(minutes: 2),
        description: 'paired machine to be stored',
      );
      final machine = machineRepo.machines.first;
      await _ensureMachineSession(tester, machine);

      Get.toNamed(Routes.newSession);
      await tester.pump();
      await _waitUntil(
        tester,
        () => Get.isRegistered<NewSessionViewModel>(),
        description: 'new session view model',
      );
      final newSession = Get.find<NewSessionViewModel>();
      await _waitUntil(
        tester,
        () =>
            newSession.selectedMachine.value != null &&
            !newSession.isLoadingRuntimes.value &&
            newSession.availableRuntimes.any((item) => item.id == _runtime),
        timeout: const Duration(minutes: 2),
        description: 'runtime list containing $_runtime',
      );

      final runtime = newSession.availableRuntimes.firstWhere(
        (item) => item.id == _runtime,
      );
      newSession.selectRuntime(runtime);
      newSession.cwdController.text = _cwd;
      newSession.promptController.text = _prompt;
      await newSession.startSession();
      await tester.pump();

      await _waitUntil(
        tester,
        () =>
            Get.currentRoute == Routes.chat &&
            Get.isRegistered<ChatViewModel>(),
        timeout: const Duration(minutes: 1),
        description: 'chat route after session.create',
      );
      final chat = Get.find<ChatViewModel>();
      final sessionId = chat.sessionId;
      expect(sessionId, isNotEmpty);

      await _waitUntil(
        tester,
        () => _messageText(chat.messages).contains(_prompt),
        timeout: const Duration(seconds: 30),
        description: 'optimistic user prompt',
      );
      await _waitUntil(
        tester,
        () => chat.approvals.isNotEmpty,
        timeout: const Duration(minutes: 2),
        description: 'approval request from prompt',
      );
      final approval = chat.approvals.values.first;
      expect(
        approval.options.map((option) => option.optionId),
        contains('once'),
      );
      await chat.replyApproval(approval.id, 'once');
      await tester.pump();

      await _waitUntil(
        tester,
        () =>
            _messageText(chat.messages).contains("I'll help you.") &&
            _messageText(chat.messages).contains('Done!') &&
            !chat.isPromptPending.value,
        timeout: const Duration(minutes: 2),
        description: 'prompt completion after approval',
      );
      await _waitUntil(
        tester,
        () =>
            Get.find<EventRepository>().sessionById(sessionId)?.status ==
            SessionStatus.idle,
        timeout: const Duration(minutes: 1),
        description: 'daemon session truth to return idle',
      );

      await chat.prepareForClose();
      expect(_messageText(chat.messages), isNot(contains(_loadReplayMarker)));
      final markedStale = await Get.find<SessionChatCacheRepository>()
          .markSessionCacheStale(sessionId);
      expect(markedStale, isTrue);
      final beforeLoadSeq = Get.find<EventRepository>().lastSeqFor(
        machine.machineId,
      );

      Get.offAllNamed(Routes.home);
      await tester.pump();
      await _waitUntil(
        tester,
        () => Get.currentRoute == Routes.home,
        description: 'home after leaving chat',
      );
      await _waitUntil(
        tester,
        () => !Get.isRegistered<ChatViewModel>(),
        description: 'previous chat view model disposal',
      );

      Get.toNamed(
        Routes.chat,
        arguments: {
          'sessionId': sessionId,
          'machineId': machine.machineId,
          'runtime': _runtime,
          'cwd': _cwd,
          'sessionTitle': '',
        },
      );
      await tester.pump();
      await _waitUntil(
        tester,
        () =>
            Get.currentRoute == Routes.chat &&
            Get.isRegistered<ChatViewModel>(),
        description: 'reopened chat route',
      );
      final reopened = Get.find<ChatViewModel>();
      await _waitUntil(
        tester,
        () =>
            reopened.uiMode.value == ChatUiMode.normal &&
            !reopened.isLoading.value &&
            _messageText(reopened.messages).contains(_loadReplayMarker),
        timeout: const Duration(minutes: 2),
        description: 'session.load replay to hydrate transcript',
      );
      expect(reopened.restoreUnavailableMessage.value, isEmpty);
      expect(_messageText(reopened.messages), contains('Hi there'));
      expect(
        Get.find<EventRepository>().lastSeqFor(machine.machineId),
        beforeLoadSeq,
      );

      await _exerciseCancelPending(tester, reopened);
      await _exercisePositiveSeqResync(tester, machine, reopened);
    },
    skip: _missingE2eConfig,
  );
}

Future<void> _exerciseCancelPending(
  WidgetTester tester,
  ChatViewModel chat,
) async {
  await _waitForIdleTruth(tester, chat.sessionId);

  await chat.sendMessage('mobile e2e cancel permission prompt');
  await tester.pump();
  await _waitUntil(
    tester,
    () => chat.approvals.isNotEmpty && chat.canCancelRun,
    timeout: const Duration(minutes: 2),
    description: 'cancelable approval state',
  );

  await chat.cancelSession();
  await tester.pump();
  expect(chat.isCancelingRun.value, isTrue);
  expect(chat.canPrompt, isFalse);
  expect(
    Get.find<EventRepository>().sessionById(chat.sessionId)?.status,
    isNot(SessionStatus.idle),
  );

  await _waitForIdleTruth(tester, chat.sessionId);
  await _waitUntil(
    tester,
    () => !chat.isCancelingRun.value && chat.canPrompt,
    timeout: const Duration(minutes: 1),
    description: 'cancel pending cleared by daemon truth',
  );
}

Future<void> _exercisePositiveSeqResync(
  WidgetTester tester,
  PairedMachine machine,
  ChatViewModel chat,
) async {
  await _waitForIdleTruth(tester, chat.sessionId);
  final eventRepo = Get.find<EventRepository>();
  final wsRepo = Get.find<WsSessionRepository>();
  final recovery = Get.find<ReconnectRecoveryCoordinator>();
  final beforeSeq = eventRepo.lastSeqFor(machine.machineId);
  final beforeFinishedCount = _occurrences(
    _messageText(chat.messages),
    _runFinishedMarker,
  );

  await chat.sendMessage('mobile e2e resync prompt');
  await tester.pump();
  await wsRepo.endSession(machine.machineId);
  await tester.pump();
  await Future<void>.delayed(const Duration(seconds: 2));
  expect(
    _occurrences(_messageText(chat.messages), _runFinishedMarker),
    beforeFinishedCount,
  );

  final result = await recovery.recoverMachine(machine.machineId);
  expect(result.transcript, TranscriptRecoveryState.complete);
  expect(result.sessionReady, isTrue);
  await _waitUntil(
    tester,
    () =>
        eventRepo.lastSeqFor(machine.machineId) > beforeSeq &&
        _occurrences(_messageText(chat.messages), _runFinishedMarker) >
            beforeFinishedCount,
    timeout: const Duration(minutes: 1),
    description: 'positive seq resync applied missed events',
  );
  await _waitForIdleTruth(tester, chat.sessionId);
}

Future<void> _pairIfNeeded(WidgetTester tester) async {
  await _waitUntil(
    tester,
    () => Get.currentRoute == Routes.welcome || Get.currentRoute == Routes.home,
    timeout: const Duration(minutes: 2),
    description: 'startup route resolution',
  );

  if (Get.currentRoute != Routes.welcome) {
    return;
  }
  if (_authUrl.isEmpty) {
    throw StateError(
      'MUXAGENT_AUTH_URL is required when app starts on Welcome',
    );
  }

  await _waitUntil(
    tester,
    () => Get.isRegistered<WelcomeViewModel>(),
    description: 'welcome view model',
  );
  final welcome = Get.find<WelcomeViewModel>();
  welcome.urlController.text = _authUrl;
  welcome.onManualConnect();
  await tester.pump();

  await _waitUntil(
    tester,
    () => Get.isRegistered<AuthViewModel>(),
    description: 'auth view model',
  );
  final auth = Get.find<AuthViewModel>();
  await _waitUntil(
    tester,
    () =>
        auth.state.value == AuthState.pending ||
        auth.state.value == AuthState.approved,
    timeout: const Duration(minutes: 2),
    description: 'auth request pending or already approved',
  );
  if (auth.state.value == AuthState.pending) {
    await auth.approve();
    await tester.pump();
  }

  await _waitUntil(
    tester,
    () => auth.state.value == AuthState.approved,
    timeout: const Duration(minutes: 2),
    description: 'auth approval',
  );
  auth.done();
  await tester.pump();
}

Future<void> _waitForHome(WidgetTester tester) async {
  await _waitUntil(
    tester,
    () => Get.currentRoute == Routes.home,
    timeout: const Duration(minutes: 3),
    description: 'home route',
  );
}

Future<void> _ensureMachineSession(
  WidgetTester tester,
  PairedMachine machine,
) async {
  final wsRepo = Get.find<WsSessionRepository>();
  await _waitUntil(
    tester,
    () async {
      try {
        await wsRepo.ensureConnected(relayHttpUrl: machine.relayHttpUrl);
        if (!wsRepo.hasSession(machine.machineId)) {
          await wsRepo
              .startSession(machine: machine)
              .timeout(const Duration(seconds: 8));
        }
        return wsRepo.hasSession(machine.machineId) ||
            wsRepo.activeSessionIds.contains(machine.machineId);
      } catch (_) {
        return false;
      }
    },
    timeout: const Duration(minutes: 3),
    description: 'relay session for paired machine',
  );
}

String _messageText(Iterable<Message> messages) {
  final buffer = StringBuffer();
  for (final message in messages) {
    for (final part in message.parts) {
      final text = part.text;
      if (text != null && text.isNotEmpty) {
        buffer.write(text);
      }
    }
    buffer.write('\n');
  }
  return buffer.toString();
}

int _occurrences(String text, String needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var start = 0;
  while (true) {
    final index = text.indexOf(needle, start);
    if (index < 0) return count;
    count++;
    start = index + needle.length;
  }
}

Future<void> _waitForIdleTruth(WidgetTester tester, String sessionId) async {
  await _waitUntil(
    tester,
    () =>
        Get.find<EventRepository>().sessionById(sessionId)?.status ==
        SessionStatus.idle,
    timeout: const Duration(minutes: 1),
    description: 'daemon session truth idle',
  );
}

Future<void> _waitUntil(
  WidgetTester tester,
  FutureOr<bool> Function() predicate, {
  Duration timeout = const Duration(seconds: 30),
  String description = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (await predicate()) {
      return;
    }
  }
  throw TimeoutException('Timed out waiting for $description after $timeout');
}
