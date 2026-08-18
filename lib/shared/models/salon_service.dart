/// Represents a service offered by a salon (e.g. Haircut, Facial, Beard Trim).
class SalonService {
  final String id;
  final String salonId;
  final String name;
  final String category;
  final double price;
  final int durationMinutes;
  final bool isActive;

  const SalonService({
    required this.id,
    required this.salonId,
    required this.name,
    required this.category,
    required this.price,
    this.durationMinutes = 20,
    this.isActive = true,
  });

  factory SalonService.fromJson(Map<String, dynamic> json) {
    return SalonService(
      id: json['id'] as String? ?? '',
      salonId: json['salon_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Hair',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: json['duration_minutes'] as int? ?? 20,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'salon_id': salonId,
      'name': name,
      'category': category,
      'price': price,
      'duration_minutes': durationMinutes,
      'is_active': isActive,
    };
  }

  SalonService copyWith({
    String? id,
    String? salonId,
    String? name,
    String? category,
    double? price,
    int? durationMinutes,
    bool? isActive,
  }) {
    return SalonService(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isActive: isActive ?? this.isActive,
    );
  }
}
