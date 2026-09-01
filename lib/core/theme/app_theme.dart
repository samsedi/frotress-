import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors based on the clean vision (Neutral Palette)
  static const Color backgroundLightBlue = Color(0xFFE0EFFF); // A more distinct, cool light blue
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Pure white for sleekness
  static const Color surfaceDark = Color(0xFF1E1E1E); // Deep dark for cards
  static const Color textDark = Color(0xFF202124); // Soft black for high contrast readability
  static const Color textLight = Color(0xFF80868B); // For very small, subtle labels

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      scaffoldBackgroundColor: backgroundLightBlue,
      colorScheme: const ColorScheme.light(
        primary: surfaceDark,
        secondary: surfaceWhite,
        surface: surfaceWhite,
        onSurface: textDark,
      ),
      useMaterial3: true,
      
      // Typography: Small, crisp labels and massive, clean numbers
      textTheme: baseTextTheme.copyWith(
        // Massive balances
        displayLarge: GoogleFonts.inter(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: textDark,
          letterSpacing: -1.5,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: textDark,
          letterSpacing: -1.0,
        ),
        // Standard clean text
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
        // Tiny, crisp, stylish labels
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: textLight,
        ),
      ),

      // Highly rounded, spacious card design
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
      ),
      
      // Minimalist App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: surfaceDark),
        titleTextStyle: GoogleFonts.inter(
          color: surfaceDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      
      // Sleek Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100), // Pill shaped
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
