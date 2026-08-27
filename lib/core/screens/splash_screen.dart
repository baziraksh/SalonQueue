import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/auth/models/app_user.dart';
import '../../features/auth/services/auth_scope.dart';
import '../../features/auth/services/auth_service.dart';
import '../routing/app_router.dart';

/// App Launch & Startup Splash Screen.
/// Solid deep magenta/pink background (#C2186A) with centered salon-chair app logo.
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

    _navigated = true;
    if (auth?.recoveryPending ?? false) {
      AppRouter.navigateToResetPassword(context);
    } else if (isAuth && user != null) {
      debugPrint(
        '[SplashScreen] Directing authenticated user: id=${user.id}, role=${user.role}',
      );
      AppRouter.navigateToRoleHome(context, role: user.role);
    } else {
      debugPrint(
        '[SplashScreen] No valid session. Navigating to Welcome screen.',
      );
      AppRouter.navigateToWelcome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const splashColor = Color(0xFFC2186A);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: splashColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: splashColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: splashColor,
        body: Center(
          child: Image.asset(
            'assets/images/app_logo.png',
            width: 140,
            height: 140,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            semanticLabel: 'Salon Queue App Logo',
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF5E00),
                      Color(0xFFD81B60),
                      Color(0xFF8E24AA),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Icon(
                    Icons.chair_alt_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
