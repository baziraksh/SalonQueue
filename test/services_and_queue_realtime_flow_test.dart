import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/salon/data/salon_repository.dart';
import 'package:salon_queue/features/queue/data/queue_repository.dart';
import 'package:salon_queue/shared/models/salon_service.dart';
import 'package:salon_queue/shared/models/queue_ticket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SalonRepository.clearCache();
    SalonRepository.enableDiskPersistence = false;
    QueueRepository.clearLocalCache();
  });

  group('Service CRUD & Realtime Stream Tests', () {
    test('addService creates and returns real service model', () async {
      final salonRepo = SalonRepository();
      const salonId = 'salon-test-service-1';

      final service = await salonRepo.addService(
        salonId: salonId,
        name: 'Classic Haircut',
        category: 'Hair',
        price: 150.0,
        durationMinutes: 25,
        isActive: true,
      );

      expect(service, isNotNull);
      expect(service.name, equals('Classic Haircut'));
      expect(service.price, equals(150.0));
      expect(service.durationMinutes, equals(25));
      expect(service.isActive, isTrue);

      final fetchedServices = await salonRepo.fetchServices(salonId);
      expect(fetchedServices.any((s) => s.name == 'Classic Haircut'), isTrue);
    });

    test('updateService modifies price, duration and active status', () async {
      final salonRepo = SalonRepository();
      const salonId = 'salon-test-service-2';

      final created = await salonRepo.addService(
        salonId: salonId,
        name: 'Beard Trim',
        category: 'Beard',
        price: 80.0,
        durationMinutes: 15,
        isActive: true,
      );

      final updated = await salonRepo.updateService(
        serviceId: created.id,
        name: 'Beard Trim & Styling',
        category: 'Beard',
        price: 120.0,
        durationMinutes: 20,
        isActive: false,
        salonId: salonId,
      );

      expect(updated.name, equals('Beard Trim & Styling'));
      expect(updated.price, equals(120.0));
      expect(updated.durationMinutes, equals(20));
      expect(updated.isActive, isFalse);

      // fetchServices with onlyActive=true should filter out paused service
      final activeOnly = await salonRepo.fetchServices(salonId, onlyActive: true);
      expect(activeOnly.any((s) => s.id == created.id), isFalse);

      // fetchServices without onlyActive should return it
      final allServices = await salonRepo.fetchServices(salonId, onlyActive: false);
      expect(allServices.any((s) => s.id == created.id), isTrue);
    });

    test('deleteService removes service cleanly', () async {
      final salonRepo = SalonRepository();
      const salonId = 'salon-test-service-3';

      final created = await salonRepo.addService(
        salonId: salonId,
        name: 'Hair Spa',
        category: 'Spa',
        price: 350.0,
        durationMinutes: 40,
      );

      await salonRepo.deleteService(created.id, salonId: salonId);

      final services = await salonRepo.fetchServices(salonId);
      expect(services.any((s) => s.id == created.id), isFalse);
    });
  });

  group('Customer Queue Joining & Status Flow Tests', () {
    test('joinQueue calculates total price and duration from real services', () async {
      final queueRepo = QueueRepository();
      const salonId = 'salon-queue-test-1';

      final selectedServices = [
        const SalonService(
          id: 'svc-1',
          salonId: salonId,
          name: 'Classic Haircut',
          category: 'Hair',
          price: 150.0,
          durationMinutes: 25,
        ),
        const SalonService(
          id: 'svc-2',
          salonId: salonId,
          name: 'Beard Trim',
          category: 'Beard',
          price: 100.0,
          durationMinutes: 15,
        ),
      ];

      final ticket = await queueRepo.joinQueue(
        salonId: salonId,
        customerId: 'customer-uuid-123',
        customerName: 'Aakash Panda',
        customerPhone: '+91 98765 43210',
        selectedServices: selectedServices,
      );

      expect(ticket.totalPrice, equals(250.0));
      expect(ticket.totalDurationMinutes, equals(40));
      expect(ticket.serviceNames, containsAll(['Classic Haircut', 'Beard Trim']));
      expect(ticket.status, equals(QueueStatus.waiting));
      expect(ticket.tokenNumber, greaterThanOrEqualTo(1));
    });

    test('updateTicketStatus progresses ticket through full lifecycle', () async {
      final queueRepo = QueueRepository();
      const salonId = 'salon-queue-test-2';

      final ticket = await queueRepo.joinQueue(
        salonId: salonId,
        customerId: 'customer-uuid-456',
        customerName: 'Pritam Ray',
        customerPhone: '+91 99999 88888',
        selectedServices: [
          const SalonService(
            id: 'svc-1',
            salonId: salonId,
            name: 'Royal Shave',
            category: 'Beard',
            price: 120.0,
            durationMinutes: 20,
          ),
        ],
      );

      expect(ticket.status, equals(QueueStatus.waiting));

      // 1. Owner calls customer to chair
      await queueRepo.updateTicketStatus(
        ticketId: ticket.id,
        status: QueueStatus.inChair,
        chairNumber: 2,
      );

      final liveQueue = await queueRepo.fetchLiveQueueForSalon(salonId);
      final inChairTicket = liveQueue.firstWhere((t) => t.id == ticket.id);
      expect(inChairTicket.status, equals(QueueStatus.inChair));
      expect(inChairTicket.chairNumber, equals(2));

      // 2. Owner completes service
      await queueRepo.updateTicketStatus(
        ticketId: ticket.id,
        status: QueueStatus.completed,
      );

      final postCompleteQueue = await queueRepo.fetchLiveQueueForSalon(salonId);
      expect(postCompleteQueue.any((t) => t.id == ticket.id && t.status == QueueStatus.inChair), isFalse);

      final completedTicket = await queueRepo.fetchTicketById(ticket.id);
      expect(completedTicket, isNotNull);
      expect(completedTicket!.status, equals(QueueStatus.completed));
      expect(completedTicket.isCompleted, isTrue);
      expect(completedTicket.completedAt, isNotNull);
    });

    test('streamTicket receives realtime completed state when owner finishes service', () async {
      final queueRepo = QueueRepository();
      const salonId = 'salon-queue-test-3';

      final ticket = await queueRepo.joinQueue(
        salonId: salonId,
        customerId: 'customer-uuid-789',
        customerName: 'Rahul Nayak',
        customerPhone: '+91 91234 56789',
        selectedServices: [
          const SalonService(
            id: 'svc-3',
            salonId: salonId,
            name: 'Hair Wash',
            category: 'Hair',
            price: 70.0,
            durationMinutes: 10,
          ),
        ],
      );

      final streamEvents = <QueueTicket>[];
      final sub = queueRepo.streamTicket(ticket.id).listen((t) {
        if (t != null) streamEvents.add(t);
      });

      // Advance to in chair
      await queueRepo.updateTicketStatus(
        ticketId: ticket.id,
        status: QueueStatus.inChair,
        chairNumber: 1,
      );

      // Advance to completed (Owner clicks Finish)
      await queueRepo.updateTicketStatus(
        ticketId: ticket.id,
        status: QueueStatus.completed,
      );

      await Future.delayed(const Duration(milliseconds: 150));
      await sub.cancel();

      expect(streamEvents.any((t) => t.status == QueueStatus.completed), isTrue);
      final finalEvent = streamEvents.lastWhere((t) => t.status == QueueStatus.completed);
      expect(finalEvent.isCompleted, isTrue);
    });

    test('fetchCompletedTicketsForSalon returns completed tickets and calculates accurate revenue', () async {
      final queueRepo = QueueRepository();
      const salonId = 'salon-analytics-test-1';

      final t1 = await queueRepo.joinQueue(
        salonId: salonId,
        customerId: 'c-1',
        customerName: 'User One',
        selectedServices: [
          const SalonService(id: 's1', salonId: salonId, name: 'Haircut', category: 'Hair', price: 200, durationMinutes: 20),
        ],
      );

      final t2 = await queueRepo.joinQueue(
        salonId: salonId,
        customerId: 'c-2',
        customerName: 'User Two',
        selectedServices: [
          const SalonService(id: 's2', salonId: salonId, name: 'Facial', category: 'Facial', price: 350, durationMinutes: 30),
        ],
      );

      // Complete t1
      await queueRepo.updateTicketStatus(ticketId: t1.id, status: QueueStatus.completed);
      // Put t2 in chair
      await queueRepo.updateTicketStatus(ticketId: t2.id, status: QueueStatus.inChair, chairNumber: 1);

      final completedTickets = await queueRepo.fetchCompletedTicketsForSalon(salonId);
      expect(completedTickets.length, equals(1));
      expect(completedTickets.first.id, equals(t1.id));
      expect(completedTickets.first.totalPrice, equals(200.0));

      // Complete t2 as well
      await queueRepo.updateTicketStatus(ticketId: t2.id, status: QueueStatus.completed);

      final allCompleted = await queueRepo.fetchCompletedTicketsForSalon(salonId);
      expect(allCompleted.length, equals(2));
      final totalRevenue = allCompleted.fold<double>(0.0, (sum, t) => sum + t.totalPrice);
      expect(totalRevenue, equals(550.0));
    });

    test('fetchLatestTicketForCustomer retrieves recent completed ticket for My Queue history', () async {
      final queueRepo = QueueRepository();
      const salonId = 'salon-latest-test-1';
      const customerId = 'customer-history-user-1';

      final ticket = await queueRepo.joinQueue(
        salonId: salonId,
        customerId: customerId,
        customerName: 'Subhashish',
        selectedServices: [
          const SalonService(id: 's1', salonId: salonId, name: 'Beard Trim', category: 'Beard', price: 100, durationMinutes: 15),
        ],
      );

      await queueRepo.updateTicketStatus(ticketId: ticket.id, status: QueueStatus.completed);

      final latest = await queueRepo.fetchLatestTicketForCustomer(customerId);
      expect(latest, isNotNull);
      expect(latest!.id, equals(ticket.id));
      expect(latest.status, equals(QueueStatus.completed));
      expect(latest.isCompleted, isTrue);
    });
  });
}
