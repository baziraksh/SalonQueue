import 'dart:async';
import 'package:flutter/material.dart';
import 'package:salon_queue/core/routing/app_router.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';

/// Premium Modern Opening & Splash Animation for Salon Queue
///
/// Visual Order (9-Step Animation):
/// 1. Off-white clean background with subtle pastel gradient glows
/// 2. Animated gradient rounded-rectangle outline draws in
/// 3. Vibrant orange → pink → purple gradient fills the app icon
/// 4. White salon chair logo pops & reveals with smooth cubic easing
/// 5. "Salon Queue" brand title fades and slides up
/// 6. "Skip the wait, book your great." tagline reveals
/// 7. Subtle floating & breathing glow halo
/// 8. Sleek gradient progress bar animates from 0% → 100%
/// 9. Seamless smooth cross-fade transition to the next screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Step 1: Background & Glows
  late Animation<double> _bgFadeAnim;

  // Step 2: Outline Draw Progress
  late Animation<double> _outlineProgressAnim;
  late Animation<double> _outlineFadeAnim;

  // Step 3: Gradient Fill & Icon Scale
  late Animation<double> _iconFillFadeAnim;
  late Animation<double> _iconScaleAnim;
  late Animation<double> _iconGlowAnim;

  // Step 4: Chair Pop & Reveal
  late Animation<double> _chairFadeAnim;
  late Animation<double> _chairScaleAnim;

  // Step 5: Brand Title Text
  late Animation<double> _titleFadeAnim;
  late Animation<Offset> _titleSlideAnim;

  // Step 6: Subtle Breathing Pulse
  late Animation<double> _pulseScaleAnim;

  // Step 7: Progress Bar (0.0 -> 1.0)
  late Animation<double> _progressAnim;

  // Step 8: Final Fade Out Transition
  late Animation<double> _exitFadeAnim;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // ── Animation Curve Intervals ───────────────────────────────────────────

    // Step 1: Background fade in (0.0 -> 0.20)
    _bgFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
    );

    // Step 2: Outline appears and draws (0.08 -> 0.35)
    _outlineFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.20, curve: Curves.easeIn),
    );
    _outlineProgressAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.35, curve: Curves.easeInOutCubic),
    );

    // Step 3: Gradient fills the icon & scale expands (0.30 -> 0.52)
    _iconFillFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.48, curve: Curves.easeOut),
    );
    _iconScaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.52, curve: Curves.easeOutBack),
      ),
    );
    _iconGlowAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.38, 0.55, curve: Curves.easeOut),
    );

    // Step 4: Chair logo pops up (0.45 -> 0.65)
    _chairFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.55, curve: Curves.easeIn),
    );
    _chairScaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 0.90,
              end: 1.04,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 60,
          ),
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 1.04,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 40,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.45, 0.65),
          ),
        );

    // Step 5: Brand text "Salon Queue" (0.55 -> 0.75)
    _titleFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.72, curve: Curves.easeOut),
    );
    _titleSlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.55, 0.75, curve: Curves.easeOutCubic),
          ),
        );

    // Step 6: Subtle Breathing Pulse (0.70 -> 1.0)
    _pulseScaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 1.0,
              end: 1.016,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 1.016,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.70, 0.95),
          ),
        );

    // Step 7: Progress Indicator (0.60 -> 0.96)
    _progressAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 0.96, curve: Curves.easeInOutCubic),
    );

    // Step 8: Smooth exit fade (0.95 -> 1.0)
    _exitFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.95, 1.0, curve: Curves.easeIn),
      ),
    );

    // Start animation immediately
    _controller.forward();
    _startBackgroundAuthAndNavigation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Concurrently validates auth/session in the background without blocking the UI
  Future<void> _startBackgroundAuthAndNavigation() async {
    final startTime = DateTime.now();

    AuthService? auth;
    try {
      auth = AuthScope.of(context, listen: false);
    } on StateError {
      auth = null;
    }

    // Await auth initialization & session restore in parallel
    if (auth != null) {
      await auth.waitForInitialization(timeout: const Duration(seconds: 4));
    }

    // Ensure minimum smooth splash animation time has elapsed
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    const minSplashDuration = 800;
    if (elapsed < minSplashDuration) {
      await Future.delayed(Duration(milliseconds: minSplashDuration - elapsed));
    }

    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    final user = auth?.currentUser;
    final isAuth = auth?.isAuthenticated ?? false;

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
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8FA), // Clean off-white
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return FadeTransition(
              opacity: _exitFadeAnim,
              child: Stack(
                children: [
                  // ── 1. Subtle Pastel Glow Blobs ────────────────────────────
                  FadeTransition(
                    opacity: _bgFadeAnim,
                    child: _buildPastelGlowBackground(size),
                  ),

                  // ── 2. Center Content: Logo + Brand + Tagline ───────────────
                  SafeArea(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 3),

                          // ── Logo Icon Container (Outline + Gradient Fill + Chair Pop) ──
                          _buildAnimatedLogo(),

                          const SizedBox(height: 24),

                          // ── Step 5: Brand Title "Salon Queue" ───────────────
                          FadeTransition(
                            opacity: _titleFadeAnim,
                            child: SlideTransition(
                              position: _titleSlideAnim,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          colors: [
                                            Color(0xFFFF4500),
                                            Color(0xFFE91E63),
                                            Color(0xFF8B2FC9),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ).createShader(bounds),
                                    child: const Text(
                                      'Salon Queue',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(flex: 4),

                          // ── Step 8: Bottom Progress Indicator ──────────────
                          FadeTransition(
                            opacity: _titleFadeAnim,
                            child: _buildProgressBar(),
                          ),

                          const SizedBox(height: 38),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// ── Background Glow Blobs ──────────────────────────────────────────────────
  Widget _buildPastelGlowBackground(Size size) {
    return Stack(
      children: [
        // Bottom-left soft pink / peach glow
        Positioned(
          left: -size.width * 0.35,
          bottom: -size.height * 0.15,
          width: size.width * 0.9,
          height: size.width * 0.9,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFB3C6).withValues(alpha: 0.40),
                  const Color(0xFFFFC6D9).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Upper-right soft lavender/purple glow
        Positioned(
          right: -size.width * 0.30,
          top: -size.height * 0.10,
          width: size.width * 0.85,
          height: size.width * 0.85,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE2D1F9).withValues(alpha: 0.40),
                  const Color(0xFFEDE0FD).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.60, 1.0],
              ),
            ),
          ),
        ),

        // Center subtle warm peach glow
        Positioned(
          left: size.width * 0.20,
          top: size.height * 0.35,
          width: size.width * 0.60,
          height: size.width * 0.60,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFDDE4).withValues(alpha: 0.25),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ── Logo Icon Container with Outline & Fill Animations ────────────────────
  Widget _buildAnimatedLogo() {
    const double iconSize = 100.0;
    const double cornerRadius = 22.0;

    return Transform.scale(
      scale: _pulseScaleAnim.value,
      child: SizedBox(
        width: iconSize,
        height: iconSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft glowing shadow behind icon
            if (_iconGlowAnim.value > 0)
              Container(
                width: iconSize * 0.85,
                height: iconSize * 0.85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cornerRadius),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFE91E63,
                      ).withValues(alpha: 0.38 * _iconGlowAnim.value),
                      blurRadius: 32,
                      spreadRadius: 2,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: const Color(
                        0xFFFF5722,
                      ).withValues(alpha: 0.20 * _iconGlowAnim.value),
                      blurRadius: 20,
                      offset: const Offset(-4, 6),
                    ),
                  ],
                ),
              ),

            // Step 2: Gradient Outline being drawn
            if (_outlineFadeAnim.value > 0 && _iconFillFadeAnim.value < 1.0)
              Opacity(
                opacity:
                    _outlineFadeAnim.value * (1.0 - _iconFillFadeAnim.value),
                child: CustomPaint(
                  size: const Size(iconSize, iconSize),
                  painter: _GradientRoundedRectBorderPainter(
                    progress: _outlineProgressAnim.value,
                    radius: cornerRadius,
                    strokeWidth: 2.2,
                  ),
                ),
              ),

            // Step 2b: Faint Chair Preview inside outline before full fill
            if (_outlineFadeAnim.value > 0 && _iconFillFadeAnim.value < 0.6)
              Opacity(
                opacity:
                    (0.28 * _outlineFadeAnim.value) *
                    (1.0 - _iconFillFadeAnim.value),
                child: const CustomPaint(
                  size: Size(50, 50),
                  painter: _SalonChairVectorPainter(color: Color(0xFFE91E63)),
                ),
              ),

            // Step 3: Filled Gradient Rounded Square
            if (_iconFillFadeAnim.value > 0)
              Opacity(
                opacity: _iconFillFadeAnim.value,
                child: Transform.scale(
                  scale: _iconScaleAnim.value,
                  child: Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF5E36), // Vibrant Orange/Red
                          Color(0xFFE91E63), // Rich Magenta/Pink
                          Color(0xFF8B2FC9), // Royal Purple
                        ],
                      ),
                      borderRadius: BorderRadius.circular(cornerRadius),
                    ),
                    child: Center(
                      // Step 4: White Salon Chair Logo Pop
                      child: Opacity(
                        opacity: _chairFadeAnim.value,
                        child: Transform.scale(
                          scale: _chairScaleAnim.value,
                          child: const CustomPaint(
                            size: Size(52, 52),
                            painter: _SalonChairVectorPainter(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ── Step 8: Bottom Progress Bar ───────────────────────────────────────────
  Widget _buildProgressBar() {
    const double trackWidth = 140.0;
    const double trackHeight = 3.8;

    return SizedBox(
      width: trackWidth,
      height: trackHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(trackHeight),
        child: Stack(
          children: [
            Container(color: const Color(0xFFE5E7EB)),
            FractionallySizedBox(
              widthFactor: _progressAnim.value.clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF5722),
                      Color(0xFFE91E63),
                      Color(0xFF8B2FC9),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── CUSTOM PAINTERS ──────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

/// Custom painter to draw the animated gradient rounded rectangle outline
class _GradientRoundedRectBorderPainter extends CustomPainter {
  final double progress;
  final double radius;
  final double strokeWidth;

  const _GradientRoundedRectBorderPainter({
    required this.progress,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final extractLength = metric.length * progress.clamp(0.0, 1.0);
    final extractedPath = metric.extractPath(0.0, extractLength);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF5E36), Color(0xFFE91E63), Color(0xFF8B2FC9)],
      ).createShader(rect);

    canvas.drawPath(extractedPath, paint);
  }

  @override
  bool shouldRepaint(_GradientRoundedRectBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Razor-sharp vector painter for the official Salon Queue modern chair logo
class _SalonChairVectorPainter extends CustomPainter {
  final Color color;

  const _SalonChairVectorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // 1. Slanted Backrest & Seat Cushion Profile
    final chairBodyPath = Path();

    // Backrest Top-Left Corner
    chairBodyPath.moveTo(w * 0.24, h * 0.24);
    // Top edge
    chairBodyPath.lineTo(w * 0.36, h * 0.24);
    // Slanted backrest right line
    chairBodyPath.lineTo(w * 0.45, h * 0.47);
    // Extend into horizontal seat cushion top edge
    chairBodyPath.lineTo(w * 0.78, h * 0.47);
    // Seat front rounded edge
    chairBodyPath.arcToPoint(
      Offset(w * 0.82, h * 0.54),
      radius: Radius.circular(w * 0.05),
    );
    chairBodyPath.arcToPoint(
      Offset(w * 0.77, h * 0.60),
      radius: Radius.circular(w * 0.05),
    );
    // Seat cushion bottom edge
    chairBodyPath.lineTo(w * 0.38, h * 0.60);
    // Backrest inner crook curve
    chairBodyPath.arcToPoint(
      Offset(w * 0.30, h * 0.53),
      radius: Radius.circular(w * 0.06),
    );
    // Backrest left exterior slant
    chairBodyPath.lineTo(w * 0.20, h * 0.29);
    chairBodyPath.arcToPoint(
      Offset(w * 0.24, h * 0.24),
      radius: Radius.circular(w * 0.04),
    );
    chairBodyPath.close();

    canvas.drawPath(chairBodyPath, paint);

    // 2. Modern Accent Armrest / Side Bar
    final armrestPath = Path();
    armrestPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.48, h * 0.37, w * 0.28, h * 0.065),
        Radius.circular(w * 0.03),
      ),
    );
    canvas.drawPath(armrestPath, paint);

    // 3. Hydraulic Center Pedestal Column / Stem
    final stemRect = Rect.fromLTWH(w * 0.48, h * 0.60, w * 0.075, h * 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(stemRect, Radius.circular(w * 0.015)),
      paint,
    );

    // 4. Solid Round Base Pedestal Plate
    final baseRect = Rect.fromLTWH(w * 0.34, h * 0.75, w * 0.36, h * 0.065);
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, Radius.circular(w * 0.032)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SalonChairVectorPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
