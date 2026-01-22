/// CampusConnect v6.0 Design System
/// UI-only redesign - No logic changes
///
/// This file defines the visual identity:
/// - Color palette
/// - Typography scale
/// - Spacing constants
/// - Component styles
library;

import 'package:flutter/material.dart';

class AppTheme {
  // Prevent instantiation
  AppTheme._();

  // ============================================================================
  // COLOR SYSTEM
  // ============================================================================

  /// Primary brand color (professional blue)
  static const Color primaryBlue = Color(0xFF2563EB); // blue-600

  /// Lighter primary for hover/pressed states
  static const Color primaryBlueLight = Color(0xFF3B82F6); // blue-500

  /// Darker primary for depth
  static const Color primaryBlueDark = Color(0xFF1E40AF); // blue-700

  /// Secondary accent (complementary)
  static const Color secondaryIndigo = Color(0xFF4F46E5); // indigo-600

  /// Modern gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Success (applied, completed actions)
  static const Color success = Color(0xFF059669); // emerald-600
  static const Color successLight = Color(0xFF10B981); // emerald-500
  static const Color successBg = Color(0xFFD1FAE5); // emerald-100

  /// Warning (offline, trial expiring)
  static const Color warning = Color(0xFFD97706); // amber-600
  static const Color warningLight = Color(0xFFF59E0B); // amber-500
  static const Color warningBg = Color(0xFFFEF3C7); // amber-100

  /// Error (failures, critical states)
  static const Color error = Color(0xFFDC2626); // red-600
  static const Color errorLight = Color(0xFFEF4444); // red-500
  static const Color errorBg = Color(0xFFFEE2E2); // red-100

  /// Neutral grays
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  /// Background colors - soft, professional student-focused design
  static const Color background = Color(0xFFF7F9FC); // Soft light blue-gray
  static const Color surface = Colors.white;
  static const Color surfaceVariant = gray50;

  /// Text colors
  static const Color textPrimary = gray900;
  static const Color textSecondary = gray600;
  static const Color textTertiary = gray400;
  static const Color textOnPrimary = Colors.white;

  // ============================================================================
  // SPACING SYSTEM (8px grid)
  // ============================================================================

  static const double space0 = 0.0;
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // ============================================================================
  // BORDER RADIUS
  // ============================================================================

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusFull = 999.0; // Pill shape

  // ============================================================================
  // ELEVATION / SHADOWS
  // ============================================================================

  static List<BoxShadow> get shadowSmall => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 3,
      offset: const Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get shadowLarge => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  /// Colored shadow for elevated cards
  static List<BoxShadow> get shadowColored => [
    BoxShadow(
      color: primaryBlue.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  // ============================================================================
  // TYPOGRAPHY SCALE
  // ============================================================================

  /// Screen titles (AppBar, Page headers)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  /// Section headers
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  /// Card titles, list items
  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  /// Body text (primary)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  /// Body text (secondary)
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  /// Body text (small)
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  /// Captions, metadata, timestamps
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    height: 1.3,
  );

  /// Button text
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  /// Label text (form labels, tags)
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.2,
  );

  // ============================================================================
  // THEME DATA
  // ============================================================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: secondaryIndigo,
        surface: surface,
        error: error,
      ),

      // Scaffold
      scaffoldBackgroundColor: background,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: titleLarge,
      ),

      // Card
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
          side: BorderSide(color: gray200, width: 1),
        ),
        margin: EdgeInsets.all(0),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: textOnPrimary,
          disabledBackgroundColor: gray200,
          disabledForegroundColor: gray400,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: space20,
            vertical: space12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: button,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(
            horizontal: space16,
            vertical: space8,
          ),
          textStyle: button,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space16,
          vertical: space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: error),
        ),
        hintStyle: const TextStyle(color: gray400),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: gray100,
        deleteIconColor: gray600,
        labelStyle: label,
        padding: const EdgeInsets.symmetric(
          horizontal: space12,
          vertical: space4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: gray200,
        space: 1,
        thickness: 1,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryBlue,
        unselectedItemColor: gray400,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: gray800,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================================
  // COMMON DECORATIONS
  // ============================================================================

  /// Card decoration (consistent across app)
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusMedium),
    border: Border.all(color: gray200),
    boxShadow: shadowSmall,
  );

  /// Elevated card decoration
  static BoxDecoration get cardElevatedDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusMedium),
    boxShadow: shadowMedium,
  );

  /// Glass morphism effect for modern overlays
  static BoxDecoration get glassDecoration => BoxDecoration(
    color: surface.withOpacity(0.85),
    borderRadius: BorderRadius.circular(radiusMedium),
    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
    boxShadow: shadowLarge,
  );

  /// Gradient card decoration
  static BoxDecoration get gradientCardDecoration => BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(radiusLarge),
    boxShadow: shadowColored,
  );

  /// Banner decoration (warning, success, etc.)
  static BoxDecoration bannerDecoration(Color backgroundColor) => BoxDecoration(
    color: backgroundColor,
    border: Border(
      left: BorderSide(
        color: backgroundColor == warningBg
            ? warning
            : backgroundColor == successBg
            ? success
            : primaryBlue,
        width: 4,
      ),
      bottom: BorderSide(color: gray200, width: 1),
    ),
  );
}
