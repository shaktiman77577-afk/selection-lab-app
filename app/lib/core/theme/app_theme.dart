// lib/core/theme/app_theme.dart
//
// Redesign (Sep 2026): Testbook jaisa clean look.
// - Halka grey background, safed cards, patli border, shadow nahi
// - Navy main colour (buttons, links); gold sirf accent (offers, badges)
// - Font: Inter; Hindi ke liye Noto Sans Devanagari (fallback)
//
// AppColors purane screens ke liye hai (video/PDF viewer, email login).
// primary ab orange nahi, brand gold — taaki bache hue screens bhi naye
// rangon se mel khayein. Inhe dheere-dheere Brand/DT par le jayenge.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFFFFAB00); // brand gold (pehle orange FF6B00)
  static const primaryDark = Color(0xFFE09600);
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF1A1A1A);
  static const card = Color(0xFF242424);
  static const text = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFAAAAAA);
  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFE53935);
  static const warning = Color(0xFFFFB300);
}

/// Brand colours — naye screens yahi use karein
class Brand {
  static const navy = Color(0xFF1A2F55);
  static const navyLight = Color(0xFF2C4A85);
  /// Dark mode me navy kaala-sa dikhta hai — wahan ye halka neela
  static const navyOnDark = Color(0xFF7C9BE0);
  static const gold = Color(0xFFFFAB00);
  static const green = Color(0xFF2E8B4A);
  static const red = Color(0xFFC0392B);
}

class AppTheme {
  static final ThemeData lightTheme = _build(Brightness.light);
  static final ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? const Color(0xFF0F1115) : const Color(0xFFF5F6FA);
    final card = dark ? const Color(0xFF181B22) : Colors.white;
    final text = dark ? Colors.white : const Color(0xFF1B2331);
    final muted = dark ? const Color(0xFF8C93A3) : const Color(0xFF6B7385);
    final line =
        dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08);
    final primary = dark ? Brand.navyOnDark : Brand.navy;
    final onPrimary = dark ? const Color(0xFF0F1115) : Colors.white;

    final base = ThemeData(useMaterial3: true, brightness: b);
    final hindi = GoogleFonts.notoSansDevanagari().fontFamily;
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: text,
      displayColor: text,
      fontFamilyFallback: hindi == null ? null : [hindi],
    );

    final radius10 = BorderRadius.circular(10);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(seedColor: Brand.navy, brightness: b)
          .copyWith(
        primary: primary,
        onPrimary: onPrimary,
        secondary: Brand.gold,
        onSecondary: const Color(0xFF1A1A1A),
        surface: card,
        onSurface: text,
        error: Brand.red,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium
            ?.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: text),
        shape: Border(bottom: BorderSide(color: line)),
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: line),
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: radius10),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: primary.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: radius10),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
            borderRadius: radius10, borderSide: BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius10, borderSide: BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius10,
            borderSide: BorderSide(color: primary, width: 1.5)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        side: BorderSide(color: line),
        labelStyle: TextStyle(color: text, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF2A2F3A) : Brand.navy,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: radius10),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
