import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/config/app_config.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon_service.dart';
import '../../notifications/data/notification_repository.dart';

/// Data repository managing live queue tickets, digital tokens, and owner queue actions.
class QueueRepository {
  // ignore: prefer_initializing_formals
  QueueRepository({supabase.SupabaseClient? client}) : _client = client;

  final supabase.SupabaseClient? _client;
  final NotificationRepository _notifRepo = NotificationRepository();
  static final HttpClient _directHttpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..badCertificateCallback = ((_, __, ___) => true);

  supabase.SupabaseClient? get client {
    if (_client != null) return _client;
    try {
      return supabase.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static final StreamController<List<QueueTicket>> _localQueueStreamController =
      StreamController<List<QueueTicket>>.broadcast();

  /// Clears in-memory ticket cache on user logout
  static void clearLocalCache() {
    _inMemoryTickets.removeWhere((t) => !t.id.startsWith('t-demo-'));
  }

  // Local fallback storage for offline testing / demo
  static final List<QueueTicket> _inMemoryTickets = [
    QueueTicket(
      id: 't-demo-1',
      salonId: '11111111-1111-1111-1111-111111111111',
      customerName: 'Rahul Sharma',
      customerPhone: '+91 98765 11223',
      serviceNames: ['Classic Haircut'],
      totalPrice: 150,
      totalDurationMinutes: 25,
      tokenNumber: 1,
      status: QueueStatus.inChair,
      chairNumber: 1,
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      completedAt: null,
    ),
    QueueTicket(
      id: 't-demo-2',
      salonId: '11111111-1111-1111-1111-111111111111',
      customerName: 'Amit Verma',
      customerPhone: '+91 98222 33445',
      serviceNames: ['Gold Glow Facial', 'Beard Trim & Shape'],
      totalPrice: 530,
      totalDurationMinutes: 50,
      tokenNumber: 2,
      status: QueueStatus.waiting,
      chairNumber: null,
      createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      startedAt: null,
      completedAt: null,
    ),
  ];

  /// Customers join live queue and get assigned a digital token
  Future<QueueTicket> joinQueue({
    required String salonId,
    required String? customerId,
    required String customerName,
    String? customerPhone,
    required List<SalonService> selectedServices,
    String? notes,
  }) async {
    final client = this.client;
    final totalPrice = selectedServices.fold<double>(0.0, (sum, s) => sum + s.price);
    final totalDuration = selectedServices.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final serviceNames = selectedServices.map((s) => s.name).toList();

    if (client == null) {
      final nextToken = _inMemoryTickets.where((t) => t.salonId == salonId).length + 1;
      final ticket = QueueTicket(
        id: 't-local-${DateTime.now().millisecondsSinceEpoch}',
        salonId: salonId,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        serviceNames: serviceNames,
        totalPrice: totalPrice,
        totalDurationMinutes: totalDuration > 0 ? totalDuration : 20,
        tokenNumber: nextToken,
        status: QueueStatus.waiting,
        notes: notes,
        createdAt: DateTime.now(),
        startedAt: null,
        completedAt: null,
      );
      _inMemoryTickets.add(ticket);
      _notifyLocalStream(salonId);
      return ticket;
    }

    try {
      // Get highest token number today
      final existing = await client
          .from('queue_tickets')
          .select('token_number')
          .eq('salon_id', salonId)
          .order('token_number', ascending: false)
          .limit(1);

      int nextToken = 1;
      if ((existing as List).isNotEmpty) {
        nextToken = ((existing.first['token_number'] as int?) ?? 0) + 1;
      }

      final payload = {
        'salon_id': salonId,
        'customer_id': ?customerId,
        'customer_name': customerName,
        'customer_phone': ?customerPhone,
        'service_names': serviceNames,
        'total_price': totalPrice,
        'total_duration_minutes': totalDuration > 0 ? totalDuration : 20,
        'token_number': nextToken,
        'status': 'WAITING',
        'notes': ?notes,
      };

      final response = await client.from('queue_tickets').insert(payload).select().single();
      final ticket = QueueTicket.fromJson(Map<String, dynamic>.from(response));

      if (customerId != null && customerId.isNotEmpty) {
        _notifRepo.notifyCustomerQueueJoined(
          customerId: customerId,
          salonName: 'SalonQueue Salon',
          tokenNumber: ticket.tokenNumber,
          estWaitMinutes: ticket.totalDurationMinutes,
        );
      }

      return ticket;
    } catch (e) {
      debugPrint('[QueueRepository] joinQueue error: $e. Using local storage.');
      final nextToken = _inMemoryTickets.where((t) => t.salonId == salonId).length + 1;
      final ticket = QueueTicket(
        id: 't-local-${DateTime.now().millisecondsSinceEpoch}',
        salonId: salonId,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        serviceNames: serviceNames,
        totalPrice: totalPrice,
        totalDurationMinutes: totalDuration > 0 ? totalDuration : 20,
        tokenNumber: nextToken,
        status: QueueStatus.waiting,
        notes: notes,
        createdAt: DateTime.now(),
        startedAt: null,
        completedAt: null,
      );
      _inMemoryTickets.add(ticket);
      _notifyLocalStream(salonId);

      if (customerId != null && customerId.isNotEmpty) {
        _notifRepo.notifyCustomerQueueJoined(
          customerId: customerId,
          salonName: 'SalonQueue Salon',
          tokenNumber: ticket.tokenNumber,
          estWaitMinutes: ticket.totalDurationMinutes,
        );
      }

      return ticket;
    }
  }

  /// Fetches the currently active waiting/in-chair ticket for a customer
  Future<QueueTicket?> fetchActiveTicketForCustomer(String customerId) async {
    final client = this.client;
    if (client == null) {
      try {
        return _inMemoryTickets.firstWhere(
          (t) => (t.customerId == customerId || t.customerId == null) &&
                 (t.status == QueueStatus.waiting || t.status == QueueStatus.inChair),
        );
      } catch (_) {
        return null;
      }
    }

    try {
      final res = await client
          .from('queue_tickets')
          .select()
          .eq('customer_id', customerId)
          .inFilter('status', ['WAITING', 'IN_CHAIR'])
          .order('created_at', ascending: false)
          .maybeSingle();

      if (res == null) return null;
      return QueueTicket.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      if (AppConfig.isSupabaseConfigured) {
        try {
          final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/queue_tickets?customer_id=eq.$customerId&status=in.(WAITING,IN_CHAIR)&order=created_at.desc&limit=1');
          final req = await _directHttpClient.getUrl(uri).timeout(const Duration(seconds: 4));
          req.headers.set('apikey', AppConfig.supabaseAnonKey);
          req.headers.set('Authorization', 'Bearer ${AppConfig.supabaseAnonKey}');
          req.headers.set('Accept', 'application/json');
          final res = await req.close().timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final body = await res.transform(utf8.decoder).join();
            final list = jsonDecode(body) as List<dynamic>;
            if (list.isNotEmpty) {
              return QueueTicket.fromJson(Map<String, dynamic>.from(list.first as Map));
            }
          }
        } catch (_) {}
      }

      try {
        return _inMemoryTickets.firstWhere(
          (t) => (t.customerId == customerId || t.customerId == null) &&
                 (t.status == QueueStatus.waiting || t.status == QueueStatus.inChair),
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Alias for fetchActiveTicketForCustomer
  Future<QueueTicket?> getActiveTicketForCustomer(String customerId) =>
      fetchActiveTicketForCustomer(customerId);

  /// Real-time live stream for a customer's active queue ticket
  Stream<QueueTicket?> streamActiveTicketForCustomer(String customerId) {
    final client = this.client;
    if (client == null) {
      return Stream.periodic(const Duration(seconds: 2), (_) {
        try {
          return _inMemoryTickets.firstWhere(
            (t) => (t.customerId == customerId || t.customerId == null) &&
                   (t.status == QueueStatus.waiting || t.status == QueueStatus.inChair),
          );
        } catch (_) {
          return null;
        }
      });
    }

    try {
      return client
          .from('queue_tickets')
          .stream(primaryKey: ['id'])
          .eq('customer_id', customerId)
          .map((rows) {
            final active = rows.where((r) {
              final status = r['status'] as String?;
              return status == 'WAITING' || status == 'IN_CHAIR';
            }).toList();
            if (active.isEmpty) return null;
            return QueueTicket.fromJson(Map<String, dynamic>.from(active.first));
          })
          .handleError((error) {
            debugPrint('[QueueRepository] streamActiveTicketForCustomer stream error: $error');
            return null;
          });
    } catch (e) {
      debugPrint('[QueueRepository] streamActiveTicketForCustomer fallback: $e');
      return Stream.fromFuture(fetchActiveTicketForCustomer(customerId));
    }
  }

  /// Fetches all active queue tickets for a salon (for Salon Owner Command Center)
  Future<List<QueueTicket>> fetchLiveQueueForSalon(String salonId) async {
    final client = this.client;
    if (client == null) {
      return _inMemoryTickets.where((t) => t.salonId == salonId).toList();
    }

    try {
      final res = await client
          .from('queue_tickets')
          .select()
          .eq('salon_id', salonId)
          .inFilter('status', ['WAITING', 'IN_CHAIR'])
          .order('token_number', ascending: true);

      final list = (res as List)
          .map((r) => QueueTicket.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();

      if (list.isEmpty) {
        return _inMemoryTickets.where((t) => t.salonId == salonId).toList();
      }
      return list;
    } catch (e) {
      debugPrint('[QueueRepository] fetchLiveQueueForSalon error: $e');
      return _inMemoryTickets.where((t) => t.salonId == salonId).toList();
    }
  }

  /// Real-time stream of all queue tickets for a salon (Owner Live Command Board)
  Stream<List<QueueTicket>> streamLiveQueueForSalon(String salonId) {
    final client = this.client;
    if (client == null) {
      return _localQueueStreamController.stream
          .map((all) => all.where((t) => t.salonId == salonId).toList());
    }

    try {
      return client
          .from('queue_tickets')
          .stream(primaryKey: ['id'])
          .eq('salon_id', salonId)
          .map((rows) {
            return rows
                .where((r) => r['status'] == 'WAITING' || r['status'] == 'IN_CHAIR')
                .map((r) => QueueTicket.fromJson(Map<String, dynamic>.from(r)))
                .toList()
              ..sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber));
          })
          .handleError((error) {
            debugPrint('[QueueRepository] streamLiveQueueForSalon stream error: $error');
            return <QueueTicket>[];
          });
    } catch (e) {
      debugPrint('[QueueRepository] streamLiveQueueForSalon fallback: $e');
      return Stream.periodic(const Duration(seconds: 3), (_) => fetchLiveQueueForSalon(salonId))
          .asyncMap((event) => event);
    }
  }

  /// Updates status of a ticket (Call Next / In Chair, Completed, Cancelled, Skipped)
  Future<void> updateTicketStatus({
    required String ticketId,
    required QueueStatus status,
    int? chairNumber,
  }) async {
    final client = this.client;
    String? customerId;

    // Update in-memory
    final idx = _inMemoryTickets.indexWhere((t) => t.id == ticketId);
    if (idx != -1) {
      customerId = _inMemoryTickets[idx].customerId;
      _inMemoryTickets[idx] = _inMemoryTickets[idx].copyWith(
        status: status,
        chairNumber: chairNumber,
        startedAt: status == QueueStatus.inChair ? DateTime.now() : _inMemoryTickets[idx].startedAt,
        completedAt: status == QueueStatus.completed ? DateTime.now() : null,
      );
      _notifyLocalStream(_inMemoryTickets[idx].salonId);
    }

    if (customerId != null && customerId.isNotEmpty) {
      if (status == QueueStatus.inChair) {
        _notifRepo.notifyCustomerTurnArrived(
          customerId: customerId,
          salonName: 'Royal Cuts & Grooming',
          chairNumber: chairNumber ?? 1,
        );
      } else if (status == QueueStatus.cancelled) {
        _notifRepo.notifyCustomerQueueCancelled(
          customerId: customerId,
          salonName: 'Royal Cuts & Grooming',
        );
      }
    }

    if (client == null) return;

    try {
      final Map<String, dynamic> updateData = {
        'status': status.dbName,
        'chair_number': ?chairNumber,
        if (status == QueueStatus.inChair) 'started_at': DateTime.now().toIso8601String(),
        if (status == QueueStatus.completed) 'completed_at': DateTime.now().toIso8601String(),
      };

      await client.from('queue_tickets').update(updateData).eq('id', ticketId);
    } catch (e) {
      debugPrint('[QueueRepository] updateTicketStatus error: $e');
    }
  }

  /// Cancels a queue ticket
  Future<void> cancelTicket(String ticketId) async {
    await updateTicketStatus(ticketId: ticketId, status: QueueStatus.cancelled);
  }

  /// Fetches past booking and completed/cancelled visits for a customer
  Future<List<QueueTicket>> fetchCustomerHistory(String customerId) async {
    final client = this.client;
    if (client == null) {
      return _inMemoryTickets.where((t) => t.customerId == customerId).toList();
    }

    try {
      final res = await client
          .from('queue_tickets')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (res as List)
          .map((r) => QueueTicket.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      if (AppConfig.isSupabaseConfigured) {
        try {
          final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/queue_tickets?customer_id=eq.$customerId&order=created_at.desc');
          final req = await _directHttpClient.getUrl(uri).timeout(const Duration(seconds: 4));
          req.headers.set('apikey', AppConfig.supabaseAnonKey);
          req.headers.set('Authorization', 'Bearer ${AppConfig.supabaseAnonKey}');
          req.headers.set('Accept', 'application/json');
          final res = await req.close().timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final body = await res.transform(utf8.decoder).join();
            final list = jsonDecode(body) as List<dynamic>;
            return list
                .map((r) => QueueTicket.fromJson(Map<String, dynamic>.from(r as Map)))
                .toList();
          }
        } catch (_) {}
      }
      return _inMemoryTickets.where((t) => t.customerId == customerId).toList();
    }
  }

  static void _notifyLocalStream(String salonId) {
    _localQueueStreamController.add(List.from(_inMemoryTickets));
  }
}
