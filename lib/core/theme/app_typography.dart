import 'package:flutter/material.dart';

/// Typography definitions specified in THEME.md Section 4.
class AppTypography {
  AppTypography._();

  static TextTheme createTextTheme(
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32.0,
        height: 40.0 / 32.0,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 24.0,
        height: 32.0 / 24.0,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
      ),
      titleLarge: TextStyle(
        fontSize: 20.0,
        height: 28.0 / 20.0,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16.0,
        height: 24.0 / 16.0,
        fontWeight: FontWeight.w500,
        color: primaryTextColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.0,
        height: 22.0 / 14.0,
        fontWeight: FontWeight.w400,
        color: primaryTextColor,
      ),
      labelLarge: TextStyle(
        fontSize: 12.0,
        height: 18.0 / 12.0,
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
      ),
      bodySmall: TextStyle(
        fontSize: 11.0,
        height: 16.0 / 11.0,
        fontWeight: FontWeight.w400,
        color: secondaryTextColor,
      ),
    );
  }
}
