import 'package:flutter/material.dart';

import '../../config/fonts.dart';

class CodeText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;

  const CodeText(
    this.text, {
    super.key,
    this.fontSize = 13,
    this.color,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppFonts.code(fontSize: fontSize, color: color),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
