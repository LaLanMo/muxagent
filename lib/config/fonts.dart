import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  static TextStyle code({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle codeSmall({Color? color}) {
    return code(fontSize: 11, color: color);
  }

  static TextStyle codeLabel({Color? color}) {
    return code(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }
}
