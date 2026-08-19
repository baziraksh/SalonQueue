import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';
import '../models/salon.dart';

/// Premium salon card matching the reference design:
/// - Real store/cover image uploaded by owner or luxury fallback gradient
/// - Availability badge ("AVAILABLE NOW" / "BUSY" / "CLOSED")
/// - Verified salon badge
/// - Favorite heart icon
/// - Distance badge
/// - Salon name, Rating (with review count), Location, Owner info
/// - Wait time & in-queue count
/// - Gold "JOIN QUEUE" CTA button
class SalonCard extends StatelessWidget {
  final Salon salon;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onTap;
  final VoidCallback onJoinQueue;

  const SalonCard({
    super.key,
    required this.salon,
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.onTap,
    required this.onJoinQueue,
  });

  Widget _buildCoverImage(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return Image.network(
          imagePath,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackBanner(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 140,
              width: double.infinity,
              color: AppColorSchemes.navy,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColorSchemes.gold,
                  ),
                ),
              ),
            );
          },
        );
      } else if (imagePath.startsWith('data:image')) {
        try {
          final base64Str = imagePath.split(',').last;
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        } catch (_) {
          return _buildFallbackBanner();
        }
      } else {
        final file = File(imagePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        }
      }
    }
    return _buildFallbackBanner();
  }

  Widget _buildFallbackBanner() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColorSchemes.navy,
            AppColorSchemes.navyLight,
            Color(0xFF2C4A6F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColorSchemes.gold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColorSchemes.gold,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.content_cut,
                color: AppColorSchemes.gold,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                salon.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerAvatar(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: AppColorSchemes.gold,
        child: Icon(Icons.person, size: 14, color: AppColorSchemes.navy),
      );
    }
    if (avatarUrl.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const CircleAvatar(
            radius: 12,
            backgroundColor: AppColorSchemes.gold,
            child: Icon(Icons.person, size: 14, color: AppColorSchemes.navy),
          ),
        ),
      );
    } else if (avatarUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(avatarUrl.split(',').last);
        return ClipOval(
          child: Image.memory(bytes, width: 24, height: 24, fit: BoxFit.cover),
        );
      } catch (_) {
        return const CircleAvatar(
          radius: 12,
          backgroundColor: AppColorSchemes.gold,
          child: Icon(Icons.person, size: 14, color: AppColorSchemes.navy),
        );
      }
    }
    return const CircleAvatar(
      radius: 12,
      backgroundColor: AppColorSchemes.gold,
      child: Icon(Icons.person, size: 14, color: AppColorSchemes.navy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rush = salon.rushLevel;
    final isOpen = salon.isQueueOpen;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Banner / Real Cover Image ─────────────────────
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                    child: _buildCoverImage(salon.effectiveCoverImage),
                  ),

                  // Top Dark Gradient Scrim Overlay for Contrast
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Status Badge: "AVAILABLE NOW" / "BUSY"
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? (rush == RushLevel.low
                                ? AppColorSchemes.available
                                : AppColorSchemes.moderate)
                            : AppColorSchemes.busy,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            !isOpen
                                ? 'CLOSED'
                                : (rush == RushLevel.low
                                    ? 'AVAILABLE NOW'
                                    : (rush == RushLevel.moderate ? 'MODERATE RUSH' : 'HIGH RUSH')),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Distance Badge (Bottom-left of image)
                  if (salon.distanceKm != null)
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.directions_walk,
                              size: 13,
                              color: AppColorSchemes.gold,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              salon.formattedDistance,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Gallery Photos Indicator Badge (Bottom-right if photos exist)
                  if (salon.galleryImages.isNotEmpty)
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${salon.galleryImages.length} photos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Favorite Heart Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? const Color(0xFFEF4444) : Colors.white,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: onFavoriteTap,
                      ),
                    ),
                  ),
                ],
              ),

              // ── 2. Card Content Details ───────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Rating Row + Verified Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  salon.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColorSchemes.charcoal,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (salon.isVerified) ...[
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF1E88E5),
                                  size: 17,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                              const SizedBox(width: 3),
                              Text(
                                (salon.rating > 0 && salon.reviewCount > 0)
                                    ? '${salon.rating.toStringAsFixed(1)} (${salon.reviewCount})'
                                    : 'New',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Owner information & Location address
                    Row(
                      children: [
                        if (salon.ownerAvatarUrl != null || salon.ownerName != null) ...[
                          _buildOwnerAvatar(salon.ownerAvatarUrl),
                          const SizedBox(width: 6),
                          Text(
                            salon.ownerName ?? 'Owner',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColorSchemes.navy,
                            ),
                          ),
                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                        ],
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColorSchemes.warmGrey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${salon.address}, ${salon.city}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColorSchemes.warmGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Wait Time & Queue Status Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated Wait',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 15,
                                  color: AppColorSchemes.gold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '~${salon.estWaitMinutes} mins',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColorSchemes.charcoal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Queue Status',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${salon.waitingCount} in queue',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: salon.waitingCount > 3
                                    ? AppColorSchemes.busy
                                    : AppColorSchemes.available,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── 3. Main CTA: Gold "JOIN QUEUE" Button ─────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onJoinQueue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColorSchemes.gold,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          shadowColor: AppColorSchemes.gold.withValues(alpha: 0.4),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'JOIN QUEUE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
