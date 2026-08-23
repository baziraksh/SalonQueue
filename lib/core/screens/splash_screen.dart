import 'dart:async';
import 'package:flutter/material.dart';
import '../../features/auth/models/app_user.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/services/auth_scope.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/customer/screens/customer_entry_screen.dart';
import '../../features/salon/screens/salon_entry_screen.dart';
import '../routing/app_router.dart';
import 'welcome_screen.dart';

/// Instant Startup & Authentication Router for Salon Queue.
///
/// Immediately determines authentication state on frame 1 without any splash/flash
/// animation, gradient delay, or artificial timer:
/// - Authenticated Customer -> Opens Customer Home directly
/// - Authenticated Salon Owner -> Opens Owner Dashboard directly
/// - Password Recovery -> Opens Reset Password directly
/// - Unauthenticated -> Opens Welcome / Login directly
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateAuthAndRoute());
  }

  Future<void> _evaluateAuthAndRoute() async {
    if (!mounted || _navigated) return;

    AuthService? auth;
    try {
      auth = AuthScope.of(context, listen: false);
    } on StateError {
      auth = null;
    }

    if (auth != null && !auth.initialized) {
      await auth.waitForInitialization(timeout: const Duration(seconds: 4));
    }

    if (!mounted || _navigated) return;

    final user = auth?.currentUser;
    final isAuth = auth?.isAuthenticated ?? false;

    if (auth?.recoveryPending ?? false) {
      _navigated = true;
      AppRouter.navigateToResetPassword(context);
    } else if (isAuth && user != null) {
      _navigated = true;
      debugPrint(
        '[SplashScreen] Directing authenticated user: id=${user.id}, role=${user.role}',
      );
      AppRouter.navigateToRoleHome(context, role: user.role);
    } else {
      _navigated = true;
      debugPrint(
        '[SplashScreen] No valid session. Navigating to Welcome screen.',
      );
      AppRouter.navigateToWelcome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    AuthService? auth;
    try {
      auth = AuthScope.of(context, listen: true);
    } on StateError {
      auth = null;
    }

    // Direct synchronous frame-1 rendering for instant startup without flash
    if (auth != null) {
      if (auth.recoveryPending) {
        return const ResetPasswordScreen();
      }
      if (auth.isAuthenticated && auth.currentUser != null) {
        if (auth.currentUser!.role == AppRole.salonOwner) {
          return const SalonEntryScreen();
        } else {
          return const CustomerEntryScreen();
        }
      }
      if (auth.initialized) {
        return const WelcomeScreen();
      }
    }

    return const Scaffold(
      backgroundColor: Color(0xFFFAF9F6),
      body: SizedBox.shrink(),
    );
  }
}
