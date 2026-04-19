import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/bindings/startup_binding.dart';
import 'package:muxagent/data/models/auth_request.dart';
import 'package:muxagent/data/repositories/paired_machine_repository.dart';
import 'package:muxagent/data/services/pairing_deep_link_coordinator.dart';
import 'package:muxagent/domain/paired_machine.dart';
import 'package:muxagent/routing/routes.dart';
import 'package:muxagent/ui/startup/startup_screen.dart';

import '../../support/fake_paired_machine_repository.dart';
import '../../support/fake_pairing_deep_link_coordinator.dart';

class _FakePairingLinkSource implements PairingLinkSource {
  _FakePairingLinkSource({this.initialUri});

  final Uri? initialUri;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialUri() async => initialUri;

  @override
  Stream<Uri> get uriStream => _controller.stream;

  Future<void> dispose() async {
    await _controller.close();
  }
}

PairedMachine _buildMachine(String machineId) {
  return PairedMachine(
    machineId: machineId,
    relayHttpUrl: 'https://relay.test',
    machineSignPubB64: 'sign-$machineId',
    machineEncPubB64: 'enc-$machineId',
    hostname: 'host-$machineId',
  );
}

Future<void> _pumpStartupApp(
  WidgetTester tester, {
  required PairingDeepLinkCoordinator coordinator,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: Routes.startup,
      getPages: [
        GetPage(
          name: Routes.startup,
          page: () => const StartupScreen(),
          binding: StartupBinding(),
        ),
        GetPage(
          name: Routes.home,
          page: () => const Scaffold(body: Text('home')),
        ),
        GetPage(
          name: Routes.welcome,
          page: () => const Scaffold(body: Text('welcome')),
        ),
        GetPage(
          name: Routes.auth,
          page: () => const Scaffold(body: Text('auth')),
        ),
      ],
      routingCallback: (routing) {
        coordinator.onRouteChanged(routing?.current);
      },
    ),
  );
  await tester.pump();
  coordinator.onNavigatorReady();
  await tester.pump();
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('routes startup auth deeplinks to auth', (tester) async {
    final source = _FakePairingLinkSource(
      initialUri: Uri.parse(
        'muxagent://auth?id=req-startup-123&relay=https%3A%2F%2Frelay.test',
      ),
    );
    final coordinator = PairingDeepLinkCoordinator(
      source: source,
      parser: const AuthRequestPairingLinkParser(),
    );
    await coordinator.start();
    Get.put<PairedMachineRepository>(FakePairedMachineRepository());
    Get.put<PairingDeepLinkCoordinator>(coordinator);

    await _pumpStartupApp(tester, coordinator: coordinator);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.auth);
    expect(find.text('auth'), findsOneWidget);

    await source.dispose();
  });

  testWidgets('routes empty machine catalogs to welcome', (tester) async {
    final source = _FakePairingLinkSource();
    final coordinator = PairingDeepLinkCoordinator(
      source: source,
      parser: const AuthRequestPairingLinkParser(),
    );
    await coordinator.start();
    Get.put<PairedMachineRepository>(FakePairedMachineRepository());
    Get.put<PairingDeepLinkCoordinator>(coordinator);

    await _pumpStartupApp(tester, coordinator: coordinator);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.welcome);
    expect(find.text('welcome'), findsOneWidget);

    await source.dispose();
  });

  testWidgets('routes known machines to home', (tester) async {
    final source = _FakePairingLinkSource();
    final coordinator = PairingDeepLinkCoordinator(
      source: source,
      parser: const AuthRequestPairingLinkParser(),
    );
    await coordinator.start();
    Get.put<PairedMachineRepository>(
      FakePairedMachineRepository([_buildMachine('machine-1')]),
    );
    Get.put<PairingDeepLinkCoordinator>(coordinator);

    await _pumpStartupApp(tester, coordinator: coordinator);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.home);
    expect(find.text('home'), findsOneWidget);

    await source.dispose();
  });

  testWidgets(
    'waits for the deeplink blocking window to clear before routing empty catalogs to welcome',
    (tester) async {
      final coordinator = FakePairingDeepLinkCoordinator(
        blockingWelcomeRedirect: true,
      );
      Get.put<PairedMachineRepository>(FakePairedMachineRepository());
      Get.put<PairingDeepLinkCoordinator>(coordinator);

      await _pumpStartupApp(tester, coordinator: coordinator);
      await tester.pump();

      expect(Get.currentRoute, Routes.startup);

      coordinator.setBlockingWelcomeRedirect(false);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(Get.currentRoute, Routes.welcome);
      expect(find.text('welcome'), findsOneWidget);

      coordinator.dispose();
    },
  );
}
