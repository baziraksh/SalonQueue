import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/auth/services/auth_scope.dart';
import '../../features/auth/services/auth_service.dart';
import '../routing/app_router.dart';

/// App Launch & Startup Splash Screen.
/// Displays a full-screen radiant gradient background (orange -> pink -> purple)
/// with a standalone white salon chair that smoothly animates from small to its
/// final centered size, then routes seamlessly to the destination screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.22,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateAuthAndRoute());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _evaluateAuthAndRoute() async {
    if (!mounted || _navigated) return;

    AuthService? auth;
    try {
      auth = AuthScope.of(context, listen: false);
    } on StateError {
      auth = null;
    }

    // Wait for parallel animation and auth initialization to settle naturally
    final authInitFuture = auth != null && !auth.initialized
        ? auth.waitForInitialization(timeout: const Duration(seconds: 4))
        : Future<void>.value();

    final animationFuture = _controller.isCompleted
        ? Future<void>.value()
        : _controller.forward();

    await Future.wait([authInitFuture, animationFuture]);

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
    // Responsive size: ~40% of shorter screen dimension
    final targetSize = (shortestSide * 0.42).clamp(140.0, 260.0);

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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF5E00), // Vibrant Orange / Coral (Top-Left)
                Color(0xFFFF2D55), // Bright Coral-Rose
                Color(0xFFD81B60), // Magenta / Rose Red (Center)
                Color(0xFF8E24AA), // Deep Purple-Magenta
                Color(0xFF4A148C), // Royal Deep Violet (Bottom-Right)
              ],
              stops: [0.0, 0.22, 0.50, 0.78, 1.0],
            ),
          ),
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
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
      ),
    );
  }
}
