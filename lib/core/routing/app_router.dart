import 'package:flutter/material.dart';

import '../../features/auth/models/app_user.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/customer/screens/customer_entry_screen.dart';
import '../../features/salon/screens/salon_entry_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/welcome_screen.dart';

/// Argument payload passed to the sign-in / sign-up routes.
/// Carries which dashboard the user *requested* (a login mode, not a grant).
class AuthFlowArguments {
  final AppRole requestedRole;
  const AuthFlowArguments(this.requestedRole);
}

/// Application router configuration.
///
/// Routes are intentionally coarse. Which screen is shown for a given route
/// is decided at runtime by the widget (e.g., SplashScreen checks auth state).
class AppRouter {
  // Named routes.
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String signIn = '/auth/sign-in';
  static const String signUp = '/auth/sign-up';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String customerEntry = '/customer';
  static const String salonEntry = '/salon';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final rawName = settings.name ?? '';
    final uri = Uri.tryParse(rawName);
    var path = uri?.path ?? rawName;

    // Handle deep links like salonqueue://auth/reset-password or /auth/reset-password?code=...
    if (uri != null && uri.host.isNotEmpty && uri.path.isNotEmpty) {
      path = '/${uri.host}${uri.path}';
    }

    // Strip trailing query parameters or fragment hashes if still present in path
    if (path.contains('?')) {
      path = path.split('?').first;
    }
    if (path.contains('#')) {
      path = path.split('#').first;
    }
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    if (path == resetPassword ||
        path == '/reset-password' ||
        path.endsWith('/reset-password') ||
        rawName.contains('reset-password')) {
      return MaterialPageRoute(
        builder: (_) => const ResetPasswordScreen(),
        settings: settings,
      );
    }

    switch (path) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case welcome:
        return MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
          settings: settings,
        );
      case signIn:
      case '/sign-in':
        return MaterialPageRoute(
          builder: (_) => SignInScreen(
            requestedRole: _readRequestedRole(settings),
          ),
          settings: settings,
        );
      case signUp:
      case '/sign-up':
        return MaterialPageRoute(
          builder: (_) => SignUpScreen(
            requestedRole: _readRequestedRole(settings),
          ),
          settings: settings,
        );
      case forgotPassword:
      case '/forgot-password':
        return MaterialPageRoute(
          builder: (_) => ForgotPasswordScreen(
            requestedRole: _readRequestedRole(settings),
          ),
          settings: settings,
        );
      case customerEntry:
        return MaterialPageRoute(
          builder: (_) => const CustomerEntryScreen(),
          settings: settings,
        );
      case salonEntry:
        return MaterialPageRoute(
          builder: (_) => const SalonEntryScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }

  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    return [
      MaterialPageRoute(
        builder: (_) => const SplashScreen(),
        settings: RouteSettings(name: splash),
      ),
    ];
  }

  // ── Navigation helpers ───────────────────────────────────────────────────

  /// Clears the entire navigation stack and lands on the welcome screen.
  /// Used for unauthenticated landings and after logout.
  static void navigateToWelcome(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      welcome,
      (route) => false,
    );
  }

  /// Navigates to sign-in for the requested login mode.
  static void navigateToSignIn(BuildContext context,
      {AppRole requestedRole = AppRole.customer}) {
    Navigator.of(context).pushNamed(
      signIn,
      arguments: AuthFlowArguments(requestedRole),
    );
  }

  /// Navigates to sign-up for the requested login mode.
  static void navigateToSignUp(BuildContext context,
      {AppRole requestedRole = AppRole.customer}) {
    Navigator.of(context).pushNamed(
      signUp,
      arguments: AuthFlowArguments(requestedRole),
    );
  }

  /// Navigates to the forgot-password screen.
  static void navigateToForgotPassword(BuildContext context,
      {AppRole requestedRole = AppRole.customer}) {
    Navigator.of(context).pushNamed(
      forgotPassword,
      arguments: AuthFlowArguments(requestedRole),
    );
  }

  /// Navigates to the reset-password screen (after a recovery deep link).
  /// Clears the stack so no auth screen sits underneath.
  static void navigateToResetPassword(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      resetPassword,
      (route) => false,
    );
  }

  /// After a successful password update, return to sign-in and clear the
  /// entire recovery stack.
  static void navigateToSignInAfterReset(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      signIn,
      (route) => false,
    );
  }

  /// Routes an authenticated user to their role's home screen.
  static void navigateToRoleHome(BuildContext context, {required AppRole role}) {
    switch (role) {
      case AppRole.salonOwner:
        navigateToSalonEntry(context);
        break;
      case AppRole.customer:
        navigateToCustomerEntry(context);
        break;
    }
  }

  /// Routes to the Customer Dashboard, clearing the entire authentication
  /// flow (splash/welcome/sign-in/sign-up) from the stack so the dashboard
  /// becomes the root route. Back navigation cannot return to auth screens.
  static void navigateToCustomerEntry(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      customerEntry,
      (route) => false,
    );
  }

  /// Routes to the Salon Owner Dashboard, clearing the entire authentication
  /// flow (splash/welcome/sign-in/sign-up) from the stack so the dashboard
  /// becomes the root route. Back navigation cannot return to auth screens.
  static void navigateToSalonEntry(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      salonEntry,
      (route) => false,
    );
  }

  /// Routes to the welcome screen after an explicit logout, clearing the
  /// entire authenticated stack (dashboard etc.).
  static void navigateToWelcomeAfterLogout(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      welcome,
      (route) => false,
    );
  }

  static AppRole _readRequestedRole(RouteSettings settings) {
    if (settings.arguments is AuthFlowArguments) {
      return (settings.arguments as AuthFlowArguments).requestedRole;
    }
    return AppRole.customer;
  }
}
