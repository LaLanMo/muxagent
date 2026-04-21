import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:muxagent/data/models/auth_request.dart';
import 'package:muxagent/i18n/app_locales.dart';
import 'package:muxagent/ui/welcome/welcome_screen.dart';
import 'package:muxagent/ui/welcome/welcome_viewmodel.dart';

import '../../support/localization_test_utils.dart';

void main() {
  setUp(() {
    registerTestTranslations();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('welcome screen avoids overflow when keyboard is visible', (
    tester,
  ) async {
    Get.put(
      WelcomeViewModel(pairingLinkParser: const AuthRequestPairingLinkParser()),
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 320),
          ),
          child: const WelcomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MuxAgent'), findsOneWidget);
    final heroImage = tester.widget<Image>(find.byType(Image).first);
    expect(
      (heroImage.image as AssetImage).assetName,
      'assets/images/app_icon.png',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping outside the URL field dismisses the keyboard focus', (
    tester,
  ) async {
    Get.put(
      WelcomeViewModel(pairingLinkParser: const AuthRequestPairingLinkParser()),
    );

    await tester.pumpWidget(localizedTestApp(child: const WelcomeScreen()));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    await tester.tap(textField);
    await tester.pump();

    EditableText editableText = tester.widget(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(12, 12));
    await tester.pump();

    editableText = tester.widget(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isFalse);
  });

  test('manual connect maps parser failures to inline errors', () {
    final viewModel = WelcomeViewModel(
      pairingLinkParser: const AuthRequestPairingLinkParser(),
    );
    addTearDown(viewModel.onClose);

    viewModel.urlController.text = 'muxagent://auth?id=req-123';
    viewModel.onManualConnect();

    expect(
      viewModel.urlError.value,
      'Invalid URL: missing id or relay parameter',
    );
  });

  testWidgets('welcome screen renders Chinese copy', (tester) async {
    Get.put(
      WelcomeViewModel(pairingLinkParser: const AuthRequestPairingLinkParser()),
    );

    await tester.pumpWidget(
      localizedTestApp(locale: AppLocales.zhCN, child: const WelcomeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('扫描二维码'), findsOneWidget);
    expect(find.text('随时随地掌控你的编程代理'), findsOneWidget);
  });
}
