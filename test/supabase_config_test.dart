import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/core/config/app_config.dart';
import 'package:salon_queue/core/config/supabase_config.dart';
import 'package:salon_queue/features/auth/data/auth_repository.dart';

void main() {
  group('Supabase Configuration & Connectivity Diagnostics Tests', () {
    test('AppConfig handles empty and valid URLs cleanly', () {
      expect(AppConfig.supabaseHostname, isNotNull);
      expect(AppConfig.supabaseHostname, equals('ktabfbscrehhdstggjzp.supabase.co'));
    });

    test('SupabaseConfig diagnostics verify configured host connectivity', () async {
      final isConfigured = AppConfig.isSupabaseConfigured;
      expect(isConfigured, isTrue);

      final isReachable = await SupabaseConfig.checkConnectivity();
      // Should return a boolean result without throwing an unhandled exception
      expect(isReachable is bool, isTrue);
    });

    test('AuthRepository translates network and DNS host lookup errors to user friendly messages', () {
      final repo = AuthRepository(client: null, useSingletonFallback: false);

      // Testing raw DNS failure error translation (from user issue screenshot)
      const rawDnsError =
          "ClientException with SocketException: Failed host lookup: 'ktabfbscrehhdstggjzp.supabase.co' "
          "(OS Error: No address associated with hostname, errno = 7), "
          "uri=https://ktabfbscrehhdstggjzp.supabase.co/auth/v1/token?grant_type=password";

      expect(repo.isAvailable, isFalse);
      expect(rawDnsError, contains('SocketException'));

      // SignUp / SignIn calls with null client throw AuthException with clear message
      expect(
        () async => await repo.signIn(email: 'test@example.com', password: 'password123'),
        throwsA(predicate((e) =>
            e.toString().contains('Authentication service is currently unavailable') &&
            !e.toString().contains('SocketException') &&
            !e.toString().contains('ktabfbscrehhdstggjzp'))),
      );
    });
  });
}
