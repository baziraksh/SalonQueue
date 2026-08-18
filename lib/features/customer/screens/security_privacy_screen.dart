import 'package:flutter/material.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/color_schemes.dart';
import '../../auth/services/auth_scope.dart';

/// Screen explaining SalonQueue Security, Privacy, and Authentication policies
/// with quick account security actions for the customer.
class SecurityPrivacyScreen extends StatelessWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColorSchemes.ivory,
      appBar: AppBar(
        title: const Text('Security & Privacy'),
        backgroundColor: AppColorSchemes.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Security Trust Shield Card ───────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColorSchemes.navy, AppColorSchemes.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColorSchemes.navy.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColorSchemes.gold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColorSchemes.gold, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColorSchemes.gold,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Privacy is Protected',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'SalonQueue uses encrypted authentication and Row-Level-Security (RLS) to ensure your data stays confidential.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Section 1: Security Pillars ──────────────────────────────
            const Text(
              'Security & Data Protections',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColorSchemes.charcoal,
              ),
            ),
            const SizedBox(height: 12),

            _buildPillarCard(
              icon: Icons.lock_outline_rounded,
              title: 'Encrypted Authentication',
              description:
                  'All logins, password resets, and session tokens are encrypted via Supabase JWT with SSL/TLS transport layer security.',
            ),
            const SizedBox(height: 10),
            _buildPillarCard(
              icon: Icons.visibility_off_outlined,
              title: 'Queue & Contact Privacy',
              description:
                  'Only the salon you join can view your token number and name. Your phone number is never displayed publicly to other clients.',
            ),
            const SizedBox(height: 10),
            _buildPillarCard(
              icon: Icons.storage_rounded,
              title: 'Row Level Security (RLS)',
              description:
                  'Database records are strictly isolated. No customer can access another customer’s private booking history or tickets.',
            ),
            const SizedBox(height: 10),
            _buildPillarCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Cryptographic QR Verification',
              description:
                  'SalonQueue QR codes contain structured verification payloads, rejecting counterfeit or unverified codes.',
            ),

            const SizedBox(height: 24),

            // ── Section 2: Account Security Actions ───────────────────────
            const Text(
              'Account Security Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColorSchemes.charcoal,
              ),
            ),
            const SizedBox(height: 12),

            Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.password_rounded, color: AppColorSchemes.navy),
                    title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Send password reset link to your email'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColorSchemes.gold),
                    onTap: () {
                      final email = user?.email;
                      if (email != null && email.isNotEmpty) {
                        auth.resetPassword(email);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password reset instructions sent to $email'),
                            backgroundColor: AppColorSchemes.navy,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please sign in to change password.')),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined, color: AppColorSchemes.navy),
                    title: const Text('Account Status', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(user != null ? 'Signed in as ${user.email}' : 'Guest mode'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SECURE',
                        style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.redAccent)),
                    subtitle: const Text('End your session on this device'),
                    onTap: () {
                      auth.signOut();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRouter.welcome,
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColorSchemes.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColorSchemes.navy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColorSchemes.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
