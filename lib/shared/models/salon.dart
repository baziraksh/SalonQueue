import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'salon_service.dart';

/// Crowd / rush status level for a salon
enum RushLevel {
  low,
  moderate,
  high;

  String get label => switch (this) {
    RushLevel.low => 'Low Rush',
    RushLevel.moderate => 'Moderate',
    RushLevel.high => 'High Rush',
  };

  Color get color => switch (this) {
    RushLevel.low => const Color(0xFF2E7D32), // Green
    RushLevel.moderate => const Color(0xFFE65100), // Amber / Orange
    RushLevel.high => const Color(0xFFC62828), // Red
  };

  Color get backgroundColor => switch (this) {
    RushLevel.low => const Color(0xFFE8F5E9),
    RushLevel.moderate => const Color(0xFFFFF3E0),
    RushLevel.high => const Color(0xFFFFEBEE),
  };

  IconData get icon => switch (this) {
    RushLevel.low => Icons.check_circle_outline,
    RushLevel.moderate => Icons.access_time,
    RushLevel.high => Icons.local_fire_department,
  };
}

/// Represents a salon location with operating hours, services, geo-coordinates, and live queue status.
class Salon {
  final String id;
  final String? ownerId;
  final String name;
  final String? description;
  final String address;
  final String city;
  final String district;
  final String state;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final double rating;
  final int reviewCount;
  final int activeChairs;
  final bool isQueueOpen;
  final String openingTime;
  final String closingTime;
  final String? bannerUrl;
  final String? coverImageUrl;
  final String? ownerAvatarUrl;
  final String? ownerName;
  final List<String> galleryImages;
  final int waitingCount;
  final int estWaitMinutes;
  final double? distanceKm;
  final List<SalonService> services;
  final bool isVerified;

  const Salon({
    required this.id,
    this.ownerId,
    required this.name,
    this.description,
    required this.address,
    required this.city,
    this.district = '',
    this.state = 'Maharashtra',
    this.pincode,
    this.latitude,
    this.longitude,
    this.phone,
    this.rating = 4.8,
    this.reviewCount = 50,
    this.activeChairs = 3,
    this.isQueueOpen = true,
    this.openingTime = '09:00 AM',
    this.closingTime = '09:00 PM',
    this.bannerUrl,
    this.coverImageUrl,
    this.ownerAvatarUrl,
    this.ownerName,
    this.galleryImages = const [],
    this.waitingCount = 0,
    this.estWaitMinutes = 0,
    this.distanceKm,
    this.services = const [],
    this.isVerified = true,
  });

  /// Effective cover image URL (falls back to bannerUrl if coverImageUrl is null)
  String? get effectiveCoverImage => coverImageUrl ?? bannerUrl;

  /// Calculates rush level based on people waiting vs active chairs
  RushLevel get rushLevel {
    if (!isQueueOpen) return RushLevel.low;
    final ratio = activeChairs > 0 ? waitingCount / activeChairs : waitingCount;
    if (ratio <= 0.6) return RushLevel.low;
    if (ratio <= 1.5) return RushLevel.moderate;
    return RushLevel.high;
  }

  /// Formatted user-friendly distance string (e.g. "1.2 km away", "800 m away")
  String get formattedDistance {
    if (distanceKm == null) return '';
    if (distanceKm! < 1.0) {
      return '${(distanceKm! * 1000).round()} m away';
    }
    return '${distanceKm!.toStringAsFixed(1)} km away';
  }

