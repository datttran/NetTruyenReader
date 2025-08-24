import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized theme constants for the NetTruyen Reader app
/// This makes it easy to switch between light and dark themes
class ThemeConstants {
  // Private constructor to prevent instantiation
  ThemeConstants._();

  // ===== NETFLIX COLOR PALETTE =====
  static const Color netflixWhite = Color(0xFFFFFFFF);      // #ffffff - Pure white
  static const Color netflixRed = Color(0xFFC1071E);        // #c1071e - Netflix signature red
  static const Color netflixLightGray = Color(0xFFDEDEDE);  // #dedede - Light gray
  static const Color netflixDarkGray = Color(0xFF43465E);   // #43465e - Dark gray
  static const Color netflixNavy = Color(0xFF131834);       // #131834 - Deep navy

  // ===== LIGHT THEME COLORS =====
  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: netflixRed,                // Netflix red
    secondary: netflixDarkGray,         // Dark gray
    tertiary: netflixNavy,              // Navy blue
    surface: netflixWhite,              // Pure white
    background: netflixWhite,           // Pure white
    onPrimary: netflixWhite,            // White text on red
    onSecondary: netflixWhite,          // White text on dark gray
    onSurface: netflixNavy,             // Navy text on white
    onBackground: netflixNavy,          // Navy text on white
    error: netflixRed,                  // Netflix red for errors
    onError: netflixWhite,              // White text on red
  );

  // ===== DARK THEME COLORS =====
  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: netflixRed,                // Netflix red
    secondary: netflixDarkGray,         // Dark gray
    tertiary: netflixLightGray,         // Light gray
    surface: netflixNavy,               // Deep navy
    background: netflixNavy,            // Deep navy
    onPrimary: netflixWhite,            // White text on red
    onSecondary: netflixWhite,          // White text on dark gray
    onSurface: netflixLightGray,        // Light gray text on navy
    onBackground: netflixLightGray,     // Light gray text on navy
    error: netflixRed,                  // Netflix red for errors
    onError: netflixWhite,              // White text on red
  );

  // ===== COMMON COLORS =====
  static const Color chapterBadgeRed = netflixRed;              // Netflix red for chapter badges
  static const Color chapterBadgeRedLight = Color(0xFFE53E3E); // Slightly lighter red for light theme
  static const Color shimmerBase = netflixLightGray;            // Netflix light gray for shimmer
  static const Color shimmerHighlight = netflixWhite;           // Netflix white for shimmer highlight
  static const Color shimmerBaseDark = netflixDarkGray;         // Netflix dark gray for dark shimmer
  static const Color shimmerHighlightDark = netflixLightGray;   // Netflix light gray for dark shimmer highlight

  // ===== GOOGLE FONTS INCONSOLATA STYLES =====
  static TextStyle get inconsolataHeading => GoogleFonts.inconsolata(
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );
  
  static TextStyle get inconsolataSubheading => GoogleFonts.inconsolata(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle get inconsolataBody => GoogleFonts.inconsolata(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
  
  static TextStyle get inconsolataCaption => GoogleFonts.inconsolata(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  
  static TextStyle get inconsolataButton => GoogleFonts.inconsolata(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // ===== THEME DATA =====
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    textTheme: GoogleFonts.inconsolataTextTheme(ThemeData.light().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: netflixRed,
      foregroundColor: netflixWhite,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inconsolata(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: netflixWhite,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightColorScheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: netflixLightGray,
      selectedColor: netflixRed,
      labelStyle: GoogleFonts.inconsolata(color: netflixNavy),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: darkColorScheme,
    textTheme: GoogleFonts.inconsolataTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: netflixNavy,
      foregroundColor: netflixWhite,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inconsolata(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: netflixWhite,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkColorScheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: netflixDarkGray,
      selectedColor: netflixRed,
      labelStyle: GoogleFonts.inconsolata(color: netflixWhite),
    ),
  );

  // ===== UTILITY METHODS =====
  static Color getChapterBadgeColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return chapterBadgeRed;
      case ThemeMode.dark:
        return chapterBadgeRedLight;
      case ThemeMode.system:
        return chapterBadgeRed; // Default to light theme
    }
  }

  static Color getShimmerBaseColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return shimmerBase;
      case ThemeMode.dark:
        return shimmerBaseDark;
      case ThemeMode.system:
        return shimmerBase; // Default to light theme
    }
  }

  static Color getShimmerHighlightColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return shimmerHighlight;
      case ThemeMode.dark:
        return shimmerHighlightDark;
      case ThemeMode.system:
        return shimmerHighlight; // Default to light theme
    }
  }
} 