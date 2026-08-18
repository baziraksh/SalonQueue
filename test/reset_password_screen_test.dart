// Widget tests for the Reset New Password screen.
//
// Verifies the recovery-session password update flow:
//   - Password validation (too short)
//   - Confirmation mismatch detection
//   - Successful password update shows the success message
//   - A form with mismatched passwords does not submit

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:salon_queue/core/routing/app_router.dart';
import 'package:salon_queue/features/auth/data/auth_repository.dart';
import 'package:salon_queue/features/auth/screens/reset_password_screen.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';

/// Scripted repository; updatePassword always succeeds.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super();

  final _authEvents = StreamController<supabase.AuthState>.broadcast();

  bool updatePasswordCalled = false;
  String? updatedPassword;

  @override
  Stream<supabase.AuthState> get onAuthStateChange =>
      _authEvents.stream;

  void emitPasswordRecovery() {
    _authEvents.add(
      supabase.AuthState(
        supabase.AuthChangeEvent.passwordRecovery,
        null,
      ),
    );
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatePasswordCalled = true;
    updatedPassword = newPassword;
  }

  @override
  Future<void> signOut() async {}
}

/// Builds an AuthService in a recovery state (as the deep link does).
///
/// The PASSWORD_RECOVERY event is emitted into the stream; it is delivered to
/// the AuthService subscription during the caller's `pumpWidget`/`pump`
/// (microtask flush), so no explicit timer await is needed here.
Future<AuthService> _recoveryService() async {
  final repo = _FakeAuthRepository();
  final service = AuthService(repo);

  service.initialize();

  repo.emitPasswordRecovery();

  return service;
}

Future<void> _pumpResetScreen(
    WidgetTester tester,
    AuthService service,
    ) async {
  await tester.pumpWidget(
    AuthScope(
      service: service,
      child: const MaterialApp(
        home: ResetPasswordScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _enterPasswords(
    WidgetTester tester, {
      required String password,
      required String confirm,
    }) async {
  await tester.enterText(
    find.widgetWithText(
      TextFormField,
      'New Password',
    ),
    password,
  );

  await tester.enterText(
    find.widgetWithText(
      TextFormField,
      'Confirm Password',
    ),
    confirm,
  );
}

void main() {
  testWidgets(
    'recovery session routes to reset password screen',
        (tester) async {
      final repo = _FakeAuthRepository();
      final service = AuthService(repo);

      service.initialize();

      await tester.pumpWidget(
        AuthScope(
          service: service,
          child: MaterialApp(
            initialRoute: AppRouter.splash,
            onGenerateRoute: AppRouter.generateRoute,
            onGenerateInitialRoutes: (initialRoute) {
              return [
                AppRouter.generateRoute(
                  RouteSettings(name: initialRoute),
                ),
              ];
            },
          ),
        ),
      );

      // Simulate the deep link delivering the PASSWORD_RECOVERY auth event.
      repo.emitPasswordRecovery();
      await tester.pump();

      // Advance past the 2000 ms splash timer so the auth check runs, then
      // give the route transition time to finish.
      // Deliberately avoid pumpAndSettle(): the SplashScreen shows an
      // indeterminate CircularProgressIndicator, which schedules frames
      // indefinitely, so pumpAndSettle() would never observe an idle state.
      await tester.pump(
        const Duration(milliseconds: 2100),
      );

      await tester.pump(
        const Duration(milliseconds: 500),
      );

      expect(
        find.text('Create a new password'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'validates that new password meets minimum length',
        (tester) async {
      final service = await _recoveryService();

      await _pumpResetScreen(
        tester,
        service,
      );

      await _enterPasswords(
        tester,
        password: 'short',
        confirm: 'short',
      );

      await tester.tap(
        find.text('Update Password'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows error when passwords do not match',
        (tester) async {
      final service = await _recoveryService();

      await _pumpResetScreen(
        tester,
        service,
      );

      await _enterPasswords(
        tester,
        password: 'newPassword123',
        confirm: 'differentPass1',
      );

      await tester.tap(
        find.text('Update Password'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Passwords do not match'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'successful password update shows success message',
        (tester) async {
      final service = await _recoveryService();

      await _pumpResetScreen(
        tester,
        service,
      );

      await _enterPasswords(
        tester,
        password: 'newPassword123',
        confirm: 'newPassword123',
      );

      await tester.tap(
        find.text('Update Password'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Password updated successfully.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'password update with mismatched confirmation does not submit',
        (tester) async {
      final repo = _FakeAuthRepository();
      final service = AuthService(repo);

      service.initialize();

      repo.emitPasswordRecovery();

      await _pumpResetScreen(
        tester,
        service,
      );

      await _enterPasswords(
        tester,
        password: 'newPassword123',
        confirm: 'differentPass1',
      );

      await tester.tap(
        find.text('Update Password'),
      );

      await tester.pumpAndSettle();

      expect(
        repo.updatePasswordCalled,
        isFalse,
      );
    },
  );
}