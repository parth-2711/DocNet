import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Complete FamilyVault application theme matching THEME.md specifications.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.lightPrimaryContainer,
      onPrimaryContainer: AppColors.lightPrimary,
      secondary: AppColors.lightSecondary,
      onSecondary: Colors.white,
      error: AppColors.lightError,
      onError: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
      outline: AppColors.lightOutline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: AppTypography.createTextTheme(
        AppColors.lightTextPrimary,
        AppColors.lightTextSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.inputBorderRadius,
          side: const BorderSide(color: AppColors.lightOutline, width: 1),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.standard,
          vertical: AppSpacing.compact,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.small,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.smallBorderRadius,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightPrimary,
          minimumSize: const Size(88, 48),
          side: const BorderSide(color: AppColors.lightOutline),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.small,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.smallBorderRadius,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.standard,
          vertical: AppSpacing.small,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.lightOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(
            color: AppColors.lightSecondary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.lightError),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.lightPrimary,
        unselectedItemColor: AppColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedIconTheme: IconThemeData(color: AppColors.lightPrimary),
        unselectedIconTheme: IconThemeData(color: AppColors.lightTextSecondary),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.lightPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkBackground,
      primaryContainer: AppColors.darkPrimaryContainer,
      onPrimaryContainer: AppColors.darkPrimary,
      secondary: AppColors.darkSecondary,
      onSecondary: AppColors.darkBackground,
      error: AppColors.darkError,
      onError: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      outline: AppColors.darkOutline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: AppTypography.createTextTheme(
        AppColors.darkTextPrimary,
        AppColors.darkTextSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.inputBorderRadius,
          side: const BorderSide(color: AppColors.darkOutline, width: 1),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.standard,
          vertical: AppSpacing.compact,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkBackground,
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.small,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.smallBorderRadius,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          minimumSize: const Size(88, 48),
          side: const BorderSide(color: AppColors.darkOutline),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.small,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.smallBorderRadius,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.standard,
          vertical: AppSpacing.small,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(
            color: AppColors.darkSecondary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.darkError),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedIconTheme: IconThemeData(color: AppColors.darkPrimary),
        unselectedIconTheme: IconThemeData(color: AppColors.darkTextSecondary),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.darkPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}
