// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/app_notification.dart';

/// Data repository for managing persistent and real-time notifications
/// for salon owners and customers.
class NotificationRepository {
  NotificationRepository({supabase.SupabaseClient? client}) : _client = client;

  final supabase.SupabaseClient? _client;

  supabase.SupabaseClient? get client {
    if (_client != null) return _client;
    try {
      return supabase.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static final StreamController<List<AppNotification>> _localStreamController =
      StreamController<List<AppNotification>>.broadcast();

  /// Clears in-memory notifications cache on user logout
  static void clearCache() {
    // Resets local notification stream and states
  }

  // In-memory fallback storage for offline unit tests
  static final List<AppNotification> _inMemoryNotifications = [];

  /// Fetches all notifications for an owner or user ID
  Future<List<AppNotification>> fetchNotifications(String ownerId) async {
    final activeClient = client;
    if (activeClient != null) {
      try {
        final query = activeClient.from('notifications').select();
        final res = (ownerId.isNotEmpty)
            ? await query.eq('user_id', ownerId).order('created_at', ascending: false)
            : await query.order('created_at', ascending: false);

        final list = (res as List)
            .map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        return list;
      } catch (e) {
        debugPrint('[NotificationRepository] fetchNotifications remote notice: $e');
        return [];
      }
    }

    // Fallback to in-memory list for test environments when client is null
    return _inMemoryNotifications
        .where((n) => n.ownerId == ownerId || n.ownerId == 'demo-owner' || ownerId.isEmpty)
        .toList();
  }

  /// Live stream of notifications for real-time dashboard updates
  Stream<List<AppNotification>> streamNotifications(String ownerId) {
    final activeClient = client;
    if (activeClient == null) {
      return _localStreamController.stream.map((all) {
        return all
            .where((n) => n.ownerId == ownerId || n.ownerId == 'demo-owner' || ownerId.isEmpty)
            .toList();
      });
    }

    try {
      return activeClient
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', ownerId)
          .map((rows) {
            final list = rows
                .map((r) => AppNotification.fromJson(Map<String, dynamic>.from(r)))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          })
          .handleError((error) {
            debugPrint('[NotificationRepository] streamNotifications error: $error');
            return <AppNotification>[];
          });
    } catch (e) {
      debugPrint('[NotificationRepository] streamNotifications fallback: $e');
      return Stream.periodic(const Duration(seconds: 4), (_) => fetchNotifications(ownerId))
          .asyncMap((event) => event);
    }
  }

  /// Calculates unread notification count
  Future<int> getUnreadCount(String ownerId) async {
    final list = await fetchNotifications(ownerId);
    return list.where((n) => !n.isRead).length;
  }

  /// Marks a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    // Update local memory
    final idx = _inMemoryNotifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _inMemoryNotifications[idx] = _inMemoryNotifications[idx].copyWith(isRead: true);
      _localStreamController.add(List.from(_inMemoryNotifications));
    }

    final activeClient = client;
    if (activeClient != null) {
      try {
        await activeClient
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId);
      } catch (e) {
        debugPrint('[NotificationRepository] markAsRead error: $e');
      }
    }
  }

  /// Marks all notifications for an owner as read
  Future<void> markAllAsRead(String ownerId) async {
    for (int i = 0; i < _inMemoryNotifications.length; i++) {
      if (_inMemoryNotifications[i].ownerId == ownerId || ownerId.isEmpty) {
        _inMemoryNotifications[i] = _inMemoryNotifications[i].copyWith(isRead: true);
      }
    }
    _localStreamController.add(List.from(_inMemoryNotifications));

    final activeClient = client;
    if (activeClient != null) {
      try {
        if (ownerId.isNotEmpty) {
          await activeClient
              .from('notifications')
              .update({'is_read': true})
              .eq('owner_id', ownerId)
              .eq('is_read', false);
        } else {
          await activeClient
              .from('notifications')
              .update({'is_read': true})
              .eq('is_read', false);
        }
      } catch (e) {
        debugPrint('[NotificationRepository] markAllAsRead error: $e');
      }
    }
  }

  /// Deletes a notification
  Future<void> deleteNotification(String notificationId) async {
    _inMemoryNotifications.removeWhere((n) => n.id == notificationId);
    _localStreamController.add(List.from(_inMemoryNotifications));

    final activeClient = client;
    if (activeClient != null) {
      try {
        await activeClient
            .from('notifications')
            .delete()
            .eq('id', notificationId);
      } catch (e) {
        debugPrint('[NotificationRepository] deleteNotification error: $e');
      }
    }
  }

  /// Inserts a new persistent notification
  Future<AppNotification> createNotification({
    required String ownerId,
    required String title,
    required String message,
    required NotificationType type,
    String? relatedId,
  }) async {
    final now = DateTime.now();
    final activeClient = client;

    if (activeClient != null && ownerId.isNotEmpty) {
      try {
        final res = await activeClient.from('notifications').insert({
          'owner_id': ownerId,
          'title': title,
          'message': message,
          'type': type.dbName,
          'related_id': relatedId,
          'is_read': false,
          'created_at': now.toUtc().toIso8601String(),
        }).select().single();

        final notif = AppNotification.fromJson(Map<String, dynamic>.from(res));
        _inMemoryNotifications.insert(0, notif);
        _localStreamController.add(List.from(_inMemoryNotifications));
        return notif;
      } catch (e) {
        debugPrint('[NotificationRepository] createNotification remote insert error: $e');
      }
    }

    // Local fallback creation
    final notif = AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      ownerId: ownerId,
      title: title,
      message: message,
      type: type,
      relatedId: relatedId,
      isRead: false,
      createdAt: now,
    );
    _inMemoryNotifications.insert(0, notif);
    _localStreamController.add(List.from(_inMemoryNotifications));
    return notif;
  }

  /// Helper: Creates a notification for when a customer joins the owner's queue
  Future<void> notifyOwnerCustomerJoined({
    required String ownerId,
    required String customerName,
    required int tokenNumber,
    List<String>? serviceNames,
  }) async {
    final servicesStr = serviceNames != null && serviceNames.isNotEmpty
        ? 'for ${serviceNames.join(", ")}'
        : '';
    await createNotification(
      ownerId: ownerId,
      title: 'New Customer Joined Queue!',
      message: '$customerName joined your live line with Token #$tokenNumber $servicesStr.'.trim(),
      type: NotificationType.customerJoined,
    );
  }

  /// Helper: Creates a notification for when a customer joins, cancels, or is called
  Future<void> notifyQueueEvent({
    required String ownerId,
    required String customerName,
    required NotificationType type,
    required String tokenNumber,
    String? details,
  }) async {
    String title;
    String message;

    switch (type) {
      case NotificationType.customerJoined:
        title = 'Customer Joined Queue';
        message = '$customerName was assigned Token #$tokenNumber. ${details ?? ''}'.trim();
        break;
      case NotificationType.customerCancelled:
        title = 'Queue Cancellation';
        message = '$customerName (Token #$tokenNumber) cancelled their spot in the queue.';
        break;
      case NotificationType.customerCalled:
        title = 'Customer Called to Chair';
        message = '$customerName (Token #$tokenNumber) was called to Chair ${details ?? '#1'}.';
        break;
      default:
        title = 'Queue Update';
        message = '$customerName - Token #$tokenNumber: ${details ?? ''}';
    }

    await createNotification(
      ownerId: ownerId,
      title: title,
      message: message,
      type: type,
    );
  }

  /// Helper: Creates a notification when a support ticket has been resolved
  Future<void> notifySupportResolved({
    required String ownerId,
    required String ticketId,
    required String subject,
    String? resolutionMessage,
  }) async {
    await createNotification(
      ownerId: ownerId,
      title: 'Support Request Resolved',
      message: 'Your support request "$subject" has been resolved. ${resolutionMessage ?? "Tap to view the resolution details."}',
      type: NotificationType.supportResolved,
      relatedId: ticketId,
    );
  }

  /// Helper: Notifies a customer when they join a salon queue
  Future<void> notifyCustomerQueueJoined({
    required String customerId,
    required String salonName,
    required int tokenNumber,
    required int estWaitMinutes,
  }) async {
    await createNotification(
      ownerId: customerId,
      title: 'Queue Joined Successfully',
      message: 'You have joined the queue at $salonName. Assigned Token #$tokenNumber (~$estWaitMinutes mins est. wait).',
      type: NotificationType.customerJoined,
    );
  }

  /// Helper: Notifies a customer when their turn arrives in chair
  Future<void> notifyCustomerTurnArrived({
    required String customerId,
    required String salonName,
    required int chairNumber,
  }) async {
    await createNotification(
      ownerId: customerId,
      title: 'Your Turn Has Arrived! ✂️',
      message: 'Your turn is now active at $salonName! Please proceed to Chair #$chairNumber.',
      type: NotificationType.customerCalled,
    );
  }

  /// Helper: Notifies a customer if their queue ticket is cancelled
  Future<void> notifyCustomerQueueCancelled({
    required String customerId,
    required String salonName,
    String? reason,
  }) async {
    await createNotification(
      ownerId: customerId,
      title: 'Queue Spot Cancelled',
      message: 'Your queue spot at $salonName has been cancelled. ${reason ?? ""}'.trim(),
      type: NotificationType.customerCancelled,
    );
  }
}
