import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/domain/approval.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/ui/chat/widgets/plan_approval_card.dart';

void main() {
  testWidgets('plan approval card follows v2 title and steps structure', (
    tester,
  ) async {
    final approval = ApprovalRequest(
      id: 'approval-1',
      sessionId: 'session-1',
      title: 'Review plan',
      bodyText: 'Refactor the ACP client to use a pluggable transport layer.',
      planMarkdown: '''
ACP Client Transport Refactor

Refactor the ACP client to use a pluggable transport layer, separating the JSON-RPC protocol from the connection mechanism.

1. Extract JSON-RPC protocol into module
2. Create transport abstraction interface
3. Implement WebSocket transport adapter
''',
      options: const [
        PermOption(
          optionId: 'allow-always',
          kind: PermOptionKind.allowAlways,
          name: 'Yes, auto-accept edits',
        ),
        PermOption(
          optionId: 'allow-once',
          kind: PermOptionKind.allowOnce,
          name: 'Yes, manually approve edits',
        ),
        PermOption(
          optionId: 'reject',
          kind: PermOptionKind.rejectOnce,
          name: 'No, keep planning',
        ),
      ],
      createdAt: DateTime(2026, 4, 13),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanApprovalCard(approval: approval, onReply: (_) {}),
        ),
      ),
    );

    expect(find.text('Review Plan'), findsOneWidget);
    expect(find.text('ACP Client Transport Refactor'), findsOneWidget);
    expect(find.text('Steps:'), findsOneWidget);
    expect(find.text('Extract JSON-RPC protocol into module'), findsOneWidget);
    expect(find.text('Yes, auto-accept edits'), findsOneWidget);
    expect(find.text('Yes, manually approve edits'), findsOneWidget);
    expect(find.text('No, keep planning'), findsOneWidget);
  });

  testWidgets('resolved plan approval card hides action section', (
    tester,
  ) async {
    final approval = ApprovalRequest(
      id: 'approval-2',
      sessionId: 'session-1',
      title: 'Review plan',
      planMarkdown: '1. Do the thing',
      options: const [
        PermOption(
          optionId: 'allow-always',
          kind: PermOptionKind.allowAlways,
          name: 'Allow',
        ),
      ],
      createdAt: DateTime(2026, 4, 13),
      resolved: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanApprovalCard(approval: approval, onReply: (_) {}),
        ),
      ),
    );

    expect(find.text('Ready to code?'), findsNothing);
    expect(find.text('Allow'), findsNothing);
    expect(find.text('Do the thing'), findsOneWidget);
  });
}
