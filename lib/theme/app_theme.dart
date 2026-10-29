// All the colors, fonts, and shapes for the app live here.
// Screens should never hardcode a Color or TextStyle directly —
// they should read it from Theme.of(context) instead, so changing
// the look of the whole app only ever means editing this one file.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Every raw color value used by the app, named the way the design spec
/// names them. Nothing else in the app should type a hex code directly.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF165E20); // dark green
  static const Color secondary = Color(0xFF45A047); // green
  static const Color accentYellow = Color(0xFFFBC02D);
  static const Color accentOrange = Color(0xFFFF7043);
  static const Color surface = Color(0xFFF1F5F9); // light gray background
  static const Color textDark = Color(0xFF26223B);
  static const Color white = Colors.white;
  // Loading-skeleton placeholder box color (see widgets/skeleton_box.dart).
  static const Color skeletonBase = Color(0xFFE2E8F0);
  // The floating bump bottom-nav bar's own background (see
  // router/main_shell_screen.dart) — deliberately fixed near-black in both
  // light and dark app theme, not derived from the theme's own surface
  // colors: a dark "bump nav" bar is a specific, intentional style choice
  // (matching the reference design), not something meant to invert.
  static const Color navBarDark = Color(0xFF1A1D21);
}

/// Shared spacing/radius numbers so cards and buttons stay consistent
/// wherever they're used.
class AppSpacing {
  AppSpacing._();

  static const double screenPadding = 16.0;
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.surface,
    );

    // Poppins for every text style, with the sizes/weights the spec asks
    // for: titles 18-22 SemiBold, body 14-16 Regular, labels 12.
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,

      // Cards: 16px rounded corners with a soft shadow.
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 3,
        shadowColor: AppColors.textDark.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),

      // Primary button: filled dark green, white text, full width, radius 12.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),

      // Secondary button: white background, green border, radius 12.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textDark.withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: BorderSide.none,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleSmall,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
    );
  }

  /// Material 3's dark conventions (surfaces derived from the seed color
  /// rather than AppColors' fixed light-mode hexes, proper light-on-dark
  /// contrast) while keeping the same brand green recognizable — letting
  /// ColorScheme.fromSeed compute the dark-appropriate primary tone
  /// automatically, rather than reusing AppColors.primary as-is (that
  /// exact dark green reads fine on white but is too dark/low-contrast for
  /// text and icons on a near-black surface).
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
    );
    final scheme = base.colorScheme;

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,

      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHigh,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.primary,
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: scheme.primary, width: 1.5),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: scheme.onSurface.withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: BorderSide.none,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleSmall,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
    );
  }
}
