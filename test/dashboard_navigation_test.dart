// Widget tests for post-login dashboard navigation.
//
// Verifies the authentication-stack fix:
//   - The Salon Owner dashboard shows NO AppBar back arrow.
//   - The Customer dashboard shows NO AppBar back arrow.
//   - Both dashboards are wrapped in PopScope so the Android system back
//     button cannot return to an auth screen.
//   - The logout action signs out and navigates back to the welcome screen
//     (stack-clearing), instead of relying on pop.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salon_queue/core/routing/app_router.dart';
import 'package:salon_queue/features/auth/data/auth_repository.dart';
import 'package:salon_queue/features/auth/models/app_user.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/customer/screens/customer_entry_screen.dart';
import 'package:salon_queue/features/salon/screens/salon_entry_screen.dart';

/// Scripted repository returning a fixed user, no network.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.user) : super();

  final AppUser user;
  bool signedOut = false;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    return user;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

Future<AuthService> _authenticatedService(AppUser user) async {
  final service = AuthService(_FakeAuthRepository(user));
  await service.signIn(
    email: user.email ?? 'user@example.com',
    password: 'password123',
    requestedRole: user.role,
  );
  return service;
}

/// Creates a MaterialApp that uses the real AppRouter to generate routes,
/// including an [onGenerateInitialRoutes] that correctly places the
/// dashboard as the only route in the stack.
MaterialApp _appForRoute({
  required String initialRoute,
  required AuthService service,
}) {
  return MaterialApp(
    initialRoute: initialRoute,
    onGenerateRoute: AppRouter.generateRoute,
    onGenerateInitialRoutes: (initialRoute) {
      final route = AppRouter.generateRoute(RouteSettings(name: initialRoute));
      return [route];
    },
  );
}

void main() {
  group('Salon Owner Dashboard navigation', () {
    testWidgets('shows no back arrow and blocks system back', (tester) async {
      final service = await _authenticatedService(
        const AppUser(
            id: 'u2', email: 'o@example.com', role: AppRole.salonOwner),
      );

      await tester.pumpWidget(AuthScope(
        service: service,
        child: MaterialApp(home: const SalonEntryScreen()),
      ));
      await tester.pumpAndSettle();

      // No back arrow anywhere.
      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      // Hamburger menu is present.
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // System back is blocked.
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('logout signs out and returns to welcome screen',
        (tester) async {
      final repo = _FakeAuthRepository(
        const AppUser(
            id: 'u2', email: 'o@example.com', role: AppRole.salonOwner),
      );
      final service = AuthService(repo);
      await service.signIn(
        email: 'o@example.com',
        password: 'password123',
        requestedRole: AppRole.salonOwner,
      );

      await tester.pumpWidget(AuthScope(
        service: service,
        child: _appForRoute(
          initialRoute: AppRouter.salonEntry,
          service: service,
        ),
      ));
      await tester.pumpAndSettle();

      // Confirm we're on the salon dashboard.
      expect(find.byType(SalonEntryScreen), findsOneWidget);

      // Open drawer using hamburger menu
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Scroll drawer ListView to reveal Logout
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      // Tap Logout tile in drawer
      expect(find.text('Logout'), findsOneWidget);
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      // Confirm logout in modal
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
      await tester.pumpAndSettle();

      expect(repo.signedOut, isTrue);

      // Stack cleared — back on the Welcome screen.
      expect(find.byType(SalonEntryScreen), findsNothing);
      expect(find.text('I am a Customer'), findsOneWidget);
      expect(find.text('I am a Salon Owner'), findsOneWidget);
    });
  });

  group('Customer Dashboard navigation', () {
    testWidgets('shows no back arrow and blocks system back', (tester) async {
      final service = await _authenticatedService(
        const AppUser(
            id: 'u1', email: 'c@example.com', role: AppRole.customer),
      );

      await tester.pumpWidget(AuthScope(
        service: service,
        child: MaterialApp(home: const CustomerEntryScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.logout), findsOneWidget);

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });
  });
}
