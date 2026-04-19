import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/models/auth_request.dart';
import 'package:muxagent/data/services/pairing_deep_link_coordinator.dart';
import 'package:muxagent/routing/routes.dart';

class _FakePairingLinkSource implements PairingLinkSource {
  _FakePairingLinkSource({this.initialUri});

  final Uri? initialUri;
  final _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialUri() async => initialUri;

  @override
  Stream<Uri> get uriStream => _controller.stream;

  void emit(Uri uri) {
    _controller.add(uri);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  setUp(() {
    Get.testMode = false;
  });

  tearDown(() async {
    await Get.deleteAll(force: true);
  });

  Future<void> pumpApp(
    WidgetTester tester,
    PairingDeepLinkCoordinator coordinator,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: [
          GetPage(
            name: Routes.home,
            page: () => const Scaffold(body: Text('home')),
          ),
          GetPage(
            name: Routes.auth,
            page: () => const Scaffold(body: Text('auth')),
          ),
          GetPage(
            name: Routes.welcome,
            page: () => const Scaffold(body: Text('welcome')),
          ),
        ],
        routingCallback: (routing) {
          coordinator.onRouteChanged(routing?.current);
        },
      ),
    );
    await tester.pump();
  }

  group('PairingDeepLinkCoordinator', () {
    test('normalizes iOS deeplink route callbacks to auth', () {
      final coordinator = PairingDeepLinkCoordinator(
        source: _FakePairingLinkSource(),
        parser: const AuthRequestPairingLinkParser(),
      );

      expect(
        coordinator.debugNormalizeObservedRoute(
          '/?id=req-123&relay=https://relay.test',
        ),
        Routes.auth,
      );
      expect(
        coordinator.debugNormalizeObservedRoute(
          '/auth?id=req-123&relay=https://relay.test',
        ),
        Routes.auth,
      );
    });

    test('reserves an initial deeplink for startup auth routing', () async {
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

      expect(coordinator.prepareStartupRoute(), isTrue);
      expect(coordinator.hasPendingPairingNavigation, isTrue);
      expect(coordinator.isBlockingWelcomeRedirect, isTrue);

      final request = coordinator.consumeStartupRouteRequest();
      expect(request?.id, 'req-startup-123');
      expect(request?.relayUrl, 'https://relay.test');
      expect(coordinator.prepareStartupRoute(), isFalse);

      await source.dispose();
    });

    testWidgets('holds a valid initial deeplink until navigator is ready', (
      tester,
    ) async {
      final source = _FakePairingLinkSource(
        initialUri: Uri.parse(
          'muxagent://auth?id=req-123&relay=https%3A%2F%2Frelay.test',
        ),
      );
      final coordinator = PairingDeepLinkCoordinator(
        source: source,
        parser: const AuthRequestPairingLinkParser(),
      );

      await coordinator.start();

      expect(coordinator.hasPendingPairingNavigation, isTrue);
      expect(coordinator.isBlockingWelcomeRedirect, isTrue);

      await pumpApp(tester, coordinator);

      coordinator.onNavigatorReady();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(Get.currentRoute, Routes.auth);
      await source.dispose();
    });

    testWidgets('dedupes repeated live delivery for the same request', (
      tester,
    ) async {
      final source = _FakePairingLinkSource();
      final coordinator = PairingDeepLinkCoordinator(
        source: source,
        parser: const AuthRequestPairingLinkParser(),
      );

      await coordinator.start();
      await pumpApp(tester, coordinator);
      coordinator.onNavigatorReady();
      await tester.pump();

      final uri = Uri.parse(
        'muxagent://auth?id=req-123&relay=https%3A%2F%2Frelay.test',
      );
      source.emit(uri);
      source.emit(uri);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(Get.currentRoute, Routes.auth);
      expect(find.text('auth'), findsOneWidget);

      await source.dispose();
    });

    testWidgets('ignores duplicate live delivery while already on auth', (
      tester,
    ) async {
      final source = _FakePairingLinkSource();
      final coordinator = PairingDeepLinkCoordinator(
        source: source,
        parser: const AuthRequestPairingLinkParser(),
      );
      var authRouteVisits = 0;

      await coordinator.start();
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: Routes.home,
          getPages: [
            GetPage(
              name: Routes.home,
              page: () => const Scaffold(body: Text('home')),
            ),
            GetPage(
              name: Routes.auth,
              page: () => const Scaffold(body: Text('auth')),
            ),
          ],
          routingCallback: (routing) {
            if (routing?.current == Routes.auth) {
              authRouteVisits += 1;
            }
            coordinator.onRouteChanged(routing?.current);
          },
        ),
      );
      await tester.pump();
      coordinator.onNavigatorReady();
      await tester.pump();

      final uri = Uri.parse(
        'muxagent://auth?id=req-123&relay=https%3A%2F%2Frelay.test',
      );
      source.emit(uri);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, Routes.auth);
      final visitsAfterFirstDelivery = authRouteVisits;
      expect(visitsAfterFirstDelivery, greaterThanOrEqualTo(1));

      source.emit(uri);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, Routes.auth);
      expect(authRouteVisits, visitsAfterFirstDelivery);

      await source.dispose();
    });

    testWidgets(
      'ignores duplicate live delivery when iOS reports deeplink query route',
      (tester) async {
        final source = _FakePairingLinkSource();
        final coordinator = PairingDeepLinkCoordinator(
          source: source,
          parser: const AuthRequestPairingLinkParser(),
        );
        var authRouteVisits = 0;

        await coordinator.start();
        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: Routes.home,
            getPages: [
              GetPage(
                name: Routes.home,
                page: () => const Scaffold(body: Text('home')),
              ),
              GetPage(
                name: Routes.auth,
                page: () => const Scaffold(body: Text('auth')),
              ),
            ],
            routingCallback: (routing) {
              if (routing?.current == Routes.auth) {
                authRouteVisits += 1;
              }
              coordinator.onRouteChanged(routing?.current);
            },
          ),
        );
        await tester.pump();
        coordinator.onNavigatorReady();
        await tester.pump();

        final uri = Uri.parse(
          'muxagent://auth?id=req-123&relay=https%3A%2F%2Frelay.test',
        );
        source.emit(uri);
        await tester.pumpAndSettle();
        expect(Get.currentRoute, Routes.auth);

        final visitsAfterFirstDelivery = authRouteVisits;
        coordinator.onRouteChanged('/?id=req-123&relay=https://relay.test');

        source.emit(uri);
        await tester.pumpAndSettle();

        expect(Get.currentRoute, Routes.auth);
        expect(authRouteVisits, visitsAfterFirstDelivery);

        await source.dispose();
      },
    );
  });
}
