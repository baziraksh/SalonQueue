import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';

/// Status of a support request ticket.
enum SupportTicketStatus {
  open,
  inProgress,
  resolved;

  String get label {
    switch (this) {
      case SupportTicketStatus.open:
        return 'OPEN';
      case SupportTicketStatus.inProgress:
        return 'IN PROGRESS';
      case SupportTicketStatus.resolved:
        return 'RESOLVED';
    }
  }

  Color get color {
    switch (this) {
      case SupportTicketStatus.open:
        return AppColorSchemes.gold;
      case SupportTicketStatus.inProgress:
        return const Color(0xFF2563EB); // Blue
      case SupportTicketStatus.resolved:
        return AppColorSchemes.available; // Green
    }
  }

  Color get backgroundColor {
    switch (this) {
      case SupportTicketStatus.open:
        return const Color(0xFFFEF3C7);
      case SupportTicketStatus.inProgress:
        return const Color(0xFFEFF6FF);
      case SupportTicketStatus.resolved:
        return const Color(0xFFF0FDF4);
    }
  }

  IconData get icon {
    switch (this) {
      case SupportTicketStatus.open:
        return Icons.pending_actions_rounded;
      case SupportTicketStatus.inProgress:
        return Icons.autorenew_rounded;
      case SupportTicketStatus.resolved:
        return Icons.check_circle_outline_rounded;
    }
  }

  static SupportTicketStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'in_progress':
      case 'inprogress':
        return SupportTicketStatus.inProgress;
      case 'resolved':
      case 'closed':
        return SupportTicketStatus.resolved;
      case 'open':
      default:
        return SupportTicketStatus.open;
    }
  }
}

/// Model representing a Help & Support ticket for customer or salon owner.
class SupportTicket {
  final String id;
  final String userId;
  final String userRole; // 'customer' or 'salon_owner'
  final String category;
  final String subject;
  final String description;
  final String? screenshotUrl;
  final SupportTicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? adminResponse;

  const SupportTicket({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.category,
    required this.subject,
    required this.description,
    this.screenshotUrl,
    this.status = SupportTicketStatus.open,
    required this.createdAt,
    required this.updatedAt,
    this.adminResponse,
  });

  String get formattedTicketId {
    if (id.length > 8) {
      return '#TICK-${id.substring(0, 6).toUpperCase()}';
    }
    return '#TICK-$id';
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? 'customer',
      category: json['category']?.toString() ?? 'General',
      subject: json['subject']?.toString() ?? 'Support Request',
      description: json['description']?.toString() ?? '',
      screenshotUrl: json['screenshot_url']?.toString(),
      status: SupportTicketStatus.fromString(json['status']?.toString()),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      adminResponse: json['admin_response']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_role': userRole,
      'category': category,
      'subject': subject,
      'description': description,
      'screenshot_url': screenshotUrl,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'admin_response': adminResponse,
    };
  }

  SupportTicket copyWith({
    String? id,
    String? userId,
    String? userRole,
    String? category,
    String? subject,
    String? description,
    String? screenshotUrl,
    SupportTicketStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? adminResponse,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userRole: userRole ?? this.userRole,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminResponse: adminResponse ?? this.adminResponse,
    );
  }
}
