import 'package:flutter/material.dart';

/// Paleta de fazenda (ver CLAUDE.md, "Aplicação do design visual"):
/// verde folha como cor primária, verde-claro como apoio, âmbar como
/// acento (confirmações / chips ativos), fundo off-white, texto
/// cinza-escuro. Fonte única de cores/estilos — todas as telas devem
/// herdar do ThemeData montado aqui, nunca hardcodar cor localmente.
class AppColors {
  AppColors._();

  static const primaryGreen = Color(0xFF2E7D32);
  static const lightGreen = Color(0xFFA5D6A7);
  static const amber = Color(0xFFF9A825);
  static const background = Color(0xFFFAF9F4);
  static const surface = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF262B27);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primaryGreen,
      onPrimary: Colors.white,
      secondary: AppColors.lightGreen,
      onSecondary: AppColors.textDark,
      tertiary: AppColors.amber,
      onTertiary: AppColors.textDark,
      surface: AppColors.surface,
      onSurface: AppColors.textDark,
      error: const Color(0xFFB3261E),
    );

    final baseText = ThemeData.light().textTheme.apply(
          bodyColor: AppColors.textDark,
          displayColor: AppColors.textDark,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseText.copyWith(
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: baseText.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16),
        bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14.5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryGreen.withValues(alpha: 0.4),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          minimumSize: const Size(64, 52),
          side: const BorderSide(color: AppColors.primaryGreen, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1.4),
        ),
        labelStyle: TextStyle(color: AppColors.textDark.withValues(alpha: 0.75)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightGreen.withValues(alpha: 0.35),
        selectedColor: AppColors.amber,
        disabledColor: colorScheme.outline.withValues(alpha: 0.15),
        checkmarkColor: AppColors.textDark,
        labelStyle: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primaryGreen,
        textColor: AppColors.textDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryGreen,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
