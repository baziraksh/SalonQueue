import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_auth;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../notifications/data/notification_repository.dart';
import '../../queue/data/queue_repository.dart';
import '../../salon/data/salon_repository.dart';
import '../data/auth_repository.dart';
import '../models/app_user.dart';

/// Application auth state - the single source of truth for the current user.
///
/// UI widgets consume this via [AuthScope] and rebuild when it notifies.
/// Never call Supabase directly from widgets - always go through this service.
///
/// The authoritative role always comes from the database (`profiles.role`).
/// The login screen's "requested role" is only a requested mode and is
/// checked against the stored role after authentication.
class AuthService extends ChangeNotifier {
  AuthService(this._repository);

  /// Nullable: when Supabase is not configured (tests / local dev),
  /// the service stays permanently unauthenticated.
  final AuthRepository? _repository;
  StreamSubscription<supabase_auth.AuthState>? _subscription;

  // ── State ────────────────────────────────────────────────────────────────
  AuthStatus _status = AuthStatus.checking;
  AppUser? _currentUser;
  String? _errorMessage;
  bool _initialized = false;
  bool _preserveError = false;
  bool _recoveryPending = false;
  final Completer<void> _initCompleter = Completer<void>();

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _currentUser != null && _currentUser!.isAuthenticated;
  bool get isLoading => _status == AuthStatus.checking;
  bool get initialized => _initialized;

  /// Returns a Future that completes when the initial session check and restoration finishes.
  Future<void> waitForInitialization({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_initialized) return;
    try {
      await _initCompleter.future.timeout(timeout);
    } catch (_) {
      if (!_initialized) {
        _initialized = true;
        notifyListeners();
      }
    }
  }

  /// Shortcut: true when the user is a customer (the most common path).
  bool get isCustomer => _currentUser?.role.isCustomer ?? false;

  /// Shortcut: true when the user is a salon owner.
  bool get isSalonOwner => _currentUser?.role.isSalonOwner ?? false;

  /// True when a PASSWORD_RECOVERY session is active (the user tapped the
  /// reset-email link and the deep link was processed).
  bool get recoveryPending => _recoveryPending;

