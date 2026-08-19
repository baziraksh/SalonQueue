// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../notifications/data/notification_repository.dart';
import '../models/support_ticket.dart';

/// Data repository for Help & Support tickets backed by Supabase with demo fallback.
class SupportRepository {
  SupportRepository({supabase.SupabaseClient? client}) : _client = client;

  final supabase.SupabaseClient? _client;
  final NotificationRepository _notifRepo = NotificationRepository();

  supabase.SupabaseClient? get client {
    if (_client != null) return _client;
    try {
      return supabase.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// In-memory storage for offline / mock testing
  static final List<SupportTicket> _demoTickets = [];

  /// Fetches tickets for a specific user ID
  Future<List<SupportTicket>> fetchUserTickets(String userId) async {
    final activeClient = client;
    if (activeClient != null) {
      try {
        final query = activeClient.from('support_tickets').select();
        final res = (userId.isNotEmpty && userId != 'guest-user')
            ? await query.eq('user_id', userId).order('created_at', ascending: false)
            : await query.order('created_at', ascending: false);

        if (res.isNotEmpty) {
          return (res as List)
              .map((item) => SupportTicket.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
        return [];
      } catch (e) {
        debugPrint('[SupportRepository] fetchUserTickets error: $e');
      }
    }

    return _demoTickets.where((t) => t.userId == userId || userId.isEmpty).toList();
  }

  /// Submits a new support request ticket
  Future<SupportTicket> createTicket({
    required String userId,
    required String userRole,
    required String category,
    required String subject,
    required String description,
    String? screenshotUrl,
  }) async {
    final now = DateTime.now();
    final activeClient = client;

    if (activeClient != null) {
      try {
        final res = await activeClient.from('support_tickets').insert({
          'user_id': userId,
          'user_role': userRole,
          'category': category,
          'subject': subject,
          'description': description,
          'screenshot_url': screenshotUrl,
          'status': 'open',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).select().single();

        debugPrint('[SupportRepository] createTicket remote insert success: $res');
        final ticket = SupportTicket.fromJson(Map<String, dynamic>.from(res));

        // In development/demo, simulate auto-resolution notification after a short delay
        _scheduleSimulatedResolution(
          userId: userId,
          ticketId: ticket.id,
          subject: subject,
          userRole: userRole,
        );

        return ticket;
      } catch (e) {
        debugPrint('[SupportRepository] createTicket remote insert error: $e');
      }
    }

    final newId = 'tick-${DateTime.now().millisecondsSinceEpoch}';
    final ticket = SupportTicket(
      id: newId,
      userId: userId,
      userRole: userRole,
      category: category,
      subject: subject,
      description: description,
      screenshotUrl: screenshotUrl,
      status: SupportTicketStatus.open,
      createdAt: now,
      updatedAt: now,
    );
    _demoTickets.insert(0, ticket);

    _scheduleSimulatedResolution(
      userId: userId,
      ticketId: newId,
      subject: subject,
      userRole: userRole,
    );

    return ticket;
  }

  /// Updates support ticket status and dispatches notification if resolved
  Future<void> updateTicketStatus({
    required String ticketId,
    required SupportTicketStatus status,
    required String ownerId,
    required String subject,
    String? adminResponse,
  }) async {
    final now = DateTime.now();
    final statusStr = status.name;

    // Update in-memory ticket
    final idx = _demoTickets.indexWhere((t) => t.id == ticketId);
    if (idx != -1) {
      _demoTickets[idx] = _demoTickets[idx].copyWith(
        status: status,
        adminResponse: adminResponse,
        updatedAt: now,
      );
    }

    final activeClient = client;
    if (activeClient != null) {
      try {
        await activeClient.from('support_tickets').update({
          'status': statusStr,
          'admin_response': ?adminResponse,
          'updated_at': now.toIso8601String(),
        }).eq('id', ticketId);
      } catch (e) {
        debugPrint('[SupportRepository] updateTicketStatus error: $e');
      }
    }

    // Automatically create persistent notification when status is resolved
    if (status == SupportTicketStatus.resolved && ownerId.isNotEmpty) {
      await _notifRepo.notifySupportResolved(
        ownerId: ownerId,
        ticketId: ticketId,
        subject: subject,
        resolutionMessage: adminResponse ?? 'Your support request has been resolved. Tap to view the resolution.',
      );
    }
  }

  /// Helper to trigger resolution notification for demo / testing flow
  void _scheduleSimulatedResolution({
    required String userId,
    required String ticketId,
    required String subject,
    required String userRole,
  }) {
    Future.delayed(const Duration(seconds: 15), () async {
      await updateTicketStatus(
        ticketId: ticketId,
        status: SupportTicketStatus.resolved,
        ownerId: userId,
        subject: subject,
        adminResponse: 'Your inquiry has been investigated and configured successfully. Thank you for using SalonQueue!',
      );
    });
  }
}
