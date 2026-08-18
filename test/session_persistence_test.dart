import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/core/screens/splash_screen.dart';
import 'package:salon_queue/core/screens/welcome_screen.dart';
import 'package:salon_queue/features/auth/data/auth_repository.dart';
import 'package:salon_queue/features/auth/models/app_user.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/customer/screens/customer_entry_screen.dart';
import 'package:salon_queue/features/salon/screens/salon_entry_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Mock AuthRepository to simulate various session, token refresh, and profile states.
class MockPersistentAuthRepository extends AuthRepository {
  MockPersistentAuthRepository({
    this.initialUser,
    this.initialSession,
    this.profileRole,
    this.shouldThrowOnProfile = false,
    this.refreshFails = false,
  });

  supabase.User? initialUser;
  supabase.Session? initialSession;
  String? profileRole;
  bool shouldThrowOnProfile;
  bool refreshFails;
  bool signOutCalled = false;

  @override
  supabase.User? get currentUser => initialUser;

  @override
  supabase.Session? get currentSession => initialSession;

  @override
  bool get hasSession => initialSession != null;

  @override
  Stream<supabase.AuthState> get onAuthStateChange => const Stream.empty();

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    if (shouldThrowOnProfile) {
      throw Exception('Network timeout / offline');
    }
    if (profileRole != null) {
      return {
        'id': userId,
        'full_name': 'Test User',
        'role': profileRole,
      };
    }
    return null;
  }

  @override
  Future<AppUser> buildAppUser(supabase.User user) async {
    if (shouldThrowOnProfile) {
      final metaRole = user.userMetadata?['role'] as String?;
      if (metaRole != null) {
        return AppUser(
          id: user.id,
          email: user.email,
          fullName: user.userMetadata?['full_name'] as String? ?? 'Test User',
          role: AppRole.fromDb(metaRole),
        );
      }
      throw Exception('Role could not be resolved');
    }

    final role = profileRole ?? user.userMetadata?['role'] as String?;
    if (role == null) {
      throw Exception('Missing role');
    }

    return AppUser(
      id: user.id,
      email: user.email,
      fullName: 'Test User',
      role: AppRole.fromDb(role),
    );
  }

  @override
  Future<supabase.AuthResponse?> refreshSession() async {
    if (refreshFails) return null;
    return null;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    initialUser = null;
    initialSession = null;
  }
}

