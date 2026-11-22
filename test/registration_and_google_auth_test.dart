import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/main.dart';
import 'package:docnet/features/auth/presentation/login_screen.dart';
import 'package:docnet/features/auth/presentation/register_screen.dart';

void main() {
  group('Registration and Google Sign-In Flow Tests', () {
    testWidgets(
      'LoginScreen navigates to dedicated RegisterScreen with proper details',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(const ProviderScope(child: FamilyVaultApp()));
        await tester.pumpAndSettle();

        // 1. Verify Login screen is displayed
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text("Don't have an account? Create one"), findsOneWidget);

        // 2. Tap to navigate to Registration screen
        await tester.tap(find.text("Don't have an account? Create one"));
        await tester.pumpAndSettle();

        // 3. Verify dedicated RegisterScreen is displayed with all proper fields
        expect(find.byType(RegisterScreen), findsOneWidget);
        expect(find.text('Create Account'), findsWidgets);
        expect(find.byKey(const ValueKey('reg_fullname')), findsOneWidget);
        expect(find.byKey(const ValueKey('reg_email')), findsOneWidget);
        expect(find.byKey(const ValueKey('reg_password')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('reg_confirm_password')),
          findsOneWidget,
        );
        expect(find.text('Sign up with Google'), findsOneWidget);
        expect(find.textContaining('End-to-End Encrypted'), findsOneWidget);

        // 4. Test validation errors on empty submission
        await tester.ensureVisible(
          find.byKey(const ValueKey('reg_submit_btn')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reg_submit_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your full name'), findsOneWidget);
        expect(find.text('Please enter your email'), findsOneWidget);
        expect(find.text('Please enter a password'), findsOneWidget);

        // 5. Test password mismatch validation
        await tester.enterText(
          find.byKey(const ValueKey('reg_fullname')),
          'Parth Godhani',
        );
        await tester.enterText(
          find.byKey(const ValueKey('reg_email')),
          'parth@familyvault.app',
        );
        await tester.enterText(
          find.byKey(const ValueKey('reg_password')),
          'SecretPass123!',
        );
        await tester.enterText(
          find.byKey(const ValueKey('reg_confirm_password')),
          'DifferentPass456!',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const ValueKey('reg_submit_btn')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reg_submit_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Passwords do not match'), findsOneWidget);

        // 6. Test Google Sign-Up triggers without manual input dialog
        await tester.ensureVisible(
          find.byKey(const ValueKey('reg_google_btn')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reg_google_btn')));
        await tester.pumpAndSettle();

        // Verify no fake text dialog popped up
        expect(find.text('Google Name'), findsNothing);
        expect(find.text('Google Email'), findsNothing);

        // Authenticated redirect to Home
        expect(find.text('This device is up to date.'), findsOneWidget);
      },
    );

    testWidgets(
      'LoginScreen Google Sign-In triggers without manual input dialog',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(const ProviderScope(child: FamilyVaultApp()));
        await tester.pumpAndSettle();

        // Tap Google Sign-In on Login screen
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Sign in with Google'),
        );
        await tester.pumpAndSettle();

        // Verify no fake text dialog popped up
        expect(find.text('Google Name'), findsNothing);
        expect(find.text('Google Email'), findsNothing);

        // Successfully authenticated to Home
        expect(find.text('This device is up to date.'), findsOneWidget);
      },
    );
  });
}
