import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/color_schemes.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/services/auth_scope.dart';
import '../../notifications/screens/customer_notifications_screen.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/screens/customer_queue_screen.dart';
import '../../support/screens/support_center_screen.dart';
import 'customer_history_screen.dart';
import 'security_privacy_screen.dart';

/// Screen displaying customer profile details, quick shortcuts, and account preferences.
class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final QueueRepository _queueRepo = QueueRepository();
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
            Icon(Icons.edit_rounded, color: AppColorSchemes.navy),
            SizedBox(width: 8),
            Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorSchemes.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Changes'),
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
              backgroundColor: AppColorSchemes.navy,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColorSchemes.navy),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColorSchemes.navy),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
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
              backgroundColor: AppColorSchemes.navy,
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
      return const Icon(Icons.person, size: 48, color: Color(0xFFC9A45C));
    }
    final trimmed = avatar.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        key: ValueKey(trimmed),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 48, color: Color(0xFFC9A45C)),
      );
    } else if (trimmed.startsWith('data:image')) {
      try {
        final base64Str = trimmed.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, key: ValueKey(trimmed.hashCode), width: 80, height: 80, fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.person, size: 48, color: Color(0xFFC9A45C));
      }
    } else {
      final file = File(trimmed);
      if (file.existsSync()) {
        return Image.file(file, key: ValueKey(trimmed), width: 80, height: 80, fit: BoxFit.cover);
      }
      return const Icon(Icons.person, size: 48, color: Color(0xFFC9A45C));
    }
  }

  Future<void> _handleOpenActiveQueue() async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final activeTicket = await _queueRepo.getActiveTicketForCustomer(user.id);
    if (!mounted) return;

    if (activeTicket != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerQueueScreen(ticket: activeTicket),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('No Active Queue Ticket'),
          content: const Text(
            'You do not have an active queue token right now. Search for a salon on the Home screen to join a live queue!',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColorSchemes.gold,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final auth = AuthScope.of(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
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
    final theme = Theme.of(context);
    final auth = AuthScope.of(context);
    final user = auth.currentUser;

    final name = user?.fullName?.isNotEmpty == true ? user!.fullName! : 'Valued Customer';
    final email = user?.email ?? 'customer@example.com';
    final phone = user?.phone?.isNotEmpty == true ? user!.phone! : '+91 98765 00000';
    final avatar = user?.avatarUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text(
          'My Profile & Account',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColorSchemes.navy),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColorSchemes.navy),
            tooltip: 'Edit Profile',
            onPressed: _handleEditProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // ── 1. Profile Header Card ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14243A), Color(0xFF1E3650)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFC9A45C), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14243A).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _handlePickProfilePhoto,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            child: _isUploadingPhoto
                                ? const CircularProgressIndicator(color: AppColorSchemes.gold)
                                : ClipOval(
                                    child: _buildAvatarWidget(avatar),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _handlePickProfilePhoto,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColorSchemes.gold,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: AppColorSchemes.navy),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC9A45C).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFC9A45C), width: 1),
                          ),
                          child: const Text(
                            '✨ VERIFIED CUSTOMER',
                            style: TextStyle(
                              color: Color(0xFFDDC088),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _handleEditProfile,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.edit, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 2. Contact Information Card ────────────────────────────────
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                elevation: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Contact Details',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: _handleEditProfile,
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: const Text('Update', style: TextStyle(color: AppColorSchemes.navy, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_outlined, color: AppColorSchemes.navy),
                        title: const Text('Phone Number'),
                        subtitle: Text(phone),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined, color: AppColorSchemes.navy),
                        title: const Text('Email Address'),
                        subtitle: Text(email),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── 3. Profile Shortcuts & Actions ─────────────────────────────
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                elevation: 0.5,
                child: Column(
                  children: [
                    // My Active Queue
                    ListTile(
                      leading: const Icon(Icons.confirmation_number_outlined, color: AppColorSchemes.navy),
                      title: const Text('My Queue', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Check live status of your active token', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: _handleOpenActiveQueue,
                    ),
                    const Divider(height: 1),

                    // Booking & Queue History
                    ListTile(
                      leading: const Icon(Icons.history, color: AppColorSchemes.navy),
                      title: const Text('Booking & Queue History', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Past salon visits and digital receipts', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CustomerHistoryScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),

                    // Favorite Salons
                    ListTile(
                      leading: const Icon(Icons.favorite_outline_rounded, color: AppColorSchemes.navy),
                      title: const Text('Favorite Salons', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Your saved salons for fast queueing', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        AppRouter.navigateToCustomerEntry(context);
                      },
                    ),
                    const Divider(height: 1),

                    // Notifications
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined, color: AppColorSchemes.navy),
                      title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Turn alerts, queue calls & updates', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CustomerNotificationsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),

                    // Security & Privacy
                    ListTile(
                      leading: const Icon(Icons.shield_outlined, color: AppColorSchemes.navy),
                      title: const Text('Security & Privacy', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Account protection & data privacy', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SecurityPrivacyScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),

                    // Help & Support Center
                    ListTile(
                      leading: const Icon(Icons.help_outline_rounded, color: AppColorSchemes.navy),
                      title: const Text('Help & Support Center', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('FAQs, submit query & track tickets', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SupportCenterScreen(isOwner: false),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 4. Sign Out Button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
