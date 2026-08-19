import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exceptions.dart';
import '../models/app_user.dart';

/// Data-access layer for authentication and profile data.
///
/// All Supabase calls live here. UI must not call Supabase directly —
/// it goes through [AuthService] (state) → [AuthRepository] (data).
///
/// The authoritative role comes from the `profiles.role` column in the
/// database. The selected login type in the UI is only a requested mode; the
/// database role decides which dashboard the user may access.
class AuthRepository {
  // ignore: prefer_initializing_formals
  AuthRepository({
    supabase.SupabaseClient? client,
    this.useSingletonFallback = true,
  }) : _client = client;

  final supabase.SupabaseClient? _client;
  final bool useSingletonFallback;

  supabase.SupabaseClient? get client {
    if (_client != null) return _client;
    if (!useSingletonFallback) return null;
    try {
      return supabase.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Whether a real Supabase client is configured.
  bool get isAvailable => client != null;

  /// Current authenticated Supabase user, or null.
  supabase.User? get currentUser => client?.auth.currentUser;

  /// Current active Supabase session, or null.
  supabase.Session? get currentSession => client?.auth.currentSession;

  /// Whether a session currently exists.
  bool get hasSession => client?.auth.currentSession != null;

  /// Stream of auth state changes from Supabase (empty when unavailable).
  Stream<supabase.AuthState> get onAuthStateChange {
    final activeClient = client;
    if (activeClient == null) return const Stream.empty();
    return activeClient.auth.onAuthStateChange;
  }

  /// Attempts to refresh the current session using the stored refresh token.
  Future<supabase.AuthResponse?> refreshSession() async {
    final activeClient = client;
    if (activeClient == null) return null;
    try {
      final response = await activeClient.auth.refreshSession();
      return response;
    } catch (e) {
      debugPrint('[AuthRepository] refreshSession error: $e');
      return null;
    }
  }

  // ── Authentication ──────────────────────────────────────────────────────

  /// Signs up a new user with email + password and the chosen [role].
  ///
  /// Authentication is handled entirely by Supabase Auth. No fake/offline
  /// fallback is used.
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? fullName,
    required AppRole role,
  }) async {
    final activeClient = client;
    if (activeClient == null) {
      throw AuthException(
        'Authentication service is currently unavailable. Please check your configuration.',
      );
    }

    try {
      final response = await activeClient.auth.signUp(
        email: email,
        password: password,
        data: {
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
          'role': role.dbName,
        },
      );

      final user = response.user;
      if (user == null) {
        throw AuthException('Sign up did not return a user.');
      }

      // No session means email confirmation is required.
      if (response.session == null) {
        throw AuthException(
          'Please check your email to confirm your account before signing in.',
        );
      }

      await _ensureProfile(user.id, fullName: fullName, role: role.dbName);
      return await buildAppUser(user);
    } on AppException {
      rethrow;
    } on supabase.AuthException catch (e) {
      throw AuthException(_translateAuthError(e.message));
    } on SocketException {
      throw NetworkException(
        'Unable to connect. Please check your internet connection and try again.',
      );
    } on TimeoutException {
      throw NetworkException(
        'Unable to connect. Please check your internet connection and try again.',
      );
    } catch (e) {
      final msg = e.toString();
      final lower = msg.toLowerCase();
      if (_isNetworkError(lower)) {
        throw NetworkException(
          'Unable to connect. Please check your internet connection and try again.',
        );
      }
      throw AuthException(_translateAuthError(msg));
    }
  }

  /// Signs in an existing user with email + password.
  ///
  /// Authentication is handled entirely by Supabase Auth. No fake/offline
  /// fallback is used.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final activeClient = client;
    if (activeClient == null) {
      throw AuthException(
        'Authentication service is currently unavailable. Please check your configuration.',
      );
    }

    try {
      // 1. Attempt pre-auth metadata cleanup to prevent oversized GoTrue JWTs
      try {
        await activeClient.rpc('clean_user_metadata_for_login', params: {
          'user_email': email.trim().toLowerCase(),
        }).timeout(const Duration(seconds: 3));
      } catch (_) {}

      final response = await activeClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw AuthException('Sign in did not return a user.');
      }