  /// Calculates distance using Haversine formula
  double calculateDistance(double userLat, double userLng) {
    if (latitude == null || longitude == null) return 5.0;
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        math.cos((latitude! - userLat) * p) / 2 +
        math.cos(userLat * p) *
            math.cos(latitude! * p) *
            (1 - math.cos((longitude! - userLng) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  factory Salon.fromJson(
    Map<String, dynamic> json, {
    List<SalonService>? services,
    double? userLat,
    double? userLng,
  }) {
    final waiting = json['waiting_count'] as int? ?? 0;
    final chairs = json['active_chairs'] as int? ?? 3;
    final calculatedWait =
        (waiting * (chairs > 0 ? (20 / chairs).round() : 15));

    final lat = (json['latitude'] as num?)?.toDouble() ?? 18.5204;
    final lng = (json['longitude'] as num?)?.toDouble() ?? 73.8567;

    double? computedDist;
    if (userLat != null && userLng != null) {
      const p = 0.017453292519943295;
      final a =
          0.5 -
          math.cos((lat - userLat) * p) / 2 +
          math.cos(userLat * p) *
              math.cos(lat * p) *
              (1 - math.cos((lng - userLng) * p)) /
              2;
      computedDist = 12742 * math.asin(math.sqrt(a));
    } else {
      computedDist = (json['distance_km'] as num?)?.toDouble();
    }

    final rawGallery =
        json['gallery_images'] as List? ?? json['gallery'] as List? ?? [];
    final gallery = rawGallery.map((e) => e.toString()).toList();
    final cover =
        json['cover_image_url'] as String? ?? json['banner_url'] as String?;

    return Salon(
      id: json['id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String? ?? (json['city'] as String? ?? ''),
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String?,
      latitude: lat,
      longitude: lng,
      phone: json['phone'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? 0,
      activeChairs: chairs > 0 ? chairs : 1,
      isQueueOpen: json['is_queue_open'] as bool? ?? true,
      openingTime: json['opening_time'] as String? ?? '09:00 AM',
      closingTime: json['closing_time'] as String? ?? '09:00 PM',
      bannerUrl: cover,
      coverImageUrl: cover,
      ownerAvatarUrl: json['owner_avatar_url'] as String?,
      ownerName: json['owner_name'] as String?,
      galleryImages: gallery,
      waitingCount: waiting,
      estWaitMinutes: calculatedWait,
      distanceKm: computedDist,
      services:
          services ??
          (json['services'] as List?)
              ?.map(
                (s) =>
                    SalonService.fromJson(Map<String, dynamic>.from(s as Map)),
              )
              .toList() ??
          [],
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'district': district,
      'state': state,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'rating': rating,
      'review_count': reviewCount,
      'active_chairs': activeChairs,
      'is_queue_open': isQueueOpen,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'banner_url': bannerUrl ?? coverImageUrl,
      'cover_image_url': coverImageUrl ?? bannerUrl,
      'owner_avatar_url': ownerAvatarUrl,
      'owner_name': ownerName,
      'gallery_images': galleryImages,
      'waiting_count': waitingCount,
      'distance_km': distanceKm,
      'is_verified': isVerified,
      'services': services.map((s) => s.toJson()).toList(),
    };
  }

  Salon copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? address,
    String? city,
    String? district,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    String? phone,
    double? rating,
    int? reviewCount,
    int? activeChairs,
    bool? isQueueOpen,
    String? openingTime,
    String? closingTime,
    String? bannerUrl,
    String? coverImageUrl,
    String? ownerAvatarUrl,
    bool clearOwnerAvatar = false,
    bool clearCoverImage = false,
    bool clearBanner = false,
    String? ownerName,
    List<String>? galleryImages,
    int? waitingCount,
    int? estWaitMinutes,
    double? distanceKm,
    List<SalonService>? services,
    bool? isVerified,
  }) {
    return Salon(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      district: district ?? this.district,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      activeChairs: activeChairs ?? this.activeChairs,
      isQueueOpen: isQueueOpen ?? this.isQueueOpen,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      bannerUrl: clearBanner ? null : (bannerUrl ?? this.bannerUrl),
      coverImageUrl: clearCoverImage
          ? null
          : (coverImageUrl ?? this.coverImageUrl),
      ownerAvatarUrl: clearOwnerAvatar
          ? null
          : (ownerAvatarUrl ?? this.ownerAvatarUrl),
      ownerName: ownerName ?? this.ownerName,
      galleryImages: galleryImages ?? this.galleryImages,
      waitingCount: waitingCount ?? this.waitingCount,
      estWaitMinutes: estWaitMinutes ?? this.estWaitMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      services: services ?? this.services,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
