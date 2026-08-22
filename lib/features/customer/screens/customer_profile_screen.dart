import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/routing/app_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/services/auth_scope.dart';
import '../../notifications/screens/customer_notifications_screen.dart';
import '../../support/screens/support_center_screen.dart';
import 'customer_history_screen.dart';
import 'security_privacy_screen.dart';

/// Customer Profile Screen
/// Redesigned to EXACTLY match the target reference screenshot with vibrant gradient header,
/// rounded customer avatar, pencil edit button, and clean white menu list.
class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final AuthRepository _authRepo = AuthRepository();
  bool _isUploadingPhoto = false;

  Future<void> _handleEditProfile() async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: Color(0xFF6D28D9)),
            SizedBox(width: 8),
            Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF111827))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6D28D9)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF6D28D9)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D28D9),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final newName = nameCtrl.text.trim();
      final newPhone = phoneCtrl.text.trim();
      if (newName.isNotEmpty) {
        await auth.updateProfile(fullName: newName, phone: newPhone);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Color(0xFF6D28D9),
            ),
          );
        }
      }
    }
  }

  Future<void> _handlePickProfilePhoto() async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF6D28D9)),
                title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF6D28D9)),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  onTap: () async {
                    Navigator.of(ctx).pop(null);
                    await _authRepo.deleteProfileImage(userId: user.id, photoUrl: user.avatarUrl);
                    await auth.updateProfile(avatarUrl: '');
                    auth.updateCurrentUserAvatar(null);
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 800, maxHeight: 800);
      if (picked != null) {
        setState(() => _isUploadingPhoto = true);
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last;
        final publicUrl = await _authRepo.uploadProfileImage(
          userId: user.id,
          imageBytes: bytes,
          fileExt: ext,
        );
        await auth.updateProfile(avatarUrl: publicUrl);
        auth.updateCurrentUserAvatar(publicUrl);
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully!'),
              backgroundColor: Color(0xFF6D28D9),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update photo: $e')),
        );
      }
    }
  }

  Widget _buildAvatarWidget(String? avatar) {
    if (avatar == null || avatar.trim().isEmpty) {
      return Container(
        color: const Color(0xFFF3E8FF),
        child: const Center(
          child: Icon(Icons.person, size: 44, color: Color(0xFF6D28D9)),
        ),
      );
    }
    final trimmed = avatar.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        key: ValueKey(trimmed),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF3E8FF),
          child: const Center(
            child: Icon(Icons.person, size: 44, color: Color(0xFF6D28D9)),
          ),
        ),
      );
    } else if (trimmed.startsWith('data:image')) {
      try {
        final base64Str = trimmed.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, key: ValueKey(trimmed.hashCode), fit: BoxFit.cover);
      } catch (_) {
        return Container(
          color: const Color(0xFFF3E8FF),
          child: const Center(
            child: Icon(Icons.person, size: 44, color: Color(0xFF6D28D9)),
          ),
        );
      }
    } else {
      final file = File(trimmed);
      if (file.existsSync()) {
        return Image.file(file, key: ValueKey(trimmed), fit: BoxFit.cover);
      }
      return Container(
        color: const Color(0xFFF3E8FF),
        child: const Center(
          child: Icon(Icons.person, size: 44, color: Color(0xFF6D28D9)),
        ),
      );
    }
  }

  void _handleOpenWallet() {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Salon Wallet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6D28D9), Color(0xFF8B2FC9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  SizedBox(height: 6),
                  Text('₹250.00', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text('✨ 150 Queue Loyalty Coins', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
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
                child: const Text('Add Money / Redeem', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleOpenReviews() {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Salon Reviews',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Feedback Matters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF111827))),
                        SizedBox(height: 2),
                        Text('Rate your salon visits to help others find the best grooming spots.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
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
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final auth = AuthScope.of(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await auth.signOut();
      if (!mounted) return;
      AppRouter.navigateToWelcomeAfterLogout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.currentUser;

    final name = user?.fullName?.isNotEmpty == true ? user!.fullName! : 'Valued Customer';
    final phone = user?.phone?.isNotEmpty == true
        ? user!.phone!
        : (user?.email?.isNotEmpty == true ? user!.email! : '+91 98765 43210');
    final avatar = user?.avatarUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF6D28D9), // Matches gradient bottom edge
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── 1. TOP PROFILE HEADER (Gradient with avatar, name, phone & pencil edit button) ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF5A1F), // Vibrant Orange
                    Color(0xFFE91E63), // Hot Pink
                    Color(0xFF6D28D9), // Deep Purple
                  ],
                  stops: [0.0, 0.45, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular Avatar with white circular frame
                  GestureDetector(
                    onTap: _handlePickProfilePhoto,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _isUploadingPhoto
                            ? Container(
                                color: Colors.white.withValues(alpha: 0.2),
                                child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                              )
                            : _buildAvatarWidget(avatar),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Customer Name & Phone Number
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Edit / Pencil Button on Right (Matching Reference Screenshot)
                  GestureDetector(
                    onTap: _handleEditProfile,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.mode_edit_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. WHITE MENU LIST (Matching Reference Screenshot EXACTLY) ───
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // 1. My Bookings
                  _buildMenuItem(
                    icon: Icons.calendar_today_outlined,
                    title: 'My Bookings',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CustomerHistoryScreen()),
                      );
                    },
                  ),
                  _buildDivider(),

                  // 2. My Profile
                  _buildMenuItem(
                    icon: Icons.person_outline_rounded,
                    title: 'My Profile',
                    onTap: _handleEditProfile,
                  ),
                  _buildDivider(),

                  // 3. My Wallet
                  _buildMenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'My Wallet',
                    onTap: _handleOpenWallet,
                  ),
                  _buildDivider(),

                  // 4. My Reviews
                  _buildMenuItem(
                    icon: Icons.star_outline_rounded,
                    title: 'My Reviews',
                    onTap: _handleOpenReviews,
                  ),
                  _buildDivider(),

                  // 5. Notifications
                  _buildMenuItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CustomerNotificationsScreen()),
                      );
                    },
                  ),
                  _buildDivider(),

                  // 6. Help & Support
                  _buildMenuItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SupportCenterScreen(isOwner: false),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),

                  // 7. Settings
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SecurityPrivacyScreen()),
                      );
                    },
                  ),
                  _buildDivider(),

                  // 8. Logout
                  _buildMenuItem(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    iconColor: const Color(0xFFEF4444),
                    onTap: _handleLogout,
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Menu Item Row Widget ───────────────────────────────────────────────────
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF6D28D9),
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFF111827),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF3F4F6),
      indent: 24,
      endIndent: 24,
    );
  }
}
