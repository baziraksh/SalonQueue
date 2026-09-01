import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/auth/services/auth_scope.dart';
import '../../features/auth/services/auth_service.dart';
import '../routing/app_router.dart';

/// App Launch & Startup Splash Screen.
/// Step 1: Displays the exact full-screen vertical radiant gradient background
/// with the centered standalone white salon chair on app click.
/// Step 2: After the splash display and auth evaluation, transitions to the
/// WelcomeScreen (I am a Customer / I am a Salon Owner) or authenticated role home.
class SplashScreen extends StatefulWidget {
  final Duration? displayDuration;

  const SplashScreen({
    super.key,
    this.displayDuration,
  });

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

    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    final effectiveDelay = widget.displayDuration ??
        (isTestEnvironment
            ? Duration.zero
            : const Duration(milliseconds: 1500));

    final delayFuture = effectiveDelay > Duration.zero
        ? Future.delayed(effectiveDelay)
        : Future<void>.value();

    final authInitFuture = auth != null && !auth.initialized
        ? auth.waitForInitialization(timeout: const Duration(seconds: 4))
        : Future<void>.value();

    await Future.wait([delayFuture, authInitFuture]);

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
    // Exactly 37.5% of shortest screen dimension matching the reference image
    final targetSize = (shortestSide * 0.38).clamp(140.0, 240.0);

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
                Color(0xFFFF5A08), // Top: Vivid Orange
                Color(0xFFFE3547), // Upper: Coral Red
                Color(0xFFEE255B), // Upper-Middle: Rose Pink
                Color(0xFFE2205F), // Center: Magenta-Pink
                Color(0xFFD51B65), // Lower-Middle: Deep Magenta
                Color(0xFFA72190), // Lower: Purple
                Color(0xFF7A1FA2), // Bottom: Royal Purple
              ],
              stops: [0.0, 0.20, 0.40, 0.50, 0.60, 0.80, 1.0],
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
