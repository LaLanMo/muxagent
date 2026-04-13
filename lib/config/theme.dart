import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muxagent/config/app_typography.dart';

class AppTheme {
  static const primary = Color(0xFF2F2825);
  static const accent = Color(0xFFFF6A15);
  static const background = Color(0xFFF7F2EE);
  static const surface = Color(0xFFFBF8F6);
  static const surfaceSubtle = Color(0xFFF4EFEB);
  static const surfaceMuted = Color(0xFFEDE8E4);
  static const textPrimary = Color(0xFF2A2421);
  static const textSecondary = Color(0xFF5F5550);
  static const textTertiary = Color(0xFF7A6F68);
  static const textMuted = Color(0xFFB6AAA2);
  static const textMetadata = Color(0xFF9B8E87);
  static const border = Color(0xFFE2DCD8);
  static const borderStrong = Color(0xFFD1C8C2);
  static const chipBorder = Color(0xFFA79A91);
  static const selectedBg = primary;
  static const hoverBg = surfaceSubtle;
  static const inputFill = surface;
  static const codeBg = Color(0xFF2F2825);
  static const codeHeaderBg = Color(0xFF3A3430);
  static const codeText = Color(0xFFFBF8F6);

  static const statusNeutralText = textTertiary;
  static const statusNeutralBg = surfaceMuted;
  static const successText = Color(0xFF1A6B3A);
  static const successBg = Color(0xFFD6EDDC);
  static const warning = Color(0xFF8B6D24);
  static const warningBg = Color(0xFFF2E7BE);
  static const errorText = Color(0xFFA14C45);
  static const errorBg = Color(0xFFF4DDDA);
  static const idleBg = statusNeutralBg;
  static const failedRed = errorText;
  static const statusConnecting = warning;
  static const statusDisconnected = errorText;
  static const disconnectedBg = errorBg;
  static const serverLostBg = errorBg;
  static const serverLostText = errorText;

  static const planAccent = Color(0xFF2563EB);
  static const subagentAccent = Color(0xFF7A6F68);
  static const unreadDot = accent;
  static const modeSkipBg = errorBg;
  static const modePlanBg = surfaceSubtle;
  static const modeAcceptBg = successBg;
  static const modePlanText = textSecondary;
  static const modeAcceptText = successText;
  static const modeSkipDot = errorText;
  static const diffRemoved = errorText;
  static const diffAdded = successText;
  static const recordRed = Color(0xFFC94C40);
  static const waveformGreen = successText;

  static const radiusNone = 0.0;
  static const radiusXs = 4.0;
  static const radiusSm = 4.0;
  static const radiusLg = 4.0;
  static const radiusPill = 4.0;

  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  static const durationFast = Duration(milliseconds: 140);
  static const durationEnter = Duration(milliseconds: 200);
  static const durationLayout = Duration(milliseconds: 300);

  static ThemeData light() {
    final textTheme = _textTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        secondary: accent,
        onSecondary: Colors.white,
        error: errorText,
        outline: border,
      ),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: AppTypography.sans(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXs),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusNone),
          ),
          minimumSize: const Size(double.infinity, 44),
          textStyle: AppTypography.sans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusNone),
          ),
          minimumSize: const Size(0, 44),
          textStyle: AppTypography.sans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusNone),
          borderSide: const BorderSide(color: borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusNone),
          borderSide: const BorderSide(color: borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusNone),
          borderSide: const BorderSide(color: primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: AppTypography.sans(fontSize: 14, color: textTertiary),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: textTertiary, size: 20),
    );
  }

  static ThemeData dark() => light();

  static TextTheme _textTheme() {
    return TextTheme(
      headlineLarge: AppTypography.sans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      headlineMedium: AppTypography.sans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: AppTypography.sans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: AppTypography.sans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: AppTypography.sans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      titleSmall: AppTypography.sans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyLarge: AppTypography.sans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodyMedium: AppTypography.sans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodySmall: AppTypography.sans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      labelLarge: AppTypography.sans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      labelMedium: AppTypography.mono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: textTertiary,
      ),
      labelSmall: AppTypography.mono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textTertiary,
      ),
    );
  }
}
