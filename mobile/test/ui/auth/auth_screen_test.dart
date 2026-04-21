import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/models/auth_request.dart';
import 'package:muxagent/data/repositories/auth_repository.dart';
import 'package:muxagent/data/repositories/paired_machine_repository.dart';
import 'package:muxagent/data/services/api/relay_service.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/ui/auth/auth_screen.dart';
import 'package:muxagent/ui/auth/auth_viewmodel.dart';

import '../../support/localization_test_utils.dart';

class _NoopAuthRepository extends AuthRepository {
  _NoopAuthRepository()
    : super(
        api: RelayService(),
        crypto: CryptoService(),
        machines: PairedMachineRepository(),
      );
}

class _TestAuthViewModel extends AuthViewModel {
  final AuthRequest request;
  final AuthState initialState;
  final String? initialHostname;
  final String? initialError;

  _TestAuthViewModel({
    required this.request,
    required this.initialState,
    this.initialHostname,
    this.initialError,
  }) : super(authRepository: _NoopAuthRepository());

  @override
  // ignore: must_call_super
  void onInit() {
    authRequest = request;
    machineHostname.value = initialHostname;
    errorMessage.value = initialError;
    state.value = initialState;
  }

  @override
  Future<void> approve() async {
    state.value = AuthState.approved;
  }

  @override
  void done() {}

  @override
  void cancel() {}

  @override
  void retry() {
    state.value = AuthState.pending;
  }
}

void main() {
  group('AuthScreen', () {
    setUp(() {
      registerTestTranslations();
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('renders the v2 pending pairing layout', (tester) async {
      Get.put<AuthViewModel>(
        _TestAuthViewModel(
          request: AuthRequest(
            id: 'req-1',
            relayUrl: 'https://relay.muxagent.com:8080',
          ),
          initialState: AuthState.pending,
          initialHostname: 'dev-macbook.local',
        ),
      );

      await tester.pumpWidget(localizedTestApp(child: const AuthScreen()));
      await tester.pump();

      expect(find.text('Pair Machine'), findsOneWidget);
      expect(find.text('Machine Found'), findsOneWidget);
      expect(find.text('MACHINE DETAILS'), findsOneWidget);
      expect(find.text('Pair This Machine'), findsOneWidget);
      expect(find.text('dev-macbook.local'), findsNWidgets(2));
    });

    testWidgets('renders the approved state action', (tester) async {
      Get.put<AuthViewModel>(
        _TestAuthViewModel(
          request: AuthRequest(
            id: 'req-1',
            relayUrl: 'https://relay.muxagent.com',
          ),
          initialState: AuthState.approved,
          initialHostname: 'dev-macbook.local',
        ),
      );

      await tester.pumpWidget(localizedTestApp(child: const AuthScreen()));
      await tester.pump();

      expect(find.text('Machine Paired'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('renders the error retry shell', (tester) async {
      Get.put<AuthViewModel>(
        _TestAuthViewModel(
          request: AuthRequest(
            id: 'req-1',
            relayUrl: 'https://relay.muxagent.com',
          ),
          initialState: AuthState.error,
          initialError: 'Relay timeout',
        ),
      );

      await tester.pumpWidget(localizedTestApp(child: const AuthScreen()));
      await tester.pump();

      expect(find.text('Pairing Failed'), findsOneWidget);
      expect(find.text('Relay timeout'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
