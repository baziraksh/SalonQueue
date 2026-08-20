import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';

/// Notification types supported in the SalonQueue Owner & Customer ecosystem.
enum NotificationType {
  customerJoined('CUSTOMER_JOINED', 'Customer Joined Queue'),
  customerCancelled('CUSTOMER_CANCELLED', 'Queue Cancellation'),
  customerCalled('CUSTOMER_CALLED', 'Customer Called to Chair'),
  queueUpdate('QUEUE_UPDATE', 'Queue Status Update'),
  bookingUpdate('BOOKING_UPDATE', 'Booking Update'),
  supportResolved('SUPPORT_RESOLVED', 'Support Issue Resolved'),
  supportUpdate('SUPPORT_UPDATE', 'Support Ticket Update'),
  systemUpdate('SYSTEM_UPDATE', 'System Notification');

  const NotificationType(this.dbName, this.displayTitle);
  final String dbName;
  final String displayTitle;

  static NotificationType fromDb(String? value) {
    if (value == null) return NotificationType.systemUpdate;
    for (final type in NotificationType.values) {
      if (type.dbName.toUpperCase() == value.toUpperCase() ||
          type.name.toUpperCase() == value.toUpperCase()) {
        return type;
      }
    }
    return NotificationType.systemUpdate;
  }
}

/// Represents a persistent notification for a Salon Owner or Customer.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String title;
  final String message;
  final NotificationType type;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      ownerId: (json['user_id'] ?? json['recipient_id'] ?? json['owner_id'] ?? '').toString(),
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      type: NotificationType.fromDb(json['type'] as String?),
      relatedId: json['related_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient_id': ownerId,
      'owner_id': ownerId,
      'title': title,
      'message': message,
      'type': type.dbName,
      if (relatedId != null) 'related_id': relatedId,
      'is_read': isRead,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? message,
    NotificationType? type,
    String? relatedId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Visual icon for this notification type
  IconData get icon {
    switch (type) {
      case NotificationType.customerJoined:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.customerCancelled:
        return Icons.person_remove_rounded;
      case NotificationType.customerCalled:
        return Icons.chair_rounded;
      case NotificationType.queueUpdate:
        return Icons.tune_rounded;
      case NotificationType.bookingUpdate:
        return Icons.event_available_rounded;
      case NotificationType.supportResolved:
        return Icons.check_circle_outline_rounded;
      case NotificationType.supportUpdate:
        return Icons.support_agent_rounded;
      case NotificationType.systemUpdate:
        return Icons.notifications_active_rounded;
    }
  }

  /// Visual theme color for badge/icon
  Color get accentColor {
    switch (type) {
      case NotificationType.customerJoined:
        return AppColorSchemes.navy;
      case NotificationType.customerCancelled:
        return AppColorSchemes.busy;
      case NotificationType.customerCalled:
        return AppColorSchemes.gold;
      case NotificationType.queueUpdate:
        return AppColorSchemes.navyLight;
      case NotificationType.bookingUpdate:
        return AppColorSchemes.gold;
      case NotificationType.supportResolved:
        return AppColorSchemes.available;
      case NotificationType.supportUpdate:
        return AppColorSchemes.navy;
      case NotificationType.systemUpdate:
        return AppColorSchemes.charcoal;
    }
  }

  /// Human-friendly relative time string
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
