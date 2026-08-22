/// Centralized App and Supabase Configuration.
///
/// Values are embedded at compile time via `--dart-define` or `.env`:
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co
///   --dart-define=SUPABASE_ANON_KEY=your-anon-key
class AppConfig {
  AppConfig._();

  /// Supabase project URL (reads SUPABASE_URL or defaults to configured project).
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: String.fromEnvironment(
      'SUPABASE_PROJECT_URL',
      defaultValue: 'https://ktabfbscrehhdstggjzp.supabase.co',
    ),
  );

  /// Supabase client-side anon / publishable key.
  /// Safe for Flutter clients; never use the service-role key.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_zuDZEttzZFFt5JIZsoz2gA_z3l7ndFX',
    ),
  );

  /// Alias for backward compatibility.
  static String get supabasePublishableKey => supabaseAnonKey;

  /// Whether to enable debug logging.
  static const bool isDebug = String.fromEnvironment('APP_DEBUG') == 'true';

  /// Android deep link used as the password-reset redirect.
  static const String resetPasswordRedirectUrl =
      'salonqueue://auth/reset-password';

  /// Returns true if Supabase configuration environment variables are present
  /// and validly formatted.
  static bool get isSupabaseConfigured {
    if (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty) {
      return false;
    }
    final url = supabaseUrl.trim().toLowerCase();
    return url.startsWith('https://') || url.startsWith('http://');
  }

  /// Returns only the hostname part of the configured Supabase URL for safe debug logging.
  static String get supabaseHostname {
    final trimmed = supabaseUrl.trim();
    if (trimmed.isEmpty) return 'not-configured';
    try {
      final uri = Uri.parse(trimmed);
      return uri.host.isNotEmpty ? uri.host : 'invalid-host';
    } catch (_) {
      return 'invalid-url';
    }
  }

  /// Validates that required config is present.
  static void validate() {
    if (supabaseUrl.trim().isEmpty) {
      throw StateError(
        'SUPABASE_URL not set. Pass --dart-define=SUPABASE_URL=...',
      );
    }
    if (supabaseAnonKey.trim().isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY not set. '
        'Pass --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    if (!supabaseUrl.trim().startsWith('https://')) {
      throw StateError('SUPABASE_URL must start with https://');
    }
  }
}
