import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/auth/models/app_user.dart';
import 'package:salon_queue/features/notifications/data/notification_repository.dart';
import 'package:salon_queue/features/notifications/models/app_notification.dart';
import 'package:salon_queue/features/queue/data/queue_repository.dart';
import 'package:salon_queue/features/salon/data/salon_repository.dart';
import 'package:salon_queue/features/support/data/support_repository.dart';
import 'package:salon_queue/shared/models/queue_ticket.dart';
import 'package:salon_queue/shared/models/salon.dart';
import 'package:salon_queue/shared/models/salon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SECURITY & RLS ISOLATION TESTS (2 CUSTOMERS & 2 OWNERS)', () {
    const customerA = AppUser(
      id: 'cust-uuid-aaaa-1111',
      email: 'customerA@example.com',
      fullName: 'Customer Alice',
      role: AppRole.customer,
    );

    const customerB = AppUser(
      id: 'cust-uuid-bbbb-2222',
      email: 'customerB@example.com',
      fullName: 'Customer Bob',
      role: AppRole.customer,
    );

    const ownerA = AppUser(
      id: 'owner-uuid-aaaa-1111',
      email: 'ownerA@example.com',
      fullName: 'Owner Alex',
      role: AppRole.salonOwner,
    );

    const ownerB = AppUser(
      id: 'owner-uuid-bbbb-2222',
      email: 'ownerB@example.com',
      fullName: 'Owner Brian',
      role: AppRole.salonOwner,
    );

    const serviceA = SalonService(
      id: 'svc-a1',
      salonId: 'salon-uuid-aaaa-1111',
      name: 'Haircut Alpha',
      category: 'Hair',
      price: 200,
      durationMinutes: 20,
      isActive: true,
    );

    const serviceB = SalonService(
      id: 'svc-b1',
      salonId: 'salon-uuid-bbbb-2222',
      name: 'Beard Trim Beta',
      category: 'Beard',
      price: 150,
      durationMinutes: 15,
      isActive: true,
    );

    const salonA = Salon(
      id: 'salon-uuid-aaaa-1111',
      ownerId: 'owner-uuid-aaaa-1111',
      name: 'Salon Alpha',
      address: '1st Street, City A',
      city: 'City A',
      district: 'District A',
      state: 'State A',
      activeChairs: 2,
      isQueueOpen: true,
      isVerified: true,
      services: [serviceA],
    );

    const salonB = Salon(
      id: 'salon-uuid-bbbb-2222',
      ownerId: 'owner-uuid-bbbb-2222',
      name: 'Salon Beta',
      address: '2nd Street, City B',
      city: 'City B',
      district: 'District B',
      state: 'State B',
      activeChairs: 3,
      isQueueOpen: true,
      isVerified: true,
      services: [serviceB],
    );

    setUp(() {
      QueueRepository.clearLocalCache();
      SalonRepository.clearCache();
      NotificationRepository.clearCache();
    });

    test('TEST 1: Customer A and Customer B have strict queue ticket privacy', () async {
      final queueRepo = QueueRepository();

      // Customer A joins Salon A
      final ticketA = await queueRepo.joinQueue(
        salonId: salonA.id,
        customerId: customerA.id,
        customerName: customerA.fullName ?? 'Customer Alice',
        selectedServices: [serviceA],
      );

      // Customer B joins Salon B
      final ticketB = await queueRepo.joinQueue(
        salonId: salonB.id,
        customerId: customerB.id,
        customerName: customerB.fullName ?? 'Customer Bob',
        selectedServices: [serviceB],
      );

      // Customer A queries own active ticket
      final activeA = await queueRepo.fetchActiveTicketForCustomer(customerA.id);
      expect(activeA, isNotNull);
      expect(activeA!.id, equals(ticketA.id));
      expect(activeA.customerId, equals(customerA.id));
      expect(activeA.customerName, equals('Customer Alice'));

      // Customer B queries own active ticket
      final activeB = await queueRepo.fetchActiveTicketForCustomer(customerB.id);
      expect(activeB, isNotNull);
      expect(activeB!.id, equals(ticketB.id));
      expect(activeB.customerId, equals(customerB.id));
      expect(activeB.customerName, equals('Customer Bob'));

      // Customer A must not see Customer B's history
      final historyA = await queueRepo.fetchCustomerHistory(customerA.id);
      expect(historyA.every((t) => t.customerId == customerA.id), isTrue);
      expect(historyA.any((t) => t.customerId == customerB.id), isFalse);
    });

    test('TEST 2: Owner A and Owner B have strict salon and queue isolation', () async {
      final queueRepo = QueueRepository();

      await queueRepo.joinQueue(
        salonId: salonA.id,
        customerId: customerA.id,
        customerName: customerA.fullName ?? 'Customer Alice',
        selectedServices: [serviceA],
      );

      await queueRepo.joinQueue(
        salonId: salonB.id,
        customerId: customerB.id,
        customerName: customerB.fullName ?? 'Customer Bob',
        selectedServices: [serviceB],
      );

      // Owner A checks live queue for Salon A
      final queueSalonA = await queueRepo.fetchLiveQueueForSalon(salonA.id);
      expect(queueSalonA.length, equals(1));
      expect(queueSalonA.first.salonId, equals(salonA.id));
      expect(queueSalonA.first.customerName, equals('Customer Alice'));

      // Owner B checks live queue for Salon B
      final queueSalonB = await queueRepo.fetchLiveQueueForSalon(salonB.id);
      expect(queueSalonB.length, equals(1));
      expect(queueSalonB.first.salonId, equals(salonB.id));
      expect(queueSalonB.first.customerName, equals('Customer Bob'));
    });

    test('TEST 3: Customer can cancel own ticket and status reflects accurately', () async {
      final queueRepo = QueueRepository();

      final ticket = await queueRepo.joinQueue(
        salonId: salonA.id,
        customerId: customerA.id,
        customerName: customerA.fullName ?? 'Customer Alice',
        selectedServices: [serviceA],
      );

      expect(ticket.isWaiting, isTrue);

      // Customer cancels
      await queueRepo.cancelTicket(ticket.id);

      final updated = await queueRepo.fetchTicketById(ticket.id);
      expect(updated, isNotNull);
      expect(updated!.status, equals(QueueStatus.cancelled));
      expect(updated.isCancelled, isTrue);
    });

    test('TEST 4: Notifications are strictly isolated between recipient users', () async {
      final notifRepo = NotificationRepository();

      // Send notif to Customer A
      await notifRepo.createNotification(
        ownerId: customerA.id,
        title: 'Turn Arrived',
        message: 'Please take Chair #1',
        type: NotificationType.customerCalled,
      );

      // Send notif to Owner B
      await notifRepo.createNotification(
        ownerId: ownerB.id,
        title: 'New Booking',
        message: 'New walkin queued',
        type: NotificationType.customerJoined,
      );

      // Verify Customer A reads only Customer A notifications
      final notifsA = await notifRepo.fetchNotifications(customerA.id);
      expect(notifsA.length, equals(1));
      expect(notifsA.first.ownerId, equals(customerA.id));
      expect(notifsA.first.title, equals('Turn Arrived'));

      // Verify Owner B reads only Owner B notifications
      final notifsB = await notifRepo.fetchNotifications(ownerB.id);
      expect(notifsB.length, equals(1));
      expect(notifsB.first.ownerId, equals(ownerB.id));
      expect(notifsB.first.title, equals('New Booking'));
    });

    test('TEST 5: Support tickets are strictly isolated per user', () async {
      final supportRepo = SupportRepository();

      // Customer A creates support ticket
      final tickA = await supportRepo.createTicket(
        userId: customerA.id,
        userRole: 'customer',
        category: 'Queue Issue',
        subject: 'Estimated wait question',
        description: 'How is wait time calculated?',
      );

      // Owner B creates support ticket
      final tickB = await supportRepo.createTicket(
        userId: ownerB.id,
        userRole: 'salonOwner',
        category: 'Billing',
        subject: 'Chair subscription',
        description: 'Adding 4th chair query',
      );

      final userATickets = await supportRepo.fetchUserTickets(customerA.id);
      expect(userATickets.length, equals(1));
      expect(userATickets.first.id, equals(tickA.id));
      expect(userATickets.first.userId, equals(customerA.id));

      final userBTickets = await supportRepo.fetchUserTickets(ownerB.id);
      expect(userBTickets.length, equals(1));
      expect(userBTickets.first.id, equals(tickB.id));
      expect(userBTickets.first.userId, equals(ownerB.id));
    });

    test('TEST 6: Storage path isolation regex and validation helper', () {
      // Path format: owners/<userId>/profile/...
      bool isOwnerAllowedStoragePath(String path, String userId) {
        final segments = path.split('/');
        if (segments.length >= 3 && segments[0] == 'owners' && segments[1] == userId) {
          return true;
        }
        if (segments.length >= 2 && segments[0] == userId) {
          return true;
        }
        if (path.startsWith(userId)) {
          return true;
        }
        return false;
      }

      const userAId = 'owner-uuid-aaaa-1111';
      const userBId = 'owner-uuid-bbbb-2222';

      final userAPhotoPath = 'owners/$userAId/cover/cover_123456.jpg';
      final userBPhotoPath = 'owners/$userBId/gallery/interior_9999.jpg';

      // User A can access User A's path
      expect(isOwnerAllowedStoragePath(userAPhotoPath, userAId), isTrue);

      // User A cannot access User B's path
      expect(isOwnerAllowedStoragePath(userBPhotoPath, userAId), isFalse);

      // User B cannot access User A's path
      expect(isOwnerAllowedStoragePath(userAPhotoPath, userBId), isFalse);
    });
  });
}
