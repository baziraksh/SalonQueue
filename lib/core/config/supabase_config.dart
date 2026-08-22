import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;

import 'app_config.dart';

/// Centralized Supabase configuration, initialization, and connection diagnostics.
class SupabaseConfig {
  SupabaseConfig._();

  static bool _isInitialized = false;

  /// Returns true if Supabase client has been successfully initialized.
  static bool get isInitialized => _isInitialized;

  /// Returns the shared SupabaseClient instance, or null if not initialized.
  static supabase_flutter.SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return supabase_flutter.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initializes the single shared Supabase client instance.
  ///
  /// Must be called at application startup before any authentication
  /// screen or feature attempts to use Supabase.
  static Future<bool> initialize() async {
    if (!AppConfig.isSupabaseConfigured) {
      if (kDebugMode || AppConfig.isDebug) {
        debugPrint(
          '[SupabaseConfig] Environment variables SUPABASE_URL or SUPABASE_ANON_KEY '
          'are not configured. Supabase client will not be initialized.',
        );
      }
      _isInitialized = false;
      return false;
    }

    try {
      await supabase_flutter.Supabase.initialize(
        url: AppConfig.supabaseUrl.trim(),
        publishableKey: AppConfig.supabaseAnonKey.trim(),
      );
      _isInitialized = true;

      if (kDebugMode || AppConfig.isDebug) {
        debugPrint(
          '[SupabaseConfig] Supabase client initialized successfully. '
          'Target Host: ${AppConfig.supabaseHostname}',
        );
      }
      return true;
    } catch (e) {
      _isInitialized = false;
      if (kDebugMode || AppConfig.isDebug) {
        debugPrint(
          '[SupabaseConfig] Failed to initialize Supabase for host '
          '${AppConfig.supabaseHostname}: ${e.runtimeType}',
        );
      }
      return false;
    }
  }

  /// Connectivity Diagnostic Pre-Check (Task 11).
  ///
  /// Verifies that the configured Supabase endpoint hostname is reachable via DNS lookup.
  /// Logs diagnostic information (hostname, reachability, error category) without
  /// exposing passwords, tokens, or keys.
  static Future<bool> checkConnectivity() async {
    if (!AppConfig.isSupabaseConfigured) {
      return false;
    }

    final hostname = AppConfig.supabaseHostname;
    try {
      final addresses = await InternetAddress.lookup(
        hostname,
      ).timeout(const Duration(seconds: 4));
      final reachable =
          addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;

      if (kDebugMode || AppConfig.isDebug) {
        debugPrint(
          '[Supabase Diagnostics] Host: $hostname | Reachable: $reachable',
        );
      }
      return reachable;
    } on SocketException {
      if (kDebugMode || AppConfig.isDebug) {
        debugPrint(
          '[Supabase Diagnostics] Host: $hostname | Reachable: false | Category: SocketException/DNS Failed',
        );
      }
      return false;
    } on TimeoutException {
      if (kDebugMode || AppConfig.isDebug) {
        debugPrint(
          '[Supabase Diagnostics] Host: $hostname | Reachable: false | Category: TimeoutException',
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode || AppConfig.isDebug) {
        debugPrint(
          '[Supabase Diagnostics] Host: $hostname | Reachable: false | Category: ${e.runtimeType}',
        );
      }
      return false;
    }
  }
}
