import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/auth/services/auth_scope.dart';
import '../../features/auth/services/auth_service.dart';
import '../routing/app_router.dart';

/// App Launch & Startup Splash Screen.
/// Displays a full-screen vertical radiant gradient background
/// (top: orange -> upper: pink -> middle: magenta -> lower: purple -> bottom: deep violet)
/// with a standalone white salon chair centered on the screen,
/// then routes seamlessly to the destination screen.
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
    final mediaQuery = MediaQuery.of(context);
    final shortestSide = mediaQuery.size.shortestSide;
    // Responsive size matching the reference design: ~44% of shorter screen dimension
    final targetSize = (shortestSide * 0.44).clamp(160.0, 260.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFF5E00), // Vibrant Orange / Coral (Top)
                Color(0xFFFF2D55), // Bright Coral-Rose
                Color(0xFFD81B60), // Magenta / Rose Red (Center)
                Color(0xFF8E24AA), // Deep Purple-Magenta
                Color(0xFF4A148C), // Royal Deep Violet (Bottom)
              ],
              stops: [0.0, 0.22, 0.50, 0.78, 1.0],
            ),
          ),
          child: Center(
            child: SizedBox(
              width: targetSize,
              height: targetSize,
              child: Image.asset(
                'assets/images/splash_chair_white.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                semanticLabel: 'Salon Queue Splash Chair',
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.chair_alt_rounded,
                    size: targetSize * 0.75,
                    color: Colors.white,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
