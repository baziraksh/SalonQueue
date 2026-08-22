import 'package:flutter/material.dart';
import 'package:salon_queue/core/routing/app_router.dart';
import 'package:salon_queue/core/theme/color_schemes.dart';
import 'package:salon_queue/features/auth/models/app_user.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';

/// Clean, minimal, luxury Welcome / Role Selection screen.
/// Both Customer and Salon Owner cards feature the consistent deep navy border.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _enterAs(BuildContext context, AppRole role) {
    final auth = AuthScope.of(context, listen: false);
    auth.clearError();
    final user = auth.currentUser;

    if (user != null && user.isAuthenticated) {
      if (role == user.role) {
        AppRouter.navigateToRoleHome(context, role: user.role);
      } else {
        // Mismatched role: Do NOT grant access. Route to proper sign-in flow.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.role.isCustomer
                  ? 'You are signed in as a Customer. Please sign in with a Salon Owner account.'
                  : 'You are signed in as a Salon Owner. Please sign in with a Customer account.',
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        AppRouter.navigateToSignIn(context, requestedRole: role);
      }
    } else {
      AppRouter.navigateToSignIn(context, requestedRole: role);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: Stack(
        children: [
          // Subtle champagne wave background
          Positioned.fill(
            child: CustomPaint(painter: _BackgroundWavePainter()),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Salon Queue Branding
                  const Text(
                    'Salon Queue',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColorSchemes.navy,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle with Indian Flag
                  const Text(
                    'Find Salons & Skip The Line 🇮🇳',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                      letterSpacing: 0.1,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 3),

                  // Role Selection Header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose how you want to continue',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Customer Role Card (with clean navy border)
                  _buildRoleCard(
                    context,
                    title: 'I am a Customer',
                    icon: Icons.person_outline_rounded,
                    onTap: () => _enterAs(context, AppRole.customer),
                  ),

                  const SizedBox(height: 16),

                  // Salon Owner Role Card (with matching clean navy border)
                  _buildRoleCard(
                    context,
                    title: 'I am a Salon Owner',
                    icon: Icons.storefront_outlined,
                    onTap: () => _enterAs(context, AppRole.salonOwner),
                  ),

                  const Spacer(flex: 2),

                  // Footer Note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: AppColorSchemes.gold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Fast, Secure & Verified Live Queues',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColorSchemes.navy, width: 1.8),
            boxShadow: [
              BoxShadow(
                color: AppColorSchemes.navy.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Role Icon Box
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColorSchemes.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppColorSchemes.gold),
              ),
              const SizedBox(width: 16),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColorSchemes.navy,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Arrow Icon
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColorSchemes.navy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColorSchemes.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle champagne wave background painter for a luxury, minimal feel.
class _BackgroundWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2D9C8).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.15);
    path1.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.08,
      size.width,
      size.height * 0.22,
    );
    canvas.drawPath(path1, paint);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.82);
    path2.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.92,
      size.width,
      size.height * 0.78,
    );
    canvas.drawPath(path2, paint);

    // Decorative soft champagne circle
    final circlePaint = Paint()
      ..color = const Color(0xFFEFE8D8).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.18),
      36,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.75),
      24,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
