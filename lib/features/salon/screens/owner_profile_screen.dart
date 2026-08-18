import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../shared/models/salon.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/services/auth_scope.dart';
import '../data/salon_repository.dart';

/// Type of image to upload for isolated bucket folder routing
enum ImageUploadType { profile, cover, gallery, post }

/// Screen allowing Salon Owner to manage Owner Profile, Profile Photo,
/// Salon Cover Image, and Salon Photo Gallery.
class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key, required this.salon, this.onUpdated});

  final Salon salon;
  final VoidCallback? onUpdated;

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final SalonRepository _salonRepo = SalonRepository();
  final AuthRepository _authRepo = AuthRepository();
  final ImagePicker _picker = ImagePicker();

  late Salon _currentSalon;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentSalon = widget.salon;
    _fetchFreshData();
  }

  Future<void> _fetchFreshData() async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user != null && user.isAuthenticated && user.id.isNotEmpty && _salonRepo.client != null) {
      final fresh = await _salonRepo.fetchOwnerSalon(user.id);
      if (fresh != null && mounted) {
        setState(() {
          _currentSalon = fresh;
        });
      }
    }
  }

  // ── Image Picker & Compression Helper ────────────────────────────────────
  Future<String?> _pickAndProcessImage({
    required ImageSource source,
    ImageUploadType type = ImageUploadType.profile,
  }) async {
    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? _currentSalon.ownerId ?? 'owner';

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;

      final String persistentUrl;
      switch (type) {
        case ImageUploadType.profile:
          persistentUrl = await _authRepo.uploadOwnerProfilePhoto(
            userId: userId,
            imageBytes: bytes,
            fileExt: ext,
          );
          break;
        case ImageUploadType.cover:
          persistentUrl = await _authRepo.uploadOwnerCoverPhoto(
            userId: userId,
            imageBytes: bytes,
            fileExt: ext,
          );
          break;
        case ImageUploadType.gallery:
          persistentUrl = await _authRepo.uploadOwnerGalleryPhoto(
            userId: userId,
            imageBytes: bytes,
            fileExt: ext,
          );
          break;
        case ImageUploadType.post:
          persistentUrl = await _authRepo.uploadOwnerPostPhoto(
            userId: userId,
            imageBytes: bytes,
            fileExt: ext,
          );
          break;
      }

      return persistentUrl;
    } catch (e) {
      debugPrint('[OwnerProfileScreen] image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to upload image. Please try again.'),
            backgroundColor: AppColorSchemes.busy,
          ),
        );
      }
      return null;
    }
  }

  void _showImageSourceDialog({
    required String title,
    required Function(String imageUri) onImageSelected,
    ImageUploadType type = ImageUploadType.profile,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.navy.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColorSchemes.navy),
                ),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final path = await _pickAndProcessImage(source: ImageSource.camera, type: type);
                  if (path != null) onImageSelected(path);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.navy.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColorSchemes.navy),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final path = await _pickAndProcessImage(source: ImageSource.gallery, type: type);
                  if (path != null) onImageSelected(path);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile Photo Updates ────────────────────────────────────────────────
  Future<void> _handleUpdateProfilePhoto(String newPhotoPath) async {
    setState(() => _isLoading = true);
    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? _currentSalon.ownerId ?? '';

    // Update Salon in DB
    await _salonRepo.updateOwnerProfile(
      salonId: _currentSalon.id,
      ownerId: userId,
      ownerAvatarUrl: newPhotoPath,
    );

    // Update User Profile in DB
    if (userId.isNotEmpty) {
      await _authRepo.updateProfile(
        userId: userId,
        avatarUrl: newPhotoPath,
      );
    }

    // Update In-Memory Auth State immediately
    auth.updateCurrentUserAvatar(newPhotoPath);

    setState(() {
      _currentSalon = _currentSalon.copyWith(ownerAvatarUrl: newPhotoPath);
      _isLoading = false;
    });
    widget.onUpdated?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image uploaded successfully.'),
          backgroundColor: AppColorSchemes.available,
        ),
      );
    }
  }

  Future<void> _confirmDeleteProfilePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Profile Photo?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to remove your profile photo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleRemoveProfilePhoto();
    }
  }

  Future<void> _handleRemoveProfilePhoto() async {
    setState(() => _isLoading = true);
    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? _currentSalon.ownerId ?? '';
    final oldPhoto = _currentSalon.ownerAvatarUrl;

    try {
      // 1. Delete from Supabase Storage & Profiles table
      if (userId.isNotEmpty) {
        await _authRepo.deleteProfileImage(
          userId: userId,
          photoUrl: oldPhoto,
        );
      }

      // 2. Update Salon record in DB & fallback memory
      await _salonRepo.updateOwnerProfile(
        salonId: _currentSalon.id,
        ownerId: userId,
        ownerAvatarUrl: null,
        clearAvatar: true,
      );

      // 3. Update In-Memory Auth State immediately
      auth.updateCurrentUserAvatar(null);

      // 4. Update local state
      setState(() {
        _currentSalon = _currentSalon.copyWith(clearOwnerAvatar: true);
        _isLoading = false;
      });
      widget.onUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed successfully.'),
            backgroundColor: AppColorSchemes.available,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete profile photo. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // ── Salon Cover Image Updates ────────────────────────────────────────────
  Future<void> _handleUpdateCoverImage(String newCoverPath) async {
    setState(() => _isLoading = true);
    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? _currentSalon.ownerId;
    await _salonRepo.updateCoverImage(
      salonId: _currentSalon.id,
      ownerId: userId,
      coverImageUrl: newCoverPath,
    );
    setState(() {
      _currentSalon = _currentSalon.copyWith(
        coverImageUrl: newCoverPath,
        bannerUrl: newCoverPath,
      );
      _isLoading = false;
    });
    widget.onUpdated?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salon cover image updated!'),
          backgroundColor: AppColorSchemes.available,
        ),
      );
    }
  }

  Future<void> _handleRemoveCoverImage() async {
    setState(() => _isLoading = true);
    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? _currentSalon.ownerId;
    await _salonRepo.updateCoverImage(
      salonId: _currentSalon.id,
      ownerId: userId,
      coverImageUrl: null,
    );
    setState(() {
      _currentSalon = _currentSalon.copyWith(
        coverImageUrl: null,
        bannerUrl: null,
      );
      _isLoading = false;
    });
    widget.onUpdated?.call();
  }

  // ── Salon Gallery Updates ────────────────────────────────────────────────
  Future<void> _handleAddGalleryPhoto(String newImagePath) async {
    setState(() => _isLoading = true);
    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? _currentSalon.ownerId;
    await _salonRepo.addGalleryImage(
      salonId: _currentSalon.id,
      ownerId: userId,
      imageUrl: newImagePath,
    );
    setState(() {
      _currentSalon = _currentSalon.copyWith(
        galleryImages: [..._currentSalon.galleryImages, newImagePath],
      );
      _isLoading = false;
    });
    widget.onUpdated?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo added to salon gallery!'),
          backgroundColor: AppColorSchemes.available,
        ),
      );
    }
  }

  Future<void> _handleRemoveGalleryPhoto(String imagePath) async {
    setState(() => _isLoading = true);
    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? _currentSalon.ownerId;
    await _salonRepo.removeGalleryImage(
      salonId: _currentSalon.id,
      ownerId: userId,
      imageUrl: imagePath,
    );
    setState(() {
      _currentSalon = _currentSalon.copyWith(
        galleryImages: _currentSalon.galleryImages.where((i) => i != imagePath).toList(),
      );
      _isLoading = false;
    });
    widget.onUpdated?.call();
  }

  // ── Edit Owner Profile Name Dialog ───────────────────────────────────────
  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(
      text: _currentSalon.ownerName ?? 'Rahul Sharma',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Edit Owner Profile', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Owner Full Name',
            prefixIcon: Icon(Icons.person_outline, color: AppColorSchemes.navy),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                final auth = AuthScope.of(context, listen: false);
                final userId = auth.currentUser?.id ?? _currentSalon.ownerId ?? '';

                await _salonRepo.updateOwnerProfile(
                  salonId: _currentSalon.id,
                  ownerId: userId,
                  ownerName: newName,
                );

                if (userId.isNotEmpty) {
                  await _authRepo.updateProfile(
                    userId: userId,
                    fullName: newName,
                  );
                }

                auth.updateCurrentUserName(newName);

                setState(() {
                  _currentSalon = _currentSalon.copyWith(ownerName: newName);
                });
                widget.onUpdated?.call();
              }
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorSchemes.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Fullscreen Image Lightbox Viewer ─────────────────────────────────────
  void _openImageViewer(String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImageWidget(imagePath, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
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
    final ownerEmail = auth.currentUser?.email ?? 'owner@salonqueue.app';
    final ownerDisplayName = _currentSalon.ownerName ??
        (auth.currentUser?.fullName ?? 'Rahul Sharma');

    return Scaffold(
      backgroundColor: AppColorSchemes.ivory,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Owner Profile',
          style: TextStyle(
            color: AppColorSchemes.charcoal,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColorSchemes.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColorSchemes.gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Top Owner Profile Header Card ─────────────────────
                  _buildOwnerHeaderCard(ownerDisplayName, ownerEmail),

                  const SizedBox(height: 16),

                  // ── 2. Profile Photo Section ─────────────────────────────
                  _buildProfilePhotoSection(),

                  const SizedBox(height: 16),

                  // ── 3. Salon Cover Image Section ─────────────────────────
                  _buildSalonCoverImageSection(),

                  const SizedBox(height: 16),

                  // ── 4. Salon Gallery Section ─────────────────────────────
                  _buildSalonGallerySection(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 1. OWNER HEADER CARD ──────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOwnerHeaderCard(String ownerName, String ownerEmail) {
    final avatar = _currentSalon.ownerAvatarUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColorSchemes.navy, AppColorSchemes.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColorSchemes.navy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColorSchemes.gold.withValues(alpha: 0.3),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColorSchemes.navy,
                  child: avatar != null && avatar.isNotEmpty
                      ? ClipOval(
                          child: _buildImageWidget(
                            avatar,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.person, size: 44, color: AppColorSchemes.gold),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showImageSourceDialog(
                    title: 'Update Profile Photo',
                    onImageSelected: _handleUpdateProfilePhoto,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColorSchemes.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ownerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColorSchemes.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColorSchemes.gold.withValues(alpha: 0.4)),
            ),
            child: const Text(
              'SALON OWNER',
              style: TextStyle(
                color: AppColorSchemes.goldLight,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentSalon.name,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            ownerEmail,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _showEditProfileDialog,
            icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
            label: const Text('Edit Profile Name', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 2. PROFILE PHOTO SECTION ──────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProfilePhotoSection() {
    final avatar = _currentSalon.ownerAvatarUrl;
    final hasPhoto = avatar != null && avatar.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColorSchemes.navy.withValues(alpha: 0.08),
            child: hasPhoto
                ? ClipOval(
                    child: _buildImageWidget(
                      avatar,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.person_rounded,
                    color: AppColorSchemes.navy, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColorSchemes.charcoal),
                ),
                Text(
                  hasPhoto ? 'Photo uploaded' : 'No photo uploaded',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showImageSourceDialog(
              title: hasPhoto ? 'Update Profile Photo' : 'Upload Profile Photo',
              onImageSelected: _handleUpdateProfilePhoto,
            ),
            child: Text(
              hasPhoto ? 'Change' : 'Upload',
              style: const TextStyle(
                  color: AppColorSchemes.navy, fontWeight: FontWeight.bold),
            ),
          ),
          if (hasPhoto) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFEF4444), size: 20),
              tooltip: 'Delete Profile Photo',
              onPressed: _confirmDeleteProfilePhoto,
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 3. SALON COVER IMAGE SECTION ──────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSalonCoverImageSection() {
    final cover = _currentSalon.effectiveCoverImage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Salon Cover Image',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColorSchemes.charcoal),
              ),
              if (cover != null)
                TextButton.icon(
                  onPressed: () => _showImageSourceDialog(
                    title: 'Change Salon Cover Image',
                    onImageSelected: _handleUpdateCoverImage,
                    type: ImageUploadType.cover,
                  ),
                  icon: const Icon(Icons.refresh, size: 14, color: AppColorSchemes.navy),
                  label: const Text('Change', style: TextStyle(color: AppColorSchemes.navy, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'This image will be shown to customers on your salon profile.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),

          // Preview Area
          if (cover != null && cover.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                    ),
                    child: _buildImageWidget(cover, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
                      onPressed: _handleRemoveCoverImage,
                    ),
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: () => _showImageSourceDialog(
                title: 'Upload Salon Cover Image',
                onImageSelected: _handleUpdateCoverImage,
                type: ImageUploadType.cover,
              ),
              child: Container(
                height: 130,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF8F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColorSchemes.gold.withValues(alpha: 0.4), style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColorSchemes.gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_photo_alternate_rounded, color: AppColorSchemes.gold, size: 28),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload Salon Cover Image',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColorSchemes.navy),
                    ),
                    const Text(
                      'Tap to choose from Camera or Gallery',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 4. SALON PHOTO GALLERY SECTION ────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSalonGallerySection() {
    final gallery = _currentSalon.galleryImages;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Salon Gallery',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColorSchemes.charcoal),
              ),
              Text(
                '${gallery.length} photos',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Show customers your salon, hairstyles, work and atmosphere.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),

          // Photos Grid
          if (gallery.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gallery.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, idx) {
                final img = gallery[idx];
                return GestureDetector(
                  onTap: () => _openImageViewer(img),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildImageWidget(img, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _handleRemoveGalleryPhoto(img),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
          ],

          // + Add Photos Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _showImageSourceDialog(
                title: 'Add Photo to Salon Gallery',
                onImageSelected: _handleAddGalleryPhoto,
                type: ImageUploadType.gallery,
              ),
              icon: const Icon(Icons.add_a_photo_rounded, size: 18, color: AppColorSchemes.navy),
              label: const Text(
                '+ Add Photos',
                style: TextStyle(color: AppColorSchemes.navy, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColorSchemes.navy, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Universal Image Widget Helper (Handles Local file, Base64, and Network URLs) ──
  Widget _buildImageWidget(String path, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(width, height),
      );
    } else if (path.startsWith('data:image')) {
      try {
        final base64Str = path.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, width: width, height: height, fit: fit);
      } catch (_) {
        return _buildImagePlaceholder(width, height);
      }
    } else {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, width: width, height: height, fit: fit);
      }
      return _buildImagePlaceholder(width, height);
    }
  }

  Widget _buildImagePlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
      ),
    );
  }
}