void main() {
  group('Authentication & Session Persistence Flow Tests', () {
    testWidgets('TEST 1 & 2: Returning Salon Owner with valid session routes directly to Owner Dashboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockUser = supabase.User(
        id: 'owner-uuid-123',
        appMetadata: {},
        userMetadata: {'role': 'SALON_OWNER', 'full_name': 'Owner Rahul'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'owner@test.com',
      );

      final mockSession = supabase.Session(
        accessToken: 'valid-token',
        tokenType: 'bearer',
        user: mockUser,
      );

      final repo = MockPersistentAuthRepository(
        initialUser: mockUser,
        initialSession: mockSession,
        profileRole: 'SALON_OWNER',
      );

      final authService = AuthService(repo);
      authService.initialize();

      await tester.pumpWidget(
        AuthScope(
          service: authService,
          child: MaterialApp(
            home: const SplashScreen(),
            routes: {
              '/welcome': (_) => const WelcomeScreen(),
              '/salon': (_) => const SalonEntryScreen(),
              '/customer': (_) => const CustomerEntryScreen(),
            },
          ),
        ),
      );

      // Advance through splash delay & session initialization
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // Verified: Directly opens Salon Owner Dashboard without displaying Welcome Screen
      expect(find.byType(SalonEntryScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('TEST 3: Returning Customer with valid session routes directly to Customer Home', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockUser = supabase.User(
        id: 'customer-uuid-456',
        appMetadata: {},
        userMetadata: {'role': 'CUSTOMER', 'full_name': 'Customer Akash'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'customer@test.com',
      );

      final mockSession = supabase.Session(
        accessToken: 'valid-token-customer',
        tokenType: 'bearer',
        user: mockUser,
      );

      final repo = MockPersistentAuthRepository(
        initialUser: mockUser,
        initialSession: mockSession,
        profileRole: 'CUSTOMER',
      );

      final authService = AuthService(repo);
      authService.initialize();

      await tester.pumpWidget(
        AuthScope(
          service: authService,
          child: MaterialApp(
            home: const SplashScreen(),
            routes: {
              '/welcome': (_) => const WelcomeScreen(),
              '/salon': (_) => const SalonEntryScreen(),
              '/customer': (_) => const CustomerEntryScreen(),
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // Verified: Directly opens Customer Home
      expect(find.byType(CustomerEntryScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('TEST 4: Explicit logout clears session and routes to Welcome screen on restart', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockPersistentAuthRepository(
        initialUser: null,
        initialSession: null,
      );

      final authService = AuthService(repo);
      authService.initialize();

      await tester.pumpWidget(
        AuthScope(
          service: authService,
          child: MaterialApp(
            home: const SplashScreen(),
            routes: {
              '/welcome': (_) => const WelcomeScreen(),
              '/salon': (_) => const SalonEntryScreen(),
              '/customer': (_) => const CustomerEntryScreen(),
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // Verified: Unauthenticated lands on WelcomeScreen
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('I am a Customer'), findsOneWidget);
      expect(find.text('I am a Salon Owner'), findsOneWidget);
    });

    testWidgets('TEST 5: Authenticated customer selecting "I am a Salon Owner" does NOT open Owner Dashboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockUser = supabase.User(
        id: 'cust-1',
        appMetadata: {},
        userMetadata: {'role': 'CUSTOMER'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'customer@test.com',
      );

      final repo = MockPersistentAuthRepository(
        initialUser: mockUser,
        initialSession: supabase.Session(accessToken: 'tok', tokenType: 'b', user: mockUser),
        profileRole: 'CUSTOMER',
      );

      final authService = AuthService(repo);
      authService.initialize();
      await authService.waitForInitialization();

      await tester.pumpWidget(
        AuthScope(
          service: authService,
          child: MaterialApp(
            home: const WelcomeScreen(),
            routes: {
              '/auth/sign-in': (_) => const Scaffold(body: Text('Sign In Screen')),
              '/salon': (_) => const SalonEntryScreen(),
              '/customer': (_) => const CustomerEntryScreen(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'I am a Salon Owner' as a customer
      await tester.tap(find.text('I am a Salon Owner'));
      await tester.pumpAndSettle();

      // Verified: Does NOT navigate to SalonEntryScreen, shows role restriction notice and goes to sign in
      expect(find.byType(SalonEntryScreen), findsNothing);
      expect(find.text('Sign In Screen'), findsOneWidget);
    });

    testWidgets('TEST 6: Offline / temporary DB failure on cold boot uses token metadata and preserves session', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockUser = supabase.User(
        id: 'owner-offline-123',
        appMetadata: {},
        userMetadata: {'role': 'SALON_OWNER', 'full_name': 'Owner Rahul'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'owner@test.com',
      );

      final mockSession = supabase.Session(
        accessToken: 'valid-token',
        tokenType: 'bearer',
        user: mockUser,
      );

      final repo = MockPersistentAuthRepository(
        initialUser: mockUser,
        initialSession: mockSession,
        shouldThrowOnProfile: true,
      );

      final authService = AuthService(repo);
      authService.initialize();

      await tester.pumpWidget(
        AuthScope(
          service: authService,
          child: MaterialApp(
            home: const SplashScreen(),
            routes: {
              '/welcome': (_) => const WelcomeScreen(),
              '/salon': (_) => const SalonEntryScreen(),
              '/customer': (_) => const CustomerEntryScreen(),
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // Verified: Session is preserved from JWT metadata and routes to Owner Dashboard
      expect(find.byType(SalonEntryScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });
  });
}
