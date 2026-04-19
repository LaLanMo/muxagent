import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'package:muxagent/main.dart' as app;
import 'package:muxagent/routing/routes.dart';
import 'package:muxagent/ui/attach_session/attach_session_viewmodel.dart';
import 'package:muxagent/ui/auth/auth_viewmodel.dart';
import 'package:muxagent/ui/welcome/welcome_viewmodel.dart';

const _authUrl = String.fromEnvironment('MUXAGENT_AUTH_URL');
const _attachSessionId = String.fromEnvironment('MUXAGENT_ATTACH_SESSION_ID');
const _attachCwd = String.fromEnvironment('MUXAGENT_ATTACH_CWD');
const _missingAttachConfig = _attachSessionId == '' || _attachCwd == '';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pairs the app and attaches an existing session', (
    tester,
  ) async {
    await app.main();
    await tester.pump();

    await _waitForAny(tester, <Finder>[
      find.text('MuxAgent'),
      find.bySemanticsLabel('New Session'),
    ]);

    if (find.text('MuxAgent').evaluate().isNotEmpty) {
      if (_authUrl.isEmpty) {
        throw StateError(
          'MUXAGENT_AUTH_URL is required when the app starts on Welcome',
        );
      }
      final welcomeViewModel = Get.find<WelcomeViewModel>();
      welcomeViewModel.urlController.text = _authUrl;
      welcomeViewModel.onManualConnect();
      await tester.pump();

      await _waitFor(tester, find.text('Pair This Machine'));
      await tester.pump(const Duration(seconds: 1));
      final authViewModel = Get.find<AuthViewModel>();
      await authViewModel.approve();
      await tester.pump();

      await _waitUntil(
        tester,
        () => authViewModel.state.value == AuthState.approved,
        timeout: const Duration(minutes: 2),
      );
      await _waitFor(
        tester,
        find.text('Machine Paired'),
        timeout: const Duration(minutes: 2),
      );
      await tester.pump(const Duration(seconds: 1));
      authViewModel.done();
      await tester.pump();
    }

    await _waitFor(tester, find.bySemanticsLabel('New Session'));
    await tester.pump(const Duration(seconds: 1));
    Get.toNamed(Routes.newSession);
    await tester.pump();

    await _waitFor(tester, find.bySemanticsLabel('Attach an existing session'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.bySemanticsLabel('Attach an existing session'));
    await tester.pump();

    await _waitFor(tester, find.text('Use the session ID from your runtime'));
    final attachViewModel = Get.find<AttachSessionViewModel>();
    await _waitUntil(
      tester,
      () =>
          find.text('Loading runtimes...').evaluate().isEmpty &&
          attachViewModel.selectedMachine.value != null &&
          attachViewModel.selectedRuntime.value != null,
      timeout: const Duration(minutes: 2),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, _attachSessionId);
    await tester.pump();

    await tester.tap(find.text('Attach Session').last);
    await tester.pump();
    await _waitFor(
      tester,
      find.byType(CircularProgressIndicator),
      timeout: const Duration(seconds: 15),
    );

    await _waitUntil(
      tester,
      () =>
          find
              .text('Use the session ID from your runtime')
              .evaluate()
              .isEmpty &&
          find.text('New Session').evaluate().isEmpty,
      timeout: const Duration(minutes: 2),
    );

    expect(find.textContaining(_attachCwd), findsWidgets);
  }, skip: _missingAttachConfig);
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  await _waitUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    timeout: timeout,
  );
}

Future<void> _waitForAny(WidgetTester tester, List<Finder> finders) async {
  await _waitUntil(
    tester,
    () => finders.any((finder) => finder.evaluate().isNotEmpty),
  );
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (predicate()) {
      return;
    }
  }
  throw TimeoutException('Timed out after $timeout');
}

class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => message;
}
