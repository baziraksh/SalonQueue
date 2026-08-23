// Widget tests for the Salon Queue app.
//
// The tests run WITHOUT a Supabase connection: the app is wrapped in an
// AuthScope backed by an AuthService with no repository, which is exactly how
// main() behaves when SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY are not provided
// via --dart-define. In that mode every auth operation degrades to an
// unauthenticated state, which is what these tests assert.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/main.dart';

/// Builds the app the same way main() does when Supabase is unavailable.
Widget _buildTestApp() {
  final authService = AuthService(null);
  authService.initialize();
  return AuthScope(service: authService, child: const SalonQueueApp());
}

void main() {
  testWidgets('App opens directly to Welcome screen on unauthenticated launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    // Directly renders Welcome screen branding & role selection on launch
    expect(find.text('Salon Queue'), findsOneWidget);
    expect(find.text('Find Salons & Skip The Line 🇮🇳'), findsOneWidget);
    expect(find.text('I am a Customer'), findsOneWidget);
    expect(find.text('I am a Salon Owner'), findsOneWidget);
  });

  testWidgets('Customer entry button opens sign-in when unauthenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('I am a Customer'));
    await tester.pumpAndSettle();

    // Not authenticated → lands on the Customer Sign In screen.
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Salon owner entry button opens sign-in when unauthenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('I am a Salon Owner'));
    await tester.pumpAndSettle();

    // Not authenticated → lands on the Salon Owner Sign In screen.
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Sign-in screen navigates to sign-up', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    // Go to sign-in first.
    await tester.tap(find.text('I am a Customer'));
    await tester.pumpAndSettle();

    // Tap "Sign Up" from the sign-in screen.
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsWidgets);
  });

  testWidgets('Sign-in screen navigates to forgot password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    // Go to sign-in first.
    await tester.tap(find.text('I am a Customer'));
    await tester.pumpAndSettle();

    // Tap "Forgot password?" from the sign-in screen.
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsWidgets);
    expect(
      find.text("Enter your email and we'll send you a password reset link."),
      findsOneWidget,
    );
  });

  testWidgets('Forgot password form validates required fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    // Navigate to forgot password.
    await tester.tap(find.text('I am a Customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    // Tap "Send Reset Link" with empty email → validation error.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);
  });

  testWidgets('Sign-up form validates required fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    // Navigate to sign-up.
    await tester.tap(find.text('I am a Customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    // Tap the Create Account button (not the AppBar title, which shares
    // the same text) with empty fields → validation errors appear.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);
  });
}
