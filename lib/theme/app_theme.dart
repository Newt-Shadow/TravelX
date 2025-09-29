import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary color palette
  static const Color primaryColor = Color(0xFF6E48AA); // A deep, engaging purple
  static const Color accentColor = Color(0xFF9370DB); // A lighter, complementary purple
  static const Color primaryGradientStart = Color(0xFF8A2BE2); // Blue Violet
  static const Color primaryGradientEnd = Color(0xFF4B0082); // Indigo

  // Neutral and background colors
  static const Color backgroundColor = Color(0xFF121212); // Dark background for a modern feel
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color textColor = Colors.white;
  static const Color subTextColor = Colors.white70;

  // System and status colors
  static const Color successColor = Color(0xFF32CD32); // Lime Green
  static const Color errorColor = Color(0xFFFF4500); // OrangeRed

  // Typography
  static final TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.poppins(fontSize: 57, fontWeight: FontWeight.bold, color: textColor),
    displayMedium: GoogleFonts.poppins(fontSize: 45, fontWeight: FontWeight.bold, color: textColor),
    displaySmall: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: textColor),
    headlineLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w600, color: textColor),
    headlineMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600, color: textColor),
    headlineSmall: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: textColor),
    titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: textColor),
    titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: const Color.fromARGB(255, 0, 0, 0)),
    titleSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
    bodyLarge: GoogleFonts.poppins(fontSize: 16, color: subTextColor),
    bodyMedium: GoogleFonts.poppins(fontSize: 14, color: subTextColor),
    bodySmall: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
    labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
    labelMedium: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
    labelSmall: GoogleFonts.poppins(fontSize: 11, color: subTextColor),
  );

  // App Theme
  static ThemeData get themeData {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: textTheme,
      // CORRECTED: Used CardThemeData instead of CardTheme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          textStyle: textTheme.labelLarge,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.white38,
      ),
    );
  }
}