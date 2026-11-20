import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide Material 3 theme.
/// Vibrant indigo-violet brand colour, soft lavender background,
/// white rounded cards and the Poppins font (google_fonts).
class AppTheme {
  static const Color brand = Color(0xFF5B3DF5);
  static const Color background = Color(0xFFF6F5FB);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      primary: brand,
      surface: Colors.white,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: GoogleFonts.poppins().fontFamily,
    );
    final radius = BorderRadius.circular(16);
    final softBorder = BorderSide(color: scheme.outlineVariant.withAlpha(120));

    return base.copyWith(
      scaffoldBackgroundColor: background,

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: softBorder),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: softBorder),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: softBorder),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: scheme.primaryContainer,
        side: softBorder,
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: scheme.onSurface),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withAlpha(120)),
    );
  }
}