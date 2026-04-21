import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/domain/event.dart';
import 'package:muxagent/domain/message.dart';
import 'package:muxagent/domain/tool_activity.dart';
import 'package:muxagent/ui/tool_detail/tool_detail_screen.dart';
import 'package:muxagent/ui/tool_detail/tool_detail_viewmodel.dart';

import '../../support/localization_test_utils.dart';

class _TestToolDetailViewModel extends ToolDetailViewModel {
  _TestToolDetailViewModel({
    required ToolActivity seededTool,
    required List<ToolActivity> seededChildTools,
  }) : super(messages: <Message>[].obs) {
    tool = seededTool;
    childTools = seededChildTools;
  }

  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  group('ToolDetailScreen', () {
    setUp(registerTestTranslations);
    tearDown(Get.reset);

    testWidgets('renders the v2 subagent summary and tool list', (
      tester,
    ) async {
      final tool = ToolActivity(
        id: 'tool-1',
        name: 'task',
        kind: ToolKind.think.value,
        title: 'Exploring auth module patterns',
        status: ToolStatus.completed,
        input: const ToolInputInfo(description: 'Investigate auth module'),
        output: 'Found the relevant files and summarized the auth flow.',
      );

      final childTools = [
        ToolActivity(
          id: 'child-1',
          name: 'search',
          kind: ToolKind.search.value,
          title: 'AuthMiddleware',
          status: ToolStatus.completed,
        ),
        ToolActivity(
          id: 'child-2',
          name: 'read',
          kind: ToolKind.read.value,
          title: 'src/auth/middleware.ts',
          status: ToolStatus.completed,
        ),
      ];

      Get.put<ToolDetailViewModel>(
        _TestToolDetailViewModel(
          seededTool: tool,
          seededChildTools: childTools,
        ),
      );

      await tester.pumpWidget(
        localizedTestApp(child: const ToolDetailScreen()),
      );
      await tester.pump();

      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Exploring auth module patterns'), findsOneWidget);
      expect(find.text('2 tool calls completed'), findsOneWidget);
      expect(find.text('TOOL CALLS'), findsOneWidget);
      expect(find.text('AuthMiddleware'), findsOneWidget);
      expect(find.text('src/auth/middleware.ts'), findsOneWidget);
    });
  });
}
