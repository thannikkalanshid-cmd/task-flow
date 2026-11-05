import 'package:flutter/material.dart';

/// One palette for the whole app so every screen matches.
class AppColors {
  static const bg = Color(0xFF070B1E);
  static const surface = Color(0xFF111B3A);
  static const surfaceHi = Color(0xFF1A2754);
  static const field = Color(0xFF060A1A);
  static const line = Color(0xFF2A3A6B);
  static const primary = Color(0xFF6366F1);
  static const primaryDeep = Color(0xFF4338CA);
  static const primaryEdge = Color(0xFF2E2A85);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const muted = Color(0xFF94A3B8);
  static const text = Color(0xFFEAF0FF);
}

class AppShadows {
  /// Layered shadow that makes a surface look raised off the background.
  static const lift = [
    BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 3)),
  ];
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final shape16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.cyan,
        tertiary: AppColors.violet,
        surface: AppColors.surface,
        error: AppColors.red,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: Colors.white,
      ),
      dividerColor: AppColors.line,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        elevation: 8,
        scrolledUnderElevation: 8,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        elevation: 12,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.line.withOpacity(.7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(AppColors.line.withOpacity(.6)),
        enabledBorder: border(AppColors.line.withOpacity(.6)),
        focusedBorder: border(AppColors.primary, 1.8),
        errorBorder: border(AppColors.red),
        focusedErrorBorder: border(AppColors.red, 1.8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: AppColors.primary.withOpacity(.7),
          minimumSize: const Size.fromHeight(52),
          shape: shape16,
          side: const BorderSide(color: Colors.white24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.line),
          shape: shape16,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFA5B4FC)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 12,
        shape: shape16,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: Color(0xFFA5B4FC),
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 20,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceHi,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceHi,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHi,
        contentTextStyle: const TextStyle(color: AppColors.text),
        shape: shape16,
        elevation: 12,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }
}
