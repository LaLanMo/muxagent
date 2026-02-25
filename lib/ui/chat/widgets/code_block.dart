import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/fonts.dart';
import '../../../config/theme.dart';

class CodeBlock extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final bool showCopyButton;

  const CodeBlock({
    super.key,
    required this.text,
    this.backgroundColor = AppTheme.codeBg,
    this.textColor = const Color(0xFFE0E0E0),
    this.showCopyButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              text,
              style: AppFonts.code(fontSize: 13, color: textColor),
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
                  color: textColor.withValues(alpha: 0.5),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
