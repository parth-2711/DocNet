import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/main.dart';

void main() {
  testWidgets(
    'App redirects unauthenticated user to Login, signs in, and loads Home dashboard',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const ProviderScope(child: FamilyVaultApp()));
      await tester.pumpAndSettle();

      // 1. Verify unauthenticated redirect displays LoginScreen
      expect(find.text('DocNet'), findsWidgets);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);

      // 2. Enter credentials for test user and tap Sign In
      await tester.enterText(
        find.byKey(const ValueKey('login_email_field')),
        'test@familyvault.app',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login_password_field')),
        'Password123!',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // 3. Verify user is authenticated and navigated to Home Dashboard
      expect(find.text('This device is up to date.'), findsOneWidget);
      expect(find.text('Encrypted Storage'), findsOneWidget);
      expect(find.text('Recent Documents'), findsOneWidget);

      // Verify Bottom Navigation is present
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Spaces'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    },
  );
}
