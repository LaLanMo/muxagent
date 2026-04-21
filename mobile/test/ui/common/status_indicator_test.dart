import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/config/theme.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/ui/common/status_indicator.dart';

import '../../support/localization_test_utils.dart';

void main() {
  testWidgets('awaiting status indicator stays single-line with stable width', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: const Scaffold(
          body: Center(
            child: StatusIndicator(
              label: 'awaiting',
              color: AppTheme.warning,
              backgroundColor: AppTheme.warningBg,
            ),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.minWidth == 66 &&
            widget.alignment == Alignment.center,
      ),
    );
    final label = tester.widget<Text>(find.text('awaiting'));

    expect(container.constraints?.minWidth, 66);
    expect(label.maxLines, 1);
    expect(label.softWrap, isFalse);
    expect(label.overflow, TextOverflow.ellipsis);
  });

  testWidgets('session status indicators keep a fixed shared width', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusIndicator.sessionStatus(SessionStatus.running),
              SizedBox(width: 8),
              StatusIndicator.sessionStatus(SessionStatus.waitingApproval),
            ],
          ),
        ),
      ),
    );

    final runningSize = tester.getSize(
      find
          .ancestor(of: find.text('running'), matching: find.byType(Container))
          .first,
    );
    final awaitingSize = tester.getSize(
      find
          .ancestor(of: find.text('awaiting'), matching: find.byType(Container))
          .first,
    );

    expect(runningSize.width, 72);
    expect(awaitingSize.width, 72);
  });
}
