import 'package:flutter_test/flutter_test.dart';

import 'package:muxagent/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const MuxAgentApp());
    expect(find.text('MuxAgent'), findsOneWidget);
  });
}
