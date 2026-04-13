import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/repositories/session_manager.dart';
import 'package:muxagent/data/repositories/ws_session_repository.dart';
import 'package:muxagent/data/services/local/crypto_service.dart';
import 'package:muxagent/data/services/ws/relay_ws_client.dart';
import 'package:muxagent/data/services/ws/token_service.dart';
import 'package:muxagent/domain/approval.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/ui/permission_detail/permission_detail_screen.dart';
import 'package:muxagent/ui/permission_detail/permission_detail_viewmodel.dart';

class _NoopRelayWsClient extends RelayWsClient {
  _NoopRelayWsClient()
    : super(
        crypto: CryptoService(),
        tokens: TokenService(crypto: CryptoService()),
        sessions: SessionManager(),
      );
}

class _FakeWsSessionRepository extends WsSessionRepository {
  _FakeWsSessionRepository()
    : super(relay: _NoopRelayWsClient(), sessions: SessionManager());

  String? repliedOptionId;

  @override
  Future<void> replyApproval({
    required String machineId,
    required String sessionId,
    required String requestId,
    required String optionId,
  }) async {
    repliedOptionId = optionId;
  }
}

class _TestPermissionDetailViewModel extends PermissionDetailViewModel {
  _TestPermissionDetailViewModel({
    required super.wsRepo,
    required ApprovalRequest seededApproval,
    required String seededMachineId,
    required String seededSessionId,
  }) {
    approval = seededApproval;
    machineId = seededMachineId;
    sessionId = seededSessionId;
  }

  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  group('PermissionDetailScreen', () {
    late _FakeWsSessionRepository wsRepo;

    setUp(() {
      Get.testMode = true;
      wsRepo = _FakeWsSessionRepository();
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('uses the fixed v2 header and hides extra description copy', (
      tester,
    ) async {
      final approval = ApprovalRequest(
        id: 'approval-1',
        sessionId: 'session-1',
        title: 'Run tests',
        reason: 'Agent wants to execute a shell command',
        command: const ApprovalCommand(
          argv: ['npm', 'run', 'test'],
          display: 'npm run test -- --coverage',
        ),
        options: const [
          PermOption(
            optionId: 'allow-once',
            kind: PermOptionKind.allowOnce,
            name: 'Allow',
          ),
          PermOption(
            optionId: 'allow-always',
            kind: PermOptionKind.allowAlways,
            name: 'Always Allow',
          ),
          PermOption(
            optionId: 'deny-once',
            kind: PermOptionKind.rejectOnce,
            name: 'Deny',
          ),
        ],
        createdAt: DateTime(2026, 4, 13),
      );

      Get.put<PermissionDetailViewModel>(
        _TestPermissionDetailViewModel(
          wsRepo: wsRepo,
          seededApproval: approval,
          seededMachineId: 'machine-1',
          seededSessionId: 'session-1',
        ),
      );

      await tester.pumpWidget(
        const GetMaterialApp(home: PermissionDetailScreen()),
      );
      await tester.pump();

      expect(find.text('Permission Request'), findsOneWidget);
      expect(find.text('npm run test -- --coverage'), findsOneWidget);
      expect(find.text('Agent wants to execute a shell command'), findsNothing);
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Always Allow'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
    });

    testWidgets('replies with the tapped approval option id', (tester) async {
      final approval = ApprovalRequest(
        id: 'approval-1',
        sessionId: 'session-1',
        title: 'Run tests',
        command: const ApprovalCommand(
          argv: ['npm', 'run', 'test'],
          display: 'npm run test -- --coverage',
        ),
        options: const [
          PermOption(
            optionId: 'allow-once',
            kind: PermOptionKind.allowOnce,
            name: 'Allow',
          ),
        ],
        createdAt: DateTime(2026, 4, 13),
      );

      Get.put<PermissionDetailViewModel>(
        _TestPermissionDetailViewModel(
          wsRepo: wsRepo,
          seededApproval: approval,
          seededMachineId: 'machine-1',
          seededSessionId: 'session-1',
        ),
      );

      await tester.pumpWidget(
        const GetMaterialApp(home: PermissionDetailScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();

      expect(wsRepo.repliedOptionId, 'allow-once');
    });
  });
}
