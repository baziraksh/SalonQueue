/// Application-wide constants for Salon Queue app
class AppConstants {
  AppConstants._();

  /// App name
  static const String appName = 'Salon Queue';

  /// App tagline / subtitle
  static const String appTagline =
      'Live Crowd & Queue Tracker Across India 🇮🇳';

  /// Short tagline for header
  static const String appTaglineShort = 'Your Time. Your Style.';

  /// App version
  static const String appVersion = '1.0.0';

  /// Splash screen duration in milliseconds
  static const int splashDuration = 2000;

  /// Default animation duration in milliseconds
  static const int defaultAnimationDuration = 300;

  /// Minimum password length
  static const int minPasswordLength = 8;

  /// Maximum name length
  static const int maxNameLength = 50;

  /// Queue position refresh interval in seconds
  static const int queueRefreshInterval = 30;

  /// Estimated wait time per customer in minutes
  static const int waitTimePerCustomer = 15;
}
