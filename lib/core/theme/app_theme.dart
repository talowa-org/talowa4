// TALOWA App Theme
// Reference: complete-app-structure.md - Design System Guidelines

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AppTheme {
  // TALOWA Brand Colors
  static const Color talowaGreen = Color(AppConstants.talowaGreenValue);
  static const Color legalBlue = Color(AppConstants.legalBlueValue);
  static const Color emergencyRed = Color(AppConstants.emergencyRedValue);
  static const Color warningOrange = Color(AppConstants.warningOrangeValue);
  static const Color successGreen = Color(AppConstants.successGreenValue);
  
  // Neutral Colors
  static const Color primaryText = Color(0xFF111827);
  static const Color secondaryText = Color(0xFF6B7280);
  static const Color disabledText = Color(0xFF9CA3AF);
  static const Color background = Color(0xFFF9FAFB);
  static const Color cardBackground = Colors.white;
  static const Color borderColor = Color(0xFFE5E7EB);
  
  // Spacing System (Base Unit: 4px)
  static const double spacingMicro = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  static const double spacingXXLarge = 48.0;
  
  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  
  // Elevation
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  
  // Typography Scale (Noto Sans Telugu)
  static const TextStyle displayStyle = TextStyle(
    fontFamily: 'NotoSansTelugu',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: primaryText,
  );
  
  static const TextStyle heading1Style = TextStyle(
    fontFamily: 'NotoSansTelugu',
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: primaryText,
  );
  
  static const TextStyle heading2Style = TextStyle(
    fontFamily: 'NotoSansTelugu',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: primaryText,
  );
  
  static const TextStyle heading3Style = TextStyle(
    fontFamily: 'NotoSansTelugu',
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: primaryText,
  );
  
  static const TextStyle bodyLargeStyle = TextStyle(
    fontFamily: 'NotoSansTelugu',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: primaryText,
  );
  
  static const TextStyle bodyStyle = TextStyle(
    fontFamily: 'NotoSansTelugu',
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: primaryText,
  );
  
  static const TextStyle captionStyle = TextStyle(
    fontFamily: 'NotoSansTelugu',
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: secondaryText,
  );
  
  static const TextStyle buttonStyle = TextStyle(
    fontFamily: 'NotoSansTelugu',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );
  
  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: talowaGreen,
        brightness: Brightness.light,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: talowaGreen,
        foregroundColor: Colors.white,
        elevation: elevationLow,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansTelugu',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: talowaGreen,
        unselectedItemColor: secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: elevationMedium,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'NotoSansTelugu',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'NotoSansTelugu',
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),
      
      // Card Theme
      cardTheme: const CardThemeData(
        color: cardBackground,
        elevation: elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        ),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: talowaGreen,
          foregroundColor: Colors.white,
          elevation: elevationLow,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLarge,
            vertical: spacingMedium,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          ),
          textStyle: buttonStyle,
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: talowaGreen,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingMedium,
            vertical: spacingSmall,
          ),
          textStyle: buttonStyle.copyWith(color: talowaGreen),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide(color: talowaGreen, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacingMedium,
          vertical: spacingMedium,
        ),
        labelStyle: bodyStyle,
        hintStyle: TextStyle(color: disabledText),
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        displayLarge: displayStyle,
        headlineLarge: heading1Style,
        headlineMedium: heading2Style,
        headlineSmall: heading3Style,
        bodyLarge: bodyLargeStyle,
        bodyMedium: bodyStyle,
        bodySmall: captionStyle,
        labelLarge: buttonStyle,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: secondaryText,
        size: 24,
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: spacingMedium,
      ),
    );
  }
  
  // Emergency Theme (for emergency alerts)
  static ThemeData get emergencyTheme {
    return lightTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: emergencyRed,
        brightness: Brightness.light,
      ),
      appBarTheme: lightTheme.appBarTheme.copyWith(
        backgroundColor: emergencyRed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emergencyRed,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
  
  // Legal Theme (for legal case screens)
  static ThemeData get legalTheme {
    return lightTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: legalBlue,
        brightness: Brightness.light,
      ),
      appBarTheme: lightTheme.appBarTheme.copyWith(
        backgroundColor: legalBlue,
      ),
    );
  }
}