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
import 'salon_location_screen.dart';
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
        title: 'Salon Profile',
        subtitle: 'Cover photo, gallery & owner info',
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
        title: 'Business Information',
        subtitle: 'Salon name, contact & description',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StoreInfoScreen(salon: salon),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.location_on_outlined,
        title: 'Salon Location',
        subtitle: 'State, City, District & Pincode',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SalonLocationScreen(salon: salon),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.access_time_rounded,
        title: 'Working Hours',
        subtitle: 'Operating hours & active chairs capacity',
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
        title: 'Services & Pricing',
        subtitle: 'Menu items, prices & durations',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ManageServicesScreen(salon: salon),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.credit_card_outlined,
        title: 'Payment Methods',
        subtitle: 'Wallet, bank account & payouts',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OwnerWalletScreen(salon: salon),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        subtitle: 'Queue alerts & system updates',
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
        title: 'Privacy Policy',
        subtitle: 'Data security and terms of service',
        onTap: () => _showPrivacyPolicy(context),
      ),
      _SettingsItem(
        icon: Icons.help_outline_rounded,
        title: 'Help & Support',
        subtitle: 'Owner FAQs & support tickets',
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
        title: 'Logout',
        subtitle: 'Sign out from owner dashboard',
        isDestructive: true,
        onTap: () => _showLogoutDialog(context),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 18),
          onPressed: () => Navigator.of(context).pop(),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: settingsItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = settingsItems[index];
          final isDestructive = item.isDestructive;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDestructive ? const Color(0xFFFEE2E2) : const Color(0xFFF1F3F5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: item.onTap,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDestructive ? const Color(0xFFFEE2E2) : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF6D28D9),
                  size: 22,
                ),
              ),
              title: Text(
                item.title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF111827),
                  letterSpacing: -0.2,
                ),
              ),
              subtitle: Text(
                item.subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade500,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDestructive ? const Color(0xFFEF4444) : Colors.grey.shade400,
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
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });
}