  /// Whether the current user may access the given role's dashboard.
  bool canAccessRole(AppRole role) {
    final user = _currentUser;
    if (user == null || !user.isAuthenticated) return false;
    return user.role == role;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Call once after Supabase is initialized.
  void initialize() {
    final repo = _repository;
    if (repo == null) {
      // No Supabase configured → permanent unauthenticated state.
      _status = AuthStatus.unauthenticated;
      _initialized = true;
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      notifyListeners();
      return;
    }

    _subscription = repo.onAuthStateChange.listen(_onAuthEvent);

    // Check for an existing session (app restart / cold boot).
    if (repo.hasSession || repo.currentUser != null) {
      _restoreFromExistingSession(repo);
    } else {
      // Allow a short window for initialSession event from Supabase SDK
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!_initialized) {
          if (repo.hasSession || repo.currentUser != null) {
            _restoreFromExistingSession(repo);
          } else {
            _status = AuthStatus.unauthenticated;
            _initialized = true;
            if (!_initCompleter.isCompleted) _initCompleter.complete();
            notifyListeners();
          }
        }
      });
    }
  }

  Future<void> _restoreFromExistingSession(AuthRepository repo) async {
    final session = repo.currentSession;
    final user = repo.currentUser;

    // Proactively purge historical bloated tokens (> 2000 bytes) that cause HTTP 431 header overflows
    if (session != null && session.accessToken.length > 2000) {
      _logForDebug('Detected oversized JWT token (${session.accessToken.length} bytes). Purging bloated session...');
      try {
        await repo.signOut();
      } catch (_) {}
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      _initialized = true;
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      notifyListeners();
      return;
    }

    if (session != null && session.isExpired) {
      _logForDebug('Stored session is expired. Attempting token refresh...');
      final refreshRes = await repo.refreshSession();
      if (refreshRes?.session == null) {
        _logForDebug('Token refresh failed. Session is invalid.');
        await repo.signOut();
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = null;
        _initialized = true;
        if (!_initCompleter.isCompleted) _initCompleter.complete();
        notifyListeners();
        return;
      }
    }

    final activeUser = repo.currentUser ?? user;
    if (activeUser != null) {
      try {
        await repo.sanitizeUserMetadataIfNeeded(activeUser);
        _currentUser = await repo.buildAppUser(activeUser);
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        _logForDebug(
          'Session restored successfully: user=${_currentUser?.id}, role=${_currentUser?.role}',
        );
      } on Exception catch (e) {
        final errStr = e.toString();
        if (errStr.contains('431') || errStr.contains('400') || errStr.contains('Header') || errStr.contains('Too Large')) {
          _logForDebug('Detected HTTP header/cookie overflow ($errStr). Clearing bloated local session.');
          try {
            await repo.signOut();
          } catch (_) {}
        }
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = null;
      }
    } else {
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    }
    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
    notifyListeners();
  }

  Future<void> _onAuthEvent(supabase_auth.AuthState state) async {
    final repo = _repository;
    if (repo == null) return;

    final event = state.event;
    final session = state.session;

    _logForDebug('AuthChangeEvent received: $event');

    // `initialSession` fires on SDK startup with a session restored from
    // local storage. Treat it like a signed-in event.
    if (event == supabase_auth.AuthChangeEvent.signedIn ||
        event == supabase_auth.AuthChangeEvent.tokenRefreshed ||
        event == supabase_auth.AuthChangeEvent.initialSession) {
      final user = session?.user ?? repo.currentUser;
      if (user != null) {
        try {
          await repo.sanitizeUserMetadataIfNeeded(user);
          _currentUser = await repo.buildAppUser(user);
          _status = AuthStatus.authenticated;
          _errorMessage = null;
          _logForDebug(
            'Auth user updated from event: ${_currentUser?.id} (${_currentUser?.role})',
          );
        } on Exception catch (e) {
          _logForDebug('Auth user build failed on event: $e');
        }
      }
    } else if (event == supabase_auth.AuthChangeEvent.passwordRecovery) {
      // A password-recovery session was established by the deep link.
      // Route the user to the reset-password screen, not a dashboard.
      _recoveryPending = true;
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      _initialized = true;
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      notifyListeners();
      return;
    } else if (event == supabase_auth.AuthChangeEvent.signedOut) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      if (!_preserveError) {
        _errorMessage = null;
      }
    } else {
      return; // Ignore other events
    }

    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
    notifyListeners();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Creates a new account and inserts the corresponding profiles row with
  /// the chosen [role].
  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
    required AppRole role,
  }) async {
    final repo = _repository;
    _errorMessage = null;
    notifyListeners();

    if (repo == null) {
      _errorMessage =
          'Authentication service is currently unavailable. Please check your configuration.';
      notifyListeners();
      return;
    }

    try {
      _currentUser = await repo.signUp(
        email: email,
        password: password,
        fullName: fullName ?? '',
        role: role,
      );
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } on AuthException catch (e) {
      // Check if this is a "please confirm email" message.
      if (e.message.toLowerCase().contains('confirm')) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = e.message;
      } else {
        _errorMessage = e.message;
      }
    } on NetworkException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
    }
    notifyListeners();
  }

  /// Authenticates with email + password, then verifies the [requestedRole]
  /// matches the role stored in the database.
  ///
  /// Returns `true` only when the stored role matches the requested mode.
  /// On mismatch, the session is signed out and an error message is set.
  Future<bool> signIn({
    required String email,
    required String password,
    required AppRole requestedRole,
  }) async {
    _logForDebug('signIn requested role=$requestedRole');
    final repo = _repository;
    _errorMessage = null;
    notifyListeners();

    if (repo == null) {
      _errorMessage =
          'Authentication service is currently unavailable. Please check your configuration.';
      notifyListeners();
      return false;
    }

    try {
      final user = await repo.signIn(
        email: email,
        password: password,
      );

      // TEMP DEBUG — log the stored role from DB
      _logForDebug('signIn stored role=${user.role}, requested=$requestedRole');
      if (user.role != requestedRole) {
        // Sign out so no wrong-context session remains active, but keep the
        // rejection message — the signedOut auth event must not erase it.
        _preserveError = true;
        await repo.signOut();
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = user.role == AppRole.salonOwner
            ? 'This account is registered as a Salon Owner. '
                'Please use Salon Owner login.'
            : 'This account is registered as a Customer. '
                'Please use Customer login.';
        _preserveError = false;
        _logForDebug(
            'Sign-in role mismatch: requested=$requestedRole stored=${user.role}');
        notifyListeners();
        return false;
      }

      _currentUser = user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Clears the current session and resets state.
  Future<void> signOut() async {
    final repo = _repository;
    if (repo != null) {
      await repo.signOut();
    }
    AuthRepository.clearCache();
    SalonRepository.clearCache();
    NotificationRepository.clearCache();
    QueueRepository.clearLocalCache();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Requests a password reset email. Returns `true` on success.
  ///
  /// The result is intentionally generic — we never reveal whether an
  /// account exists for the given email.
  Future<bool> resetPassword(String email) async {
    final repo = _repository;
    _errorMessage = null;
    notifyListeners();

    if (repo == null) {
      _errorMessage =
          'Authentication service is currently unavailable. Please check your configuration.';
      notifyListeners();
      return false;
    }

    try {
      await repo.resetPasswordForEmail(
        email.trim(),
        redirectTo: AppConfig.resetPasswordRedirectUrl,
      );
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Unable to send the reset link. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Updates the password during a recovery session. Returns `true` on success.
  Future<bool> updatePassword(String newPassword) async {
    final repo = _repository;
    _errorMessage = null;
    notifyListeners();

    if (repo == null) {
      _errorMessage =
          'Unable to connect to the server. Please check your internet connection and try again.';
      notifyListeners();
      return false;
    }

    // The recovery session must be active before a password can be updated.
    if (!_recoveryPending && !repo.hasSession) {
      _errorMessage = 'Your password reset link is invalid or has expired. '
          'Please request a new one.';
      notifyListeners();
      return false;
    }

    try {
      await repo.updatePassword(newPassword);
      // Password updated — sign out the recovery session and return.
      await repo.signOut();
      _recoveryPending = false;
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Unable to update password. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Updates the avatar URL of the currently authenticated user in state.
  void updateCurrentUserAvatar(String? avatarUrl) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(avatarUrl: avatarUrl);
      notifyListeners();
    }
  }

  /// Updates the display full name of the currently authenticated user in state.
  void updateCurrentUserName(String fullName) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(fullName: fullName);
      notifyListeners();
    }
  }

  /// Updates profile details in local state and database
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        fullName: fullName ?? _currentUser!.fullName,
        phone: phone ?? _currentUser!.phone,
        avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
      );
      notifyListeners();
      await _repository?.updateProfile(
        userId: _currentUser!.id,
        fullName: fullName,
        phone: phone,
        avatarUrl: avatarUrl,
      );
    }
  }

  /// Refreshes the current user profile from the database.
  Future<void> refreshCurrentUser() async {
    try {
      final updated = await _repository?.fetchCurrentUser();
      if (updated != null) {
        _currentUser = updated;
        notifyListeners();
      }
    } catch (e) {
      _logForDebug('refreshCurrentUser failed: $e');
    }
  }

  /// Manually clears any displayed error.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Safe logging helper — never logs tokens or secrets.
  void _logForDebug(String message) {
    // In release builds this is compiled out. Debug output only.
    assert(() {
      debugPrint('[AuthService] $message');
      return true;
    }());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}