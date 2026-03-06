import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors
  static const primary = Color(0xFF1D1D1F);
  static const background = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1D1D1F);
  static const textSecondary = Color(0xFF6B6F76);
  static const textTertiary = Color(0xFF808690);
  static const border = Color(0xFFE5E7EB);
  static const inputFill = Color(0xFFEDEEF1);
  static const codeBg = Color(0xFF1D1D1F);

  // Text variants
  static const textMuted = Color(0xFFC8CBD0);
  static const textMetadata = Color(0xFF9DA1A8);

  // Border / surface variants
  static const chipBorder = Color(0xFFE0E2E6);
  static const selectedBg = Color(0xFFEBEBEC);
  static const hoverBg = Color(0xFFF0F1F4);

  // Status colors
  static const warning = Color(0xFFE8B730);
  static const warningBg = Color(0xFFFFF8E1);
  static const successBg = Color(0xFFECFDF5);
  static const successText = Color(0xFF4CB782);
  static const idleBg = Color(0xFFF5F5F5);
  static const errorText = Color(0xFFE5484D);
  static const errorBg = Color(0xFFFDE8E8);
  static const failedRed = Color(0xFFEF4444);
  static const statusConnecting = Color(0xFFE07B54);
  static const statusDisconnected = Color(0xFFCC4444);
  static const disconnectedBg = Color(0xFFFFF0F0);
  static const serverLostBg = Color(0xFFFEF2F2);
  static const serverLostText = Color(0xFFDC2626);

  // Feature accent
  static const planAccent = Color(0xFF3B82F6);
  static const subagentAccent = Color(0xFF7C6EF6);

  // Permission mode
  static const modeSkipBg = Color(0xFFFEF2F2);
  static const modePlanBg = Color(0xFFF3E8FF);
  static const modeAcceptBg = Color(0xFFEFF6FF);
  static const modePlanText = Color(0xFF7C3AED);
  static const modeAcceptText = Color(0xFF2563EB);
  static const modeSkipDot = Color(0xFFF87171);

  // Code block
  static const codeHeaderBg = Color(0xFF2A2A2A);
  static const codeText = Color(0xFFE0E2E6);

  // Diff
  static const diffRemoved = Color(0xFFEF4444);
  static const diffAdded = Color(0xFF22C55E);

  // Voice / recording
  static const recordRed = Color(0xFFFF3B30);
  static const waveformGreen = Color(0xFF34C759);

  static ThemeData light() {
    final textTheme = _textTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        secondary: primary,
        onSecondary: Colors.white,
        error: errorText,
        outline: border,
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 48),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(0, 48),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: textTertiary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 20),
    );
  }

  static ThemeData dark() {
    final textTheme = _textTheme(dark: true);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.white,
        surface: const Color(0xFF1A1A1A),
        onSurface: Colors.white,
        secondary: primary,
        onSecondary: Colors.white,
        error: errorText,
        outline: const Color(0xFF333333),
      ),
      scaffoldBackgroundColor: const Color(0xFF111111),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 48),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF333333)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(0, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF666666),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF333333),
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF888888), size: 20),
    );
  }

  static TextTheme _textTheme({bool dark = false}) {
    final color = dark ? Colors.white : textPrimary;
    final secondary = dark ? const Color(0xFF888888) : textSecondary;
    return TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: secondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );
  }
}
