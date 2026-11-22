import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/core/theme/app_colors.dart';
import 'package:docnet/core/theme/app_theme.dart';

void main() {
  group('AppTheme & AppColors Token Tests', () {
    test('Light theme tokens match THEME.md specifications', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.brightness, equals(Brightness.light));
      expect(lightTheme.colorScheme.primary, equals(const Color(0xFF183653)));
      expect(
        lightTheme.colorScheme.primaryContainer,
        equals(const Color(0xFFDCEAF5)),
      );
      expect(lightTheme.colorScheme.secondary, equals(const Color(0xFF2C789B)));
      expect(
        lightTheme.scaffoldBackgroundColor,
        equals(const Color(0xFFF2F6FA)),
      );
      expect(lightTheme.colorScheme.surface, equals(const Color(0xFFFFFFFF)));
      expect(lightTheme.colorScheme.error, equals(const Color(0xFFB33A3A)));
    });

    test('Dark theme tokens match THEME.md specifications', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.brightness, equals(Brightness.dark));
      expect(darkTheme.colorScheme.primary, equals(const Color(0xFF8CCDF0)));
      expect(
        darkTheme.colorScheme.primaryContainer,
        equals(const Color(0xFF23445E)),
      );
      expect(darkTheme.colorScheme.secondary, equals(const Color(0xFF80C5D9)));
      expect(
        darkTheme.scaffoldBackgroundColor,
        equals(const Color(0xFF101B27)),
      );
      expect(darkTheme.colorScheme.surface, equals(const Color(0xFF172635)));
      expect(darkTheme.colorScheme.error, equals(const Color(0xFFF08A8A)));
    });

    test('AppColors contains defined success, warning, outline tokens', () {
      expect(AppColors.lightSuccess, equals(const Color(0xFF237A57)));
      expect(AppColors.lightWarning, equals(const Color(0xFFA85B2E)));
      expect(AppColors.lightOutline, equals(const Color(0xFFCBD6E0)));
      expect(AppColors.darkSuccess, equals(const Color(0xFF69D5A7)));
      expect(AppColors.darkWarning, equals(const Color(0xFFE5A16E)));
      expect(AppColors.darkOutline, equals(const Color(0xFF405466)));
    });
  });
}
