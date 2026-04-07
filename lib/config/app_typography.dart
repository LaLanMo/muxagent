import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppTypography {
  static TextStyle sans({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return _font(
      null,
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  static TextStyle mono({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return _font(
      _systemMonospaceFamily,
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      fontFamilyFallback: _systemMonospaceFallback,
    );
  }

  static TextTheme sansTextTheme([TextTheme? textTheme]) {
    return _textTheme(textTheme, sans);
  }

  static TextTheme monoTextTheme([TextTheme? textTheme]) {
    return _textTheme(textTheme, mono);
  }

  static TextStyle _font(
    String? family, {
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    List<String>? fontFamilyFallback,
  }) {
    final base = textStyle ?? const TextStyle();
    return base.copyWith(
      fontFamily: family,
      fontFamilyFallback: fontFamilyFallback,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  static String get _systemMonospaceFamily {
    if (kIsWeb) {
      return 'monospace';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'Menlo';
      case TargetPlatform.windows:
        return 'Consolas';
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        return 'monospace';
    }
  }

  static List<String> get _systemMonospaceFallback {
    if (kIsWeb) {
      return const ['Courier New', 'monospace'];
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const ['Monaco', 'Courier', 'Courier New'];
      case TargetPlatform.windows:
        return const ['Courier New'];
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        return const ['Roboto Mono', 'Droid Sans Mono'];
    }
  }

  static TextTheme _textTheme(
    TextTheme? textTheme,
    TextStyle Function({
      TextStyle? textStyle,
      Color? color,
      Color? backgroundColor,
      double? fontSize,
      FontWeight? fontWeight,
      FontStyle? fontStyle,
      double? letterSpacing,
      double? wordSpacing,
      TextBaseline? textBaseline,
      double? height,
      Locale? locale,
      Paint? foreground,
      Paint? background,
      List<ui.Shadow>? shadows,
      List<ui.FontFeature>? fontFeatures,
      TextDecoration? decoration,
      Color? decorationColor,
      TextDecorationStyle? decorationStyle,
      double? decorationThickness,
    })
    applyFont,
  ) {
    final base = textTheme ?? ThemeData.fallback().textTheme;
    return base.copyWith(
      displayLarge: base.displayLarge == null
          ? null
          : applyFont(textStyle: base.displayLarge),
      displayMedium: base.displayMedium == null
          ? null
          : applyFont(textStyle: base.displayMedium),
      displaySmall: base.displaySmall == null
          ? null
          : applyFont(textStyle: base.displaySmall),
      headlineLarge: base.headlineLarge == null
          ? null
          : applyFont(textStyle: base.headlineLarge),
      headlineMedium: base.headlineMedium == null
          ? null
          : applyFont(textStyle: base.headlineMedium),
      headlineSmall: base.headlineSmall == null
          ? null
          : applyFont(textStyle: base.headlineSmall),
      titleLarge: base.titleLarge == null
          ? null
          : applyFont(textStyle: base.titleLarge),
      titleMedium: base.titleMedium == null
          ? null
          : applyFont(textStyle: base.titleMedium),
      titleSmall: base.titleSmall == null
          ? null
          : applyFont(textStyle: base.titleSmall),
      bodyLarge: base.bodyLarge == null
          ? null
          : applyFont(textStyle: base.bodyLarge),
      bodyMedium: base.bodyMedium == null
          ? null
          : applyFont(textStyle: base.bodyMedium),
      bodySmall: base.bodySmall == null
          ? null
          : applyFont(textStyle: base.bodySmall),
      labelLarge: base.labelLarge == null
          ? null
          : applyFont(textStyle: base.labelLarge),
      labelMedium: base.labelMedium == null
          ? null
          : applyFont(textStyle: base.labelMedium),
      labelSmall: base.labelSmall == null
          ? null
          : applyFont(textStyle: base.labelSmall),
    );
  }
}
