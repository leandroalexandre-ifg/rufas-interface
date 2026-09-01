import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de fazenda "editorial de laticínio" (ver docs/design/README.md):
/// verde-floresta como cor primária, verde-claro (tinta do primário) como
/// apoio, dourado como acento (confirmações / chips ativos / progresso),
/// fundo creme, texto quase-preto puxado pro verde. Fonte única de
/// cores/estilos — todas as telas devem herdar do ThemeData montado aqui,
/// nunca hardcodar cor localmente.
class AppColors {
  AppColors._();

  static const primaryGreen = Color(0xFF1B4D3E);
  static const lightGreen = Color(0xFFDCEAE1);
  static const amber = Color(0xFFF4C15C);
  static const background = Color(0xFFFAF7F0);
  static const surface = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF26332C);
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

    final workSans = GoogleFonts.workSansTextTheme(ThemeData.light().textTheme);
    final baseText = workSans.apply(
          bodyColor: AppColors.textDark,
          displayColor: AppColors.textDark,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseText.copyWith(
        headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: baseText.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
        bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16),
        bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryGreen,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.workSans(
          color: AppColors.primaryGreen,
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryGreen),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primaryGreen.withValues(alpha: 0.14)),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.primaryGreen.withValues(alpha: 0.35),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: const StadiumBorder(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.background,
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          minimumSize: const Size(64, 52),
          side: const BorderSide(color: AppColors.primaryGreen, width: 1.6),
          shape: const StadiumBorder(),
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
        foregroundColor: AppColors.background,
        elevation: 0,
        shape: StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.4),
        ),
        labelStyle: TextStyle(color: AppColors.textDark.withValues(alpha: 0.75)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightGreen,
        selectedColor: AppColors.amber,
        disabledColor: colorScheme.outline.withValues(alpha: 0.15),
        checkmarkColor: AppColors.textDark,
        labelStyle: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primaryGreen,
        textColor: AppColors.textDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
