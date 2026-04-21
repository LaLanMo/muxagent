import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:muxagent/config/theme.dart';
import 'package:muxagent/ui/common/pill_tab_bar.dart';

import '../../support/localization_test_utils.dart';

void main() {
  testWidgets('pill tab bar exposes selected state and compose action', (
    tester,
  ) async {
    int? tappedIndex;
    var composeTapCount = 0;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          bottomNavigationBar: PillTabBar(
            currentIndex: 1,
            activeBadgeCount: 2,
            onTap: (index) => tappedIndex = index,
            onCreateTap: () => composeTapCount++,
          ),
        ),
      ),
    );

    final historyIcon = tester.widget<Icon>(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == LucideIcons.clock4,
      ),
    );
    final activeIcon = tester.widget<Icon>(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == LucideIcons.radio,
      ),
    );
    final composeIcon = tester.widget<Icon>(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == LucideIcons.pencil,
      ),
    );

    expect(historyIcon.color, AppTheme.textPrimary);
    expect(activeIcon.color, AppTheme.textTertiary);
    expect(composeIcon.color, AppTheme.accent);

    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pump();
    expect(tappedIndex, 2);

    await tester.tap(find.bySemanticsLabel('New Session'));
    await tester.pump();
    expect(composeTapCount, 1);
  });
}
