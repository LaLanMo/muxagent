import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../config/theme.dart';
import '../../../config/fonts.dart';
import '../../../i18n/tx.dart';
import '../../../utils/app_toast.dart';

class CodeBlock extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showCopyButton;

  const CodeBlock({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.showCopyButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppTheme.codeBg;
    final fgColor = textColor ?? AppTheme.codeText;

    return Container(
      width: double.infinity,
      color: bgColor,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                text,
                style: AppFonts.code(fontSize: 13, color: fgColor),
              ),
            ),
          ),
          if (showCopyButton)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: fgColor.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  AppToast.show(Tx.commonCopiedToClipboard.tr);
                },
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ),
        ],
      ),
    );
  }
}
