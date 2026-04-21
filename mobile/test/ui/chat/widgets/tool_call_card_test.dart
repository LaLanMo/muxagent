import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/event.dart';
import 'package:muxagent/domain/tool_activity.dart';
import 'package:muxagent/ui/chat/widgets/edit_diff_view.dart';
import 'package:muxagent/ui/chat/widgets/tool_call_card.dart';

import '../../../support/localization_test_utils.dart';

void main() {
  setUp(registerTestTranslations);

  testWidgets('edit tool card renders ACP diff content without input.edit', (
    tester,
  ) async {
    final tool = ToolActivity(
      id: 'tool-1',
      name: 'Edit /workspace/file.txt',
      kind: ToolKind.edit.value,
      status: ToolStatus.completed,
      diffs: [
        ToolDiff(
          path: '/workspace/file.txt',
          oldText: 'before',
          newText: 'after',
        ),
      ],
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(body: ToolCallCard(tool: tool)),
      ),
    );

    expect(find.byType(EditDiffView), findsOneWidget);
    expect(find.textContaining('Edit /workspace/file.txt'), findsOneWidget);
    expect(
      tester.widget<EditDiffView>(find.byType(EditDiffView)).maxCollapsedLines,
      5,
    );
  });

  testWidgets('chat preview only renders the first ACP diff block', (
    tester,
  ) async {
    final tool = ToolActivity(
      id: 'tool-2',
      name: 'Edit multiple files',
      kind: ToolKind.edit.value,
      status: ToolStatus.completed,
      diffs: [
        ToolDiff(
          path: '/workspace/file_a.txt',
          oldText: 'before a',
          newText: 'after a',
        ),
        ToolDiff(
          path: '/workspace/file_b.txt',
          oldText: 'before b',
          newText: 'after b',
        ),
      ],
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(body: ToolCallCard(tool: tool)),
      ),
    );

    expect(find.byType(EditDiffView), findsOneWidget);
    expect(find.text('Previewing 1 of 2 file changes'), findsOneWidget);
    expect(find.text('+1 more file change in details'), findsOneWidget);
  });

  testWidgets('completed read tool uses status badge and compact home path', (
    tester,
  ) async {
    final tool = ToolActivity(
      id: 'tool-3',
      name: 'Read',
      kind: ToolKind.read.value,
      status: ToolStatus.completed,
      input: const ToolInputInfo(filePath: '/Users/by/project/lib/file.dart'),
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(body: ToolCallCard(tool: tool)),
      ),
    );

    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('~/project/lib/file.dart'), findsOneWidget);
  });
}
