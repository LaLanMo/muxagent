import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/domain/approval.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/ui/chat/widgets/plan_approval_card.dart';

Finder _findRenderedText(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is RichText) {
      return widget.text.toPlainText().contains(text);
    }
    if (widget is Text) {
      final data = widget.data ?? widget.textSpan?.toPlainText();
      return data?.contains(text) ?? false;
    }
    return false;
  });
}

void main() {
  testWidgets('plan approval card renders markdown content directly', (
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

    expect(_findRenderedText('Review Plan'), findsWidgets);
    expect(_findRenderedText('ACP Client Transport Refactor'), findsWidgets);
    expect(_findRenderedText('Extract JSON-RPC protocol into module'), findsWidgets);
    expect(_findRenderedText('Yes, auto-accept edits'), findsWidgets);
    expect(_findRenderedText('Yes, manually approve edits'), findsWidgets);
    expect(_findRenderedText('No, keep planning'), findsWidgets);
  });

  testWidgets('plan approval card renders markdown tables', (tester) async {
    final approval = ApprovalRequest(
      id: 'approval-table',
      sessionId: 'session-1',
      title: 'Review plan',
      planMarkdown: '''
| Runtime | Access |
| --- | --- |
| Codex | Full |
| Claude Code | Restricted |
''',
      options: const [
        PermOption(
          optionId: 'allow',
          kind: PermOptionKind.allowOnce,
          name: 'Allow',
        ),
      ],
      createdAt: DateTime(2026, 4, 14),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanApprovalCard(approval: approval, onReply: (_) {}),
        ),
      ),
    );

    expect(_findRenderedText('Runtime'), findsWidgets);
    expect(_findRenderedText('Access'), findsWidgets);
    expect(_findRenderedText('Codex'), findsWidgets);
    expect(_findRenderedText('Full'), findsWidgets);
    expect(_findRenderedText('Claude Code'), findsWidgets);
    expect(_findRenderedText('Restricted'), findsWidgets);
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

    expect(_findRenderedText('Ready to code?'), findsNothing);
    expect(_findRenderedText('Allow'), findsNothing);
    expect(_findRenderedText('Do the thing'), findsWidgets);
  });
}
