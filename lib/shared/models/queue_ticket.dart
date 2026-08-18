import 'package:flutter/material.dart';

/// Status of a digital queue ticket
enum QueueStatus {
  waiting,
  inChair,
  completed,
  cancelled,
  skipped;

  static QueueStatus fromDb(String? value) {
    return switch (value?.toUpperCase()) {
      'IN_CHAIR' => QueueStatus.inChair,
      'COMPLETED' => QueueStatus.completed,
      'CANCELLED' => QueueStatus.cancelled,
      'SKIPPED' => QueueStatus.skipped,
      _ => QueueStatus.waiting,
    };
  }

  String get dbName => switch (this) {
        QueueStatus.waiting => 'WAITING',
        QueueStatus.inChair => 'IN_CHAIR',
        QueueStatus.completed => 'COMPLETED',
        QueueStatus.cancelled => 'CANCELLED',
        QueueStatus.skipped => 'SKIPPED',
      };

  String get label => switch (this) {
        QueueStatus.waiting => 'In Waiting Line',
        QueueStatus.inChair => 'Currently In Chair',
        QueueStatus.completed => 'Completed',
        QueueStatus.cancelled => 'Cancelled',
        QueueStatus.skipped => 'Skipped',
      };

  Color get color => switch (this) {
        QueueStatus.waiting => const Color(0xFFE65100), // Orange
        QueueStatus.inChair => const Color(0xFF6750A4), // Purple
        QueueStatus.completed => const Color(0xFF2E7D32), // Green
        QueueStatus.cancelled => const Color(0xFFC62828), // Red
        QueueStatus.skipped => const Color(0xFF757575), // Grey
      };
}

/// Represents a digital queue ticket for a customer at a salon.
class QueueTicket {
  final String id;
  final String salonId;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final List<String> serviceNames;
  final double totalPrice;
  final int totalDurationMinutes;
  final int tokenNumber;
  final QueueStatus status;
  final int? chairNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const QueueTicket({
    required this.id,
    required this.salonId,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.serviceNames = const [],
    this.totalPrice = 0.0,
    this.totalDurationMinutes = 20,
    required this.tokenNumber,
    this.status = QueueStatus.waiting,
    this.chairNumber,
    this.notes,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  /// Formatted token identifier (e.g. #A-07)
  String get formattedToken => '#A-${tokenNumber.toString().padLeft(2, '0')}';

  bool get isWaiting => status == QueueStatus.waiting;
  bool get isInChair => status == QueueStatus.inChair;
  bool get isCompleted => status == QueueStatus.completed;
  bool get isCancelled => status == QueueStatus.cancelled;

  factory QueueTicket.fromJson(Map<String, dynamic> json) {
    List<String> services = [];
    if (json['service_names'] is List) {
      services = (json['service_names'] as List).map((e) => e.toString()).toList();
    }

    return QueueTicket(
      id: json['id'] as String? ?? '',
      salonId: json['salon_id'] as String? ?? '',
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String? ?? 'Customer',
      customerPhone: json['customer_phone'] as String?,
      serviceNames: services,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      totalDurationMinutes: json['total_duration_minutes'] as int? ?? 20,
      tokenNumber: json['token_number'] as int? ?? 1,
      status: QueueStatus.fromDb(json['status'] as String?),
      chairNumber: json['chair_number'] as int?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'salon_id': salonId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'service_names': serviceNames,
      'total_price': totalPrice,
      'total_duration_minutes': totalDurationMinutes,
      'token_number': tokenNumber,
      'status': status.dbName,
      'chair_number': chairNumber,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  QueueTicket copyWith({
    String? id,
    String? salonId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    List<String>? serviceNames,
    double? totalPrice,
    int? totalDurationMinutes,
    int? tokenNumber,
    QueueStatus? status,
    int? chairNumber,
    String? notes,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return QueueTicket(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      serviceNames: serviceNames ?? this.serviceNames,
      totalPrice: totalPrice ?? this.totalPrice,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      status: status ?? this.status,
      chairNumber: chairNumber ?? this.chairNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
