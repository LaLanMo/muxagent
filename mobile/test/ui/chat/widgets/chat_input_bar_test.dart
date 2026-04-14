import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/domain/enums.dart';
import 'package:muxagent/ui/chat/widgets/chat_input_bar.dart';

void main() {
  testWidgets('chat input uses newline action instead of send', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(
            controller: controller,
            sessionStatus: SessionStatus.idle,
            onSend: () {},
            onCancel: () {},
            onAttach: () {},
            imagePreviews: const [],
            onRemoveImage: (_) {},
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));

    expect(textField.keyboardType, TextInputType.multiline);
    expect(textField.textInputAction, TextInputAction.newline);
    expect(textField.onSubmitted, isNull);
  });
}
