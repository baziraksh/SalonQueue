import 'package:flutter/material.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/models/salon.dart';
import '../../auth/services/auth_scope.dart';
import '../../notifications/screens/owner_notifications_screen.dart';
import '../../support/screens/support_center_screen.dart';
import 'chairs_timings_screen.dart';
import 'manage_services_screen.dart';
import 'owner_profile_screen.dart';
import 'owner_wallet_screen.dart';
import 'store_info_screen.dart';

/// Screen displaying the Salon Owner settings menu matching the reference design system.
class SalonSettingsScreen extends StatelessWidget {
  const SalonSettingsScreen({super.key, required this.salon, this.onUpdated});

  final Salon salon;
  final VoidCallback? onUpdated;

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827)),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out from your salon owner account?',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF4B5563), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final auth = AuthScope.of(context, listen: false);
              await auth.signOut();
              if (!context.mounted) return;
              AppRouter.navigateToWelcomeAfterLogout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy & Data Policy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 12),
            Text(
              'SalonQueue is committed to protecting your salon business data. All digital queue tokens, customer telephone numbers, and financial transactions are encrypted with Supabase row-level security (RLS).',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context, listen: false);
    final ownerId = auth.currentUser?.id ?? salon.ownerId ?? '';

    final settingsItems = [
      _SettingsItem(
        icon: Icons.person_outline_rounded,
        iconColor: const Color(0xFF6D28D9),
        bgColor: const Color(0xFFF3E8FF),
        title: 'Salon Profile',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OwnerProfileScreen(salon: salon, onUpdated: onUpdated),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.storefront_outlined,
        iconColor: const Color(0xFFE11D48),
        bgColor: const Color(0xFFFDF2F8),
        title: 'Business Information',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StoreInfoScreen(salon: salon),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.access_time_rounded,
        iconColor: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFF7ED),
        title: 'Working Hours',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChairsTimingsScreen(salon: salon),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.content_cut_rounded,
        iconColor: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
        title: 'Services & Pricing',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ManageServicesScreen(salon: salon),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: const Color(0xFF0284C7),
        bgColor: const Color(0xFFE0F2FE),
        title: 'Payment Methods',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OwnerWalletScreen(salon: salon),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.notifications_none_rounded,
        iconColor: const Color(0xFF6D28D9),
        bgColor: const Color(0xFFF3E8FF),
        title: 'Notifications',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OwnerNotificationsScreen(ownerId: ownerId),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.shield_outlined,
        iconColor: const Color(0xFF3B82F6),
        bgColor: const Color(0xFFEFF6FF),
        title: 'Privacy Policy',
        onTap: () => _showPrivacyPolicy(context),
      ),
      _SettingsItem(
        icon: Icons.help_outline_rounded,
        iconColor: const Color(0xFF6D28D9),
        bgColor: const Color(0xFFF3E8FF),
        title: 'Help & Support',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SupportCenterScreen(isOwner: true),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.logout_rounded,
        iconColor: const Color(0xFFEF4444),
        bgColor: const Color(0xFFFEE2E2),
        title: 'Logout',
        isDestructive: true,
        onTap: () => _showLogoutDialog(context),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827), size: 24),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 30),
        itemCount: settingsItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = settingsItems[index];
          final isDestructive = item.isDestructive;

          return GestureDetector(
            onTap: item.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDestructive ? const Color(0xFFFEE2E2) : const Color(0xFFF1F3F5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.bgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.iconColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (!isDestructive)
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });
}