      // Proactively sanitize any bloated metadata to prevent HTTP 431 header overflow
      await sanitizeUserMetadataIfNeeded(user);

      // Backfill a missing profile (e.g., signup with email confirmation).
      final metaRole = user.userMetadata?['role'];
      final metaName = user.userMetadata?['full_name'];
      await _ensureProfile(
        user.id,
        fullName: metaName is String ? metaName : null,
        role: metaRole is String ? metaRole : null,
      );

      return await buildAppUser(user);
    } on AppException {
      rethrow;
    } on supabase.AuthException catch (e) {
      throw AuthException(_translateAuthError(e.message));
    } on SocketException {
      throw NetworkException(
        'Unable to connect. Please check your internet connection and try again.',
      );
    } on TimeoutException {
      throw NetworkException(
        'Unable to connect. Please check your internet connection and try again.',
      );
    } catch (e) {
      final msg = e.toString();
      final lower = msg.toLowerCase();
      if (_isNetworkError(lower)) {
        throw NetworkException(
          'Unable to connect. Please check your internet connection and try again.',
        );
      }
      throw AuthException(_translateAuthError(msg));
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    final activeClient = client;
    if (activeClient == null) return;
    try {
      await activeClient.auth.signOut();
    } on Exception {
      // Sign-out failure is non-fatal for the app; ignore.
    }
  }

  /// Sends a password reset email via Supabase Auth.
  Future<bool> resetPasswordForEmail(
    String email, {
    String? redirectTo,
  }) async {
    final activeClient = client;
    if (activeClient == null) {
      throw AuthException(
        'Authentication service is currently unavailable. Please check your configuration.',
      );
    }

    try {
      await activeClient.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo ?? AppConfig.resetPasswordRedirectUrl,
      );
      return true;
    } on supabase.AuthException catch (e) {
      throw AuthException(_translateAuthError(e.message));
    } catch (e) {
      final msg = e.toString();
      final lower = msg.toLowerCase();
      if (_isNetworkError(lower)) {
        throw NetworkException(
          'Unable to connect. Please check your internet connection and try again.',
        );
      }
      throw AuthException(_translateAuthError(msg));
    }
  }

  /// Updates the current user's password.
  Future<void> updatePassword(String newPassword) async {
    final activeClient = client;
    if (activeClient == null) {
      throw AuthException(
        'Authentication service is currently unavailable. Please check your configuration.',
      );
    }

    if (activeClient.auth.currentSession == null) {
      throw AuthException(
        'Your password reset link is invalid or has expired. Please request a new one.',
      );
    }

    try {
      await activeClient.auth
          .updateUser(supabase.UserAttributes(password: newPassword));
    } on supabase.AuthException catch (e) {
      throw AuthException(_translateAuthError(e.message));
    } catch (e) {
      final msg = e.toString();
      final lower = msg.toLowerCase();
      if (_isNetworkError(lower)) {
        throw NetworkException(
          'Unable to connect. Please check your internet connection and try again.',
        );
      }
      throw AuthException(_translateAuthError(msg));
    }
  }

  // ── Profile / User Building ─────────────────────────────────────────────

  /// Builds an [AppUser] from a Supabase [User].
  ///
  /// The role is read from the `profiles.role` column (authoritative),
  /// with safe fallback to `user.userMetadata['role']` or [defaultRole] if the database query
  /// fails or is unreachable during cold boot.
  Future<AppUser> buildAppUser(supabase.User user) async {
    debugPrint('[AuthRepository] AUTH USER ID: ${user.id}');
    debugPrint('[AuthRepository] AUTH USER EMAIL: ${user.email}');

    Map<String, dynamic>? profile;
    try {
      profile = await _fetchProfile(user.id);
    } catch (e) {
      debugPrint('[AuthRepository] Profile fetch error (will use user metadata fallback): $e');
    }

    debugPrint('[AuthRepository] PROFILE ROLE FIELD: ${profile?['role']}');

    var roleValue = profile?['role'] as String?;
    if (roleValue == null ||
        (roleValue != 'CUSTOMER' && roleValue != 'SALON_OWNER')) {
      // Fallback to userMetadata persisted inside Supabase session JWT
      final metaRole = user.userMetadata?['role'] as String? ??
          user.appMetadata['role'] as String?;
      if (metaRole != null &&
          (metaRole.toUpperCase() == 'CUSTOMER' ||
              metaRole.toUpperCase() == 'SALON_OWNER')) {
        roleValue = metaRole.toUpperCase();
        debugPrint('[AuthRepository] Using userMetadata role fallback: $roleValue');
        unawaited(_ensureProfile(user.id, role: roleValue));
      }
    }

    if (roleValue == null ||
        (roleValue != 'CUSTOMER' && roleValue != 'SALON_OWNER')) {
      roleValue = 'CUSTOMER';
      debugPrint('[AuthRepository] Using safe default role: $roleValue');
      unawaited(_ensureProfile(user.id, role: roleValue));
    }

    return AppUser(
      id: user.id,
      email: user.email,
      fullName: profile?['full_name'] as String? ??
          user.userMetadata?['full_name'] as String?,
      phone: profile?['phone'] as String?,
      avatarUrl: profile?['avatar_url'] as String? ??
          user.userMetadata?['avatar_url'] as String?,
      role: AppRole.fromDb(roleValue),
    );
  }

  /// Sanitizes bloated user metadata (such as historical base64 avatar images)
  /// that would inflate the GoTrue JWT beyond HTTP header size limits (causing PostgREST 431).
  Future<void> sanitizeUserMetadataIfNeeded(supabase.User user) async {
    final activeClient = client;
    if (activeClient == null) return;
    final metadata = user.userMetadata;
    if (metadata == null) return;

    bool needsCleanup = false;
    final cleanedData = <String, dynamic>{};

    const allowedKeys = {'role', 'full_name', 'phone'};
    for (final entry in metadata.entries) {
      final key = entry.key;
      final val = entry.value;
      if (!allowedKeys.contains(key) || (val is String && (val.startsWith('data:') || val.length > 200))) {
        cleanedData[key] = null;
        needsCleanup = true;
      }
    }

    if (needsCleanup) {
      try {
        debugPrint(
          '[AuthRepository] Sanitizing bloated userMetadata to prevent HTTP 431 header overflow...',
        );
        await activeClient.auth.updateUser(
          supabase.UserAttributes(data: cleanedData),
        );
        await activeClient.auth.refreshSession();
        debugPrint(
          '[AuthRepository] Successfully sanitized userMetadata and refreshed session.',
        );
      } catch (e) {
        debugPrint('[AuthRepository] Failed to sanitize userMetadata: $e');
      }
    }
  }

  /// Fetches the user's profile row, or null if absent / timeout.
  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    final activeClient = client;
    if (activeClient == null) return null;

    try {
      final row = await activeClient
          .from('profiles')
          .select('id, full_name, phone, avatar_url, role')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      return row;
    } on supabase.PostgrestException catch (e) {
      if (e.code == '431' ||
          e.message.contains('431') ||
          e.details?.toString().contains('431') == true) {
        debugPrint(
          '[AuthRepository] Caught HTTP 431 in _fetchProfile. Sanitizing metadata and retrying...',
        );
        final currentUser = activeClient.auth.currentUser;
        if (currentUser != null) {
          await sanitizeUserMetadataIfNeeded(currentUser);
          try {
            return await activeClient
                .from('profiles')
                .select('id, full_name, phone, avatar_url, role')
                .eq('id', userId)
                .maybeSingle()
                .timeout(const Duration(seconds: 15));
          } catch (retryErr) {
            debugPrint(
              '[AuthRepository] Retry after HTTP 431 failed in _fetchProfile: $retryErr',
            );
          }
        }
      }
      debugPrint('[AuthRepository] PROFILE QUERY ERROR (user=$userId): $e');
      return null;
    } on Exception catch (e) {
      debugPrint('[AuthRepository] PROFILE QUERY ERROR (user=$userId): $e');
      return null;
    }
  }

  /// Internal helper to upload isolated owner files into Supabase Storage buckets ('salon_images' or 'avatars').
  Future<String> _uploadIsolatedStorageFile({
    required String bucketPath,
    required Uint8List imageBytes,
    String contentType = 'image/jpeg',
  }) async {
    final activeClient = client;
    if (activeClient != null) {
      // 1. Try 'salon_images' bucket
      try {
        await activeClient.storage.from('salon_images').uploadBinary(
          bucketPath,
          imageBytes,
          fileOptions: supabase.FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );
        final publicUrl =
            activeClient.storage.from('salon_images').getPublicUrl(bucketPath);
        if (publicUrl.isNotEmpty) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          return '$publicUrl?t=$timestamp';
        }
      } catch (storageErr) {
        debugPrint(
          '[AuthRepository] salon_images bucket upload notice: $storageErr',
        );
      }

      // 2. Try 'avatars' bucket
      try {
        await activeClient.storage.from('avatars').uploadBinary(
          bucketPath,
          imageBytes,
          fileOptions: supabase.FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );
        final publicUrl =
            activeClient.storage.from('avatars').getPublicUrl(bucketPath);
        if (publicUrl.isNotEmpty) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          return '$publicUrl?t=$timestamp';
        }
      } catch (storageErr) {
        debugPrint(
          '[AuthRepository] avatars bucket upload notice: $storageErr',
        );
      }
    }

    // High-fidelity fallback that persists directly in database.
    return 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
  }

  /// Uploads an owner's profile picture to an isolated folder: owners/{userId}/profile/...
  Future<String> uploadOwnerProfilePhoto({
    required String userId,
    required Uint8List imageBytes,
    String fileExt = 'jpg',
  }) async {
    final cleanExt = fileExt.toLowerCase().replaceAll('.', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'owners/$userId/profile/profile_$timestamp.$cleanExt';
    return _uploadIsolatedStorageFile(
      bucketPath: path,
      imageBytes: imageBytes,
      contentType: cleanExt == 'png' ? 'image/png' : 'image/jpeg',
    );
  }

  /// Uploads an owner's salon cover photo to an isolated folder: owners/{userId}/cover/...
  Future<String> uploadOwnerCoverPhoto({
    required String userId,
    required Uint8List imageBytes,
    String fileExt = 'jpg',
  }) async {
    final cleanExt = fileExt.toLowerCase().replaceAll('.', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'owners/$userId/cover/cover_$timestamp.$cleanExt';
    return _uploadIsolatedStorageFile(
      bucketPath: path,
      imageBytes: imageBytes,
      contentType: cleanExt == 'png' ? 'image/png' : 'image/jpeg',
    );
  }

  /// Uploads an owner's salon gallery photo to an isolated folder: owners/{userId}/gallery/...
  Future<String> uploadOwnerGalleryPhoto({
    required String userId,
    required Uint8List imageBytes,
    String fileExt = 'jpg',
  }) async {
    final cleanExt = fileExt.toLowerCase().replaceAll('.', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'owners/$userId/gallery/gallery_$timestamp.$cleanExt';
    return _uploadIsolatedStorageFile(
      bucketPath: path,
      imageBytes: imageBytes,
      contentType: cleanExt == 'png' ? 'image/png' : 'image/jpeg',
    );
  }

  /// Uploads an owner's post / style photo to an isolated folder: owners/{userId}/posts/...
  Future<String> uploadOwnerPostPhoto({
    required String userId,
    required Uint8List imageBytes,
    String fileExt = 'jpg',
  }) async {
    final cleanExt = fileExt.toLowerCase().replaceAll('.', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'owners/$userId/posts/post_$timestamp.$cleanExt';
    return _uploadIsolatedStorageFile(
      bucketPath: path,
      imageBytes: imageBytes,
      contentType: cleanExt == 'png' ? 'image/png' : 'image/jpeg',
    );
  }

  /// Uploads a user's profile image to Supabase Storage in an isolated path.
  Future<String> uploadProfileImage({
    required String userId,
    required Uint8List imageBytes,
    String fileExt = 'jpg',
  }) async {
    return uploadOwnerProfilePhoto(
      userId: userId,
      imageBytes: imageBytes,
      fileExt: fileExt,
    );
  }

  /// Deletes a user's profile image from Supabase Storage and sets `avatar_url` to null in profiles table.
  Future<void> deleteProfileImage({
    required String userId,
    String? photoUrl,
  }) async {
    final activeClient = client;
    if (activeClient == null || userId.isEmpty) return;

    // 1. Delete image file from Supabase Storage bucket ('avatars') if present
    try {
      final fileNamesToRemove = <String>[
        '$userId.jpg',
        '$userId.jpeg',
        '$userId.png',
        '$userId.webp',
      ];

      if (photoUrl != null &&
          photoUrl.isNotEmpty &&
          !photoUrl.startsWith('data:')) {
        try {
          final uri = Uri.parse(photoUrl);
          final pathSegments = uri.pathSegments;
          final avatarsIdx = pathSegments.indexOf('avatars');
          if (avatarsIdx != -1 && avatarsIdx < pathSegments.length - 1) {
            final extractedName =
                pathSegments.sublist(avatarsIdx + 1).join('/');
            if (extractedName.isNotEmpty &&
                !fileNamesToRemove.contains(extractedName)) {
              fileNamesToRemove.add(extractedName);
            }
          }
        } catch (_) {}
      }

      await activeClient.storage.from('avatars').remove(fileNamesToRemove);
    } catch (storageErr) {
      debugPrint(
        '[AuthRepository] Storage avatar delete notice (non-fatal): $storageErr',
      );
    }

    // 2. Clear avatar_url column in profiles table
    try {
      await activeClient.from('profiles').update({
        'avatar_url': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (dbErr) {
      debugPrint('[AuthRepository] Database avatar_url clear error: $dbErr');
      rethrow;
    }
  }

  /// Clears in-memory cache upon user logout
  static void clearCache() {
    // Clears any local auth repository caches
  }

  /// Updates profile details in Supabase and synchronizes metadata.
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
    String? phone,
  }) async {
    final activeClient = client;
    if (activeClient == null || userId.isEmpty) return;

    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (fullName != null) updateData['full_name'] = fullName;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      if (phone != null) updateData['phone'] = phone;

      await activeClient.from('profiles').update(updateData).eq('id', userId);

      // Synchronize into Supabase Auth user metadata ONLY lightweight fields (name and phone)
      final metaUpdates = <String, dynamic>{};
      if (fullName != null) metaUpdates['full_name'] = fullName;
      if (phone != null) metaUpdates['phone'] = phone;
      metaUpdates['avatar_url'] = null; // Guarantee avatar is never in JWT claims

      if (metaUpdates.isNotEmpty) {
        try {
          await activeClient.auth.updateUser(
            supabase.UserAttributes(data: metaUpdates),
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AuthRepository] updateProfile error: $e');
    }
  }

  /// Refetches the latest AppUser from Supabase.
  Future<AppUser?> fetchCurrentUser() async {
    final user = currentUser;
    if (user == null) return null;
    return buildAppUser(user);
  }

  // ── Internal Helpers ────────────────────────────────────────────────────

  /// Creates the user's profile row if it does not exist yet.
  Future<void> _ensureProfile(
    String userId, {
    String? fullName,
    String? role,
  }) async {
    final activeClient = client;
    if (activeClient == null) return;

    try {
      final existing = await activeClient
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      debugPrint(
        '[AuthRepository] ENSURE PROFILE '
        '(user=$userId, existing=${existing != null})',
      );

      if (existing == null) {
        debugPrint(
          '[AuthRepository] INSERTING NEW PROFILE '
          '(user=$userId, role=$role)',
        );
        final insertData = <String, dynamic>{
          'id': userId,
          'role': role ?? 'CUSTOMER',
        };
        if (fullName != null && fullName.isNotEmpty) {
          insertData['full_name'] = fullName;
        }
        await activeClient.from('profiles').insert(insertData);
      }
    } on supabase.PostgrestException catch (e) {
      if (e.code == '431' ||
          e.message.contains('431') ||
          e.details?.toString().contains('431') == true) {
        debugPrint(
          '[AuthRepository] Caught HTTP 431 in _ensureProfile. Sanitizing metadata and retrying...',
        );
        final currentUser = activeClient.auth.currentUser;
        if (currentUser != null) {
          await sanitizeUserMetadataIfNeeded(currentUser);
          try {
            final existing = await activeClient
                .from('profiles')
                .select('id')
                .eq('id', userId)
                .maybeSingle();
            if (existing == null) {
              final insertData = <String, dynamic>{
                'id': userId,
                'role': role ?? 'CUSTOMER',
              };
              if (fullName != null && fullName.isNotEmpty) {
                insertData['full_name'] = fullName;
              }
              await activeClient.from('profiles').insert(insertData);
            }
            return;
          } catch (retryErr) {
            debugPrint(
              '[AuthRepository] Retry after HTTP 431 failed in _ensureProfile: $retryErr',
            );
          }
        }
      }
      debugPrint('[AuthRepository] ENSURE PROFILE ERROR (user=$userId): $e');
    } on Exception catch (e) {
      // Profile creation failure is logged but does not block auth.
      debugPrint('[AuthRepository] ENSURE PROFILE ERROR (user=$userId): $e');
    }
  }

  /// Returns `true` if the error string indicates a genuine network/DNS/socket failure.
  bool _isNetworkError(String lowerCaseMessage) {
    return lowerCaseMessage.contains('socketexception') ||
        lowerCaseMessage.contains('failed host lookup') ||
        lowerCaseMessage.contains('no address associated with hostname') ||
        lowerCaseMessage.contains('handshakeexception') ||
        lowerCaseMessage.contains('connection refused') ||
        lowerCaseMessage.contains('connection closed') ||
        lowerCaseMessage.contains('connection reset') ||
        lowerCaseMessage.contains('network is unreachable') ||
        lowerCaseMessage.contains('broken pipe') ||
        lowerCaseMessage.contains('timed out') ||
        lowerCaseMessage.contains('timeout') ||
        lowerCaseMessage.contains('getaddrinfo') ||
        (lowerCaseMessage.contains('clientexception') &&
            lowerCaseMessage.contains('socket'));
  }

  /// Maps Supabase auth error messages to user-friendly text.
  ///
  /// Never exposes raw exception text, hostnames, URLs, or stack traces.
  String _translateAuthError(String message) {
    final lower = message.toLowerCase();

    // 1. Auth-specific error codes (Checked FIRST so credentials errors are never masked).
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid grant') ||
        lower.contains('invalid email or password')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already exists') ||
        lower.contains('user_already_exists')) {
      return 'An account with this email already exists. Please sign in instead.';
    }
    if (lower.contains('not confirmed') ||
        lower.contains('email not confirmed')) {
      return 'Please check your email to confirm your account before signing in.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('weak password') ||
        lower.contains('password should be at least')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (lower.contains('user not found')) {
      return 'No account found with this email. Please sign up first.';
    }

    // 2. Network / connectivity / DNS errors.
    if (_isNetworkError(lower)) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    // 3. Catch-all for technical leak prevention (never leak URLs, hostnames, or exceptions).
    if (lower.contains('supabase') ||
        lower.contains('exception') ||
        lower.contains('error:') ||
        lower.contains('uri=') ||
        lower.contains('errno') ||
        lower.contains('token') ||
        lower.contains('grant_type') ||
        lower.contains('lookup') ||
        lower.contains('address') ||
        lower.contains('socket') ||
        lower.contains('clientexception') ||
        lower.contains('failed host')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    return message.isEmpty
        ? 'Authentication failed. Please check your credentials and try again.'
        : message;
  }
}