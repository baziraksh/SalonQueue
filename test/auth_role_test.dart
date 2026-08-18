// Unit tests for role-based authentication & authorization.
//
// These tests exercise AuthService with a FakeAuthRepository, so no network
// and no Supabase client are needed. They verify the core security rule:
//   - The database role is authoritative.
//   - A login requested as Customer is rejected when the stored role is Owner.
//   - A login requested as Salon Owner is rejected when the stored role is
//     Customer.
//   - canAccessRole correctly enforces dashboard access.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:salon_queue/features/auth/data/auth_repository.dart';
import 'package:salon_queue/features/auth/models/app_user.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';

/// A scripted repository that returns a fixed stored role.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository(this.storedUser) : super();

  final _authEvents = StreamController<supabase.AuthState>.broadcast();

  AppUser storedUser;
  bool signOutCalled = false;

  @override
  Stream<supabase.AuthState> get onAuthStateChange => _authEvents.stream;

  /// Emits a password-recovery auth event (as the deep link would).
  void emitPasswordRecovery() {
    _authEvents.add(
      supabase.AuthState(
        supabase.AuthChangeEvent.passwordRecovery,
        null,
      ),
    );
  }

  // Reset password tracking
  bool resetPasswordCalled = false;
  String resetPasswordEmail = '';
  String? lastResetRedirectTo;

  // Update password tracking
  bool updatePasswordCalled = false;
  String? updatedPassword;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    return storedUser;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? fullName,
    required AppRole role,
  }) async {
    storedUser = AppUser(
      id: 'user-1',
      email: email,
      fullName: fullName,
      role: role,
    );
    return storedUser;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<bool> resetPasswordForEmail(String email, {String? redirectTo}) async {
    resetPasswordCalled = true;
    resetPasswordEmail = email;
    lastResetRedirectTo = redirectTo;
    return true;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatePasswordCalled = true;
    updatedPassword = newPassword;
  }
}

void main() {
  group('Role-based login', () {
    test('CUSTOMER account + Customer login → SUCCESS', () async {
      final service = AuthService(FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      ));
      service.initialize();

      final ok = await service.signIn(
        email: 'c@example.com',
        password: 'password123',
        requestedRole: AppRole.customer,
      );

      expect(ok, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUser?.role, AppRole.customer);
      expect(service.errorMessage, isNull);
    });

    test('CUSTOMER account + Salon Owner login → DENIED', () async {
      final service = AuthService(FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      ));
      service.initialize();

      final ok = await service.signIn(
        email: 'c@example.com',
        password: 'password123',
        requestedRole: AppRole.salonOwner,
      );

      expect(ok, isFalse);
      expect(service.isAuthenticated, isFalse);
      expect(
        service.errorMessage,
        contains('registered as a Customer'),
      );
    });

    test('SALON_OWNER account + Salon Owner login → SUCCESS', () async {
      final service = AuthService(FakeAuthRepository(
        const AppUser(
            id: 'u2', email: 'o@example.com', role: AppRole.salonOwner),
      ));
      service.initialize();

      final ok = await service.signIn(
        email: 'o@example.com',
        password: 'password123',
        requestedRole: AppRole.salonOwner,
      );

      expect(ok, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUser?.role, AppRole.salonOwner);
    });

    test('SALON_OWNER account + Customer login → DENIED', () async {
      final service = AuthService(FakeAuthRepository(
        const AppUser(
            id: 'u2', email: 'o@example.com', role: AppRole.salonOwner),
      ));
      service.initialize();

      final ok = await service.signIn(
        email: 'o@example.com',
        password: 'password123',
        requestedRole: AppRole.customer,
      );

      expect(ok, isFalse);
      expect(service.isAuthenticated, isFalse);
      expect(
        service.errorMessage,
        contains('registered as a Salon Owner'),
      );
    });

    test('Mismatched login signs out the freshly-created session', () async {
      final repo = FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      );
      final service = AuthService(repo);
      service.initialize();

      await service.signIn(
        email: 'c@example.com',
        password: 'password123',
        requestedRole: AppRole.salonOwner,
      );

      expect(repo.signOutCalled, isTrue);
    });
  });

  group('canAccessRole', () {
    test('Customer can access customer dashboard, not salon', () async {
      final service = AuthService(FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      ));
      service.initialize();

      await service.signIn(
        email: 'c@example.com',
        password: 'password123',
        requestedRole: AppRole.customer,
      );

      expect(service.canAccessRole(AppRole.customer), isTrue);
      expect(service.canAccessRole(AppRole.salonOwner), isFalse);
    });

    test('Salon Owner can access salon dashboard, not customer', () async {
      final service = AuthService(FakeAuthRepository(
        const AppUser(
            id: 'u2', email: 'o@example.com', role: AppRole.salonOwner),
      ));
      service.initialize();

      await service.signIn(
        email: 'o@example.com',
        password: 'password123',
        requestedRole: AppRole.salonOwner,
      );

      expect(service.canAccessRole(AppRole.salonOwner), isTrue);
      expect(service.canAccessRole(AppRole.customer), isFalse);
    });

    test('Unauthenticated user cannot access either dashboard', () async {
      final service = AuthService(FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      ));
      service.initialize();

      // Not signed in yet.
      expect(service.canAccessRole(AppRole.customer), isFalse);
      expect(service.canAccessRole(AppRole.salonOwner), isFalse);
    });
  });

  group('Sign-up stores the chosen role', () {
    test('Signup as Customer stores CUSTOMER', () async {
      final repo = FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      );
      final service = AuthService(repo);
      service.initialize();

      await service.signUp(
        email: 'new@example.com',
        password: 'password123',
        fullName: 'New Customer',
        role: AppRole.customer,
      );

      expect(service.isAuthenticated, isTrue);
      expect(repo.storedUser.role, AppRole.customer);
    });

    test('Signup as Salon Owner stores SALON_OWNER', () async {
      final repo = FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      );
      final service = AuthService(repo);
      service.initialize();

      await service.signUp(
        email: 'owner@example.com',
        password: 'password123',
        fullName: 'New Owner',
        role: AppRole.salonOwner,
      );

      expect(service.isAuthenticated, isTrue);
      expect(repo.storedUser.role, AppRole.salonOwner);
    });
  });

  group('Password reset', () {
    test('resetPassword requests reset email via repository with redirectTo',
        () async {
      final repo = FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      );
      final service = AuthService(repo);
      service.initialize();

      final ok = await service.resetPassword('user@example.com');

      expect(ok, isTrue);
      expect(repo.resetPasswordCalled, isTrue);
      expect(repo.resetPasswordEmail, 'user@example.com');
      expect(repo.lastResetRedirectTo,
          'salonqueue://auth/reset-password');
    });

    test('resetPassword trims the email before sending', () async {
      final repo = FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      );
      final service = AuthService(repo);
      service.initialize();

      await service.resetPassword('  user@example.com  ');

      expect(repo.resetPasswordEmail, 'user@example.com');
    });

    test('passwordRecovery event sets recoveryPending', () async {
      final repo = FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      );
      final service = AuthService(repo);
      service.initialize();

      repo.emitPasswordRecovery();
      await Future<void>.delayed(Duration.zero);

      expect(service.recoveryPending, isTrue);
      expect(service.isAuthenticated, isFalse);
    });

    test('updatePassword updates password via repository and signs out',
        () async {
      final repo = FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      );
      final service = AuthService(repo);
      service.initialize();

      // Establish a recovery session the way the deep link does.
      repo.emitPasswordRecovery();
      await Future<void>.delayed(Duration.zero);
      expect(service.recoveryPending, isTrue);

      final ok = await service.updatePassword('newPassword123');

      expect(ok, isTrue);
      expect(repo.updatePasswordCalled, isTrue);
      expect(repo.updatedPassword, 'newPassword123');
      expect(repo.signOutCalled, isTrue);
      expect(service.recoveryPending, isFalse);
      expect(service.isAuthenticated, isFalse);
    });

    test('updatePassword fails when no recovery session', () async {
      final repo = FakeAuthRepository(
        const AppUser(id: 'u1', email: 'c@example.com', role: AppRole.customer),
      );
      final service = AuthService(repo);
      service.initialize();

      // No recovery session — updatePassword should fail.
      final ok = await service.updatePassword('newPassword123');

      expect(ok, isFalse);
      expect(repo.updatePasswordCalled, isFalse);
      expect(service.errorMessage,
          contains('reset link is invalid or has expired'));
    });
  });
}
