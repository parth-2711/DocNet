import 'package:flutter/material.dart';

/// Design tokens for FamilyVault color palette as defined in THEME.md.
class AppColors {
  AppColors._();

  // --- Light Theme Colors ---
  static const Color lightPrimary = Color(0xFF183653);
  static const Color lightPrimaryContainer = Color(0xFFDCEAF5);
  static const Color lightSecondary = Color(0xFF2C789B);
  static const Color lightAccent = Color(0xFF5DB7E8);
  static const Color lightBackground = Color(0xFFF2F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFE8EFF5);
  static const Color lightTextPrimary = Color(0xFF172C42);
  static const Color lightTextSecondary = Color(0xFF607286);
  static const Color lightSuccess = Color(0xFF237A57);
  static const Color lightWarning = Color(0xFFA85B2E);
  static const Color lightError = Color(0xFFB33A3A);
  static const Color lightOutline = Color(0xFFCBD6E0);

  // --- Dark Theme Colors ---
  static const Color darkPrimary = Color(0xFF8CCDF0);
  static const Color darkPrimaryContainer = Color(0xFF23445E);
  static const Color darkSecondary = Color(0xFF80C5D9);
  static const Color darkAccent = Color(0xFF5DB7E8);
  static const Color darkBackground = Color(0xFF101B27);
  static const Color darkSurface = Color(0xFF172635);
  static const Color darkSurfaceVariant = Color(0xFF243849);
  static const Color darkTextPrimary = Color(0xFFF0F5F9);
  static const Color darkTextSecondary = Color(0xFFB2C2CF);
  static const Color darkSuccess = Color(0xFF69D5A7);
  static const Color darkWarning = Color(0xFFE5A16E);
  static const Color darkError = Color(0xFFF08A8A);
  static const Color darkOutline = Color(0xFF405466);

  // --- Premium Senior Designer Extension Gradients ---
  static const LinearGradient heroGradientLight = LinearGradient(
    colors: [Color(0xFF183653), Color(0xFF2C789B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    colors: [Color(0xFF1E2F42), Color(0xFF142230)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF1C456E), Color(0xFF2C789B)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient darkButtonGradient = LinearGradient(
    colors: [Color(0xFF2A537A), Color(0xFF3B82A6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const Gradient authBackgroundGradientDark = RadialGradient(
    center: Alignment(0.0, -0.4),
    radius: 1.2,
    colors: [Color(0xFF1A2E44), Color(0xFF101B27), Color(0xFF0C141E)],
    stops: [0.0, 0.55, 1.0],
  );

  static const Gradient authBackgroundGradientLight = RadialGradient(
    center: Alignment(0.0, -0.4),
    radius: 1.2,
    colors: [Color(0xFFE8F2FA), Color(0xFFF2F6FA), Color(0xFFE6EEF5)],
    stops: [0.0, 0.6, 1.0],
  );
}

/// Category visual style mapping for professional iconography and distinct palette tints.
class AppCategoryTheme {
  AppCategoryTheme._();

  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'identity':
        return Icons.badge_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'driving':
        return Icons.directions_car_outlined;
      case 'financial':
      case 'finance':
        return Icons.account_balance_wallet_outlined;
      case 'medical':
        return Icons.health_and_safety_outlined;
      case 'property':
        return Icons.home_work_outlined;
      case 'employment':
        return Icons.work_outline;
      case 'insurance':
        return Icons.verified_user_outlined;
      case 'family':
        return Icons.people_outline;
      default:
        return Icons.folder_open_outlined;
    }
  }

  static Color getColor(String category) {
    switch (category.toLowerCase()) {
      case 'identity':
        return const Color(0xFF2563EB); // Azure
      case 'education':
        return const Color(0xFF7C3AED); // Violet
      case 'driving':
        return const Color(0xFF0284C7); // Cyan
      case 'financial':
      case 'finance':
        return const Color(0xFF059669); // Emerald
      case 'medical':
        return const Color(0xFFE11D48); // Rose
      case 'property':
        return const Color(0xFFD97706); // Amber
      case 'employment':
        return const Color(0xFF4F46E5); // Indigo
      case 'insurance':
        return const Color(0xFF0D9488); // Teal
      case 'family':
        return const Color(0xFF0284C7); // Sky
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  static Color getBackgroundColor(String category, bool isDark) {
    final baseColor = getColor(category);
    if (isDark) {
      return baseColor.withAlpha(45);
    } else {
      return baseColor.withAlpha(25);
    }
  }
}

/// Professional soft elevation shadows.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> softCard(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withAlpha(50),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.white.withAlpha(5),
          blurRadius: 0,
          spreadRadius: 1,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: const Color(0xFF183653).withAlpha(12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF183653).withAlpha(6),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
    }
  }

  static List<BoxShadow> glow(Color color) {
    return [
      BoxShadow(
        color: color.withAlpha(60),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
