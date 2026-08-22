import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/queue/data/queue_repository.dart';
import 'package:salon_queue/shared/models/salon_service.dart';
import 'package:salon_queue/shared/models/queue_ticket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    QueueRepository.clearLocalCache();
  });

  group('Atomic Token Allocation & Concurrent Safety Tests', () {
    const service1 = SalonService(
      id: 'svc-1',
      salonId: 'salon-1',
      name: 'Haircut',
      category: 'Hair',
      price: 150.0,
      durationMinutes: 20,
    );

    const service2 = SalonService(
      id: 'svc-2',
      salonId: 'salon-1',
      name: 'Beard Trim',
      category: 'Beard',
      price: 100.0,
      durationMinutes: 15,
    );

    test(
      'Single customer joining receives token #1 and preserves all service data',
      () async {
        final queueRepo = QueueRepository();

        final ticket = await queueRepo.joinQueue(
          salonId: 'salon-1',
          customerId: 'customer-1',
          customerName: 'Aakash Panda',
          customerPhone: '+91 98765 43210',
          selectedServices: [service1, service2],
          notes: 'Please keep sides short',
        );

        expect(ticket.tokenNumber, equals(1));
        expect(ticket.totalPrice, equals(250.0));
        expect(ticket.totalDurationMinutes, equals(35));
        expect(ticket.serviceNames, containsAll(['Haircut', 'Beard Trim']));
        expect(ticket.notes, equals('Please keep sides short'));
        expect(ticket.status, equals(QueueStatus.waiting));
        expect(ticket.formattedToken, equals('#A-01'));
      },
    );

    test(
      'Sequential joins to the same salon receive strictly incrementing tokens',
      () async {
        final queueRepo = QueueRepository();

        final t1 = await queueRepo.joinQueue(
          salonId: 'salon-seq-1',
          customerId: 'c1',
          customerName: 'Customer 1',
          selectedServices: [service1],
        );

        final t2 = await queueRepo.joinQueue(
          salonId: 'salon-seq-1',
          customerId: 'c2',
          customerName: 'Customer 2',
          selectedServices: [service1],
        );

        final t3 = await queueRepo.joinQueue(
          salonId: 'salon-seq-1',
          customerId: 'c3',
          customerName: 'Customer 3',
          selectedServices: [service1],
        );

        expect(t1.tokenNumber, equals(1));
        expect(t2.tokenNumber, equals(2));
        expect(t3.tokenNumber, equals(3));
      },
    );

    test(
      'Simultaneous / concurrent joins to the same salon never produce duplicate tokens',
      () async {
        final queueRepo = QueueRepository();
        const salonId = 'salon-concurrent-test';
        const count = 20;

        // Simulate 20 concurrent customer joins triggered at the exact same moment
        final futures = List.generate(count, (i) {
          return queueRepo.joinQueue(
            salonId: salonId,
            customerId: 'concurrent-cust-$i',
            customerName: 'Customer $i',
            selectedServices: [service1],
          );
        });

        final tickets = await Future.wait(futures);

        // Verify all tickets received tokens
        expect(tickets.length, equals(count));

        // Collect all assigned token numbers
        final assignedTokens = tickets.map((t) => t.tokenNumber).toList();
        final uniqueTokens = assignedTokens.toSet();

        // Zero duplicate tokens: Unique count must equal total tickets count
        expect(
          uniqueTokens.length,
          equals(count),
          reason: 'All concurrent tokens must be unique',
        );

        // Tokens must span from 1 to count
        final sortedTokens = List<int>.from(assignedTokens)..sort();
        expect(sortedTokens.first, equals(1));
        expect(sortedTokens.last, equals(count));
      },
    );

    test('Token allocation is strictly scoped per salon', () async {
      final queueRepo = QueueRepository();

      // Salon Alpha joins
      final alpha1 = await queueRepo.joinQueue(
        salonId: 'salon-alpha',
        customerId: 'cust-a1',
        customerName: 'Alice',
        selectedServices: [service1],
      );

      final alpha2 = await queueRepo.joinQueue(
        salonId: 'salon-alpha',
        customerId: 'cust-a2',
        customerName: 'Adam',
        selectedServices: [service1],
      );

      // Salon Beta joins independently
      final beta1 = await queueRepo.joinQueue(
        salonId: 'salon-beta',
        customerId: 'cust-b1',
        customerName: 'Bob',
        selectedServices: [service1],
      );

      final beta2 = await queueRepo.joinQueue(
        salonId: 'salon-beta',
        customerId: 'cust-b2',
        customerName: 'Bella',
        selectedServices: [service1],
      );

      // Alpha has its own 1, 2 sequence
      expect(alpha1.tokenNumber, equals(1));
      expect(alpha2.tokenNumber, equals(2));

      // Beta has its own 1, 2 sequence
      expect(beta1.tokenNumber, equals(1));
      expect(beta2.tokenNumber, equals(2));
    });

    test(
      'Owner walk-in customer creation (null customerId) receives valid token',
      () async {
        final queueRepo = QueueRepository();

        final walkinTicket = await queueRepo.joinQueue(
          salonId: 'salon-walkin',
          customerId: null,
          customerName: 'Walk-in Guest',
          customerPhone: '+91 99887 76655',
          selectedServices: [service1],
        );

        expect(walkinTicket.tokenNumber, equals(1));
        expect(walkinTicket.customerId, isNull);
        expect(walkinTicket.customerName, equals('Walk-in Guest'));
        expect(walkinTicket.status, equals(QueueStatus.waiting));
      },
    );

    test(
      'QueueRepository clearLocalCache resets in-memory sequence counters',
      () async {
        final queueRepo = QueueRepository();

        final t1 = await queueRepo.joinQueue(
          salonId: 'salon-reset-test',
          customerId: 'c1',
          customerName: 'Customer 1',
          selectedServices: [service1],
        );
        expect(t1.tokenNumber, equals(1));

        // Clear cache on logout
        QueueRepository.clearLocalCache();

        // Next join after clear starts cleanly at 1
        final t2 = await queueRepo.joinQueue(
          salonId: 'salon-reset-test',
          customerId: 'c2',
          customerName: 'Customer 2',
          selectedServices: [service1],
        );
        expect(t2.tokenNumber, equals(1));
      },
    );

    test(
      'Customer join passes real non-null customerId and user info',
      () async {
        final queueRepo = QueueRepository();
        const realCustomerId = 'usr-uuid-real-authenticated-777';

        final ticket = await queueRepo.joinQueue(
          salonId: 'salon-auth-test',
          customerId: realCustomerId,
          customerName: 'Rajesh Sharma',
          customerPhone: '+91 98765 12345',
          selectedServices: [service1],
        );

        expect(ticket.customerId, equals(realCustomerId));
        expect(ticket.customerId, isNotNull);
        expect(ticket.customerId!.isNotEmpty, isTrue);
        expect(ticket.customerName, equals('Rajesh Sharma'));
        expect(ticket.customerPhone, equals('+91 98765 12345'));
      },
    );
  });
}
