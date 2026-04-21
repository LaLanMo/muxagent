import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/domain/approval.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/ui/chat/widgets/permission_card.dart';

import '../../../support/localization_test_utils.dart';

void main() {
  setUp(registerTestTranslations);

  testWidgets('permission card shows approval title and hides cwd line', (
    tester,
  ) async {
    final approval = ApprovalRequest(
      id: 'approval-1',
      sessionId: 'session-1',
      title: 'Run command',
      bodyText: 'This action needs confirmation.',
      command: const ApprovalCommand(argv: ['ls', '-la'], display: 'ls -la'),
      cwd: '/Users/by/project',
      options: const [
        PermOption(
          optionId: 'allow-once',
          kind: PermOptionKind.allowOnce,
          name: 'Allow',
        ),
        PermOption(
          optionId: 'allow-always',
          kind: PermOptionKind.allowAlways,
          name: 'Always',
        ),
        PermOption(
          optionId: 'reject-once',
          kind: PermOptionKind.rejectOnce,
          name: 'Deny',
        ),
      ],
      createdAt: DateTime(2026, 4, 13),
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: PermissionCard(approval: approval, onReply: (_) {}),
        ),
      ),
    );

    expect(find.text('Run command'), findsOneWidget);
    expect(find.text('Permission Required'), findsNothing);
    expect(find.text('cwd: /Users/by/project'), findsNothing);
    expect(find.text('ls -la'), findsOneWidget);
  });
}
