import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/support/data/faq_data.dart';
import 'package:salon_queue/features/support/data/support_repository.dart';
import 'package:salon_queue/features/support/models/support_ticket.dart';

void main() {
  group('Help & Support Feature Tests', () {
    late SupportRepository supportRepo;

    setUp(() {
      supportRepo = SupportRepository();
    });

    test('Customer FAQs contain all key categories & answers', () {
      final faqs = FaqData.customerFaqs;
      expect(faqs, isNotEmpty);

      final categories = faqs.map((f) => f.category).toSet();
      expect(categories, contains('Joining a Queue'));
      expect(categories, contains('QR Code'));
      expect(categories, contains('Bookings & Queue'));
      expect(categories, contains('Account'));
      expect(categories, contains('Notifications'));
      expect(categories, contains('Payments'));

      for (final faq in faqs) {
        expect(faq.question, isNotEmpty);
        expect(faq.answer, isNotEmpty);
        expect(faq.isCustomer, isTrue);
      }
    });

    test('Owner FAQs contain all key queue management & profile categories', () {
      final faqs = FaqData.ownerFaqs;
      expect(faqs, isNotEmpty);

      final categories = faqs.map((f) => f.category).toSet();
      expect(categories, contains('Queue Management'));
      expect(categories, contains('Salon Profile'));
      expect(categories, contains('Salon QR Code'));
      expect(categories, contains('Business Analytics'));
      expect(categories, contains('Account & Security'));

      for (final faq in faqs) {
        expect(faq.question, isNotEmpty);
        expect(faq.answer, isNotEmpty);
        expect(faq.isOwner, isTrue);
      }
    });

    test('Create support ticket saves and retrieves user ticket', () async {
      const testUserId = 'test-user-123';
      final created = await supportRepo.createTicket(
        userId: testUserId,
        userRole: 'customer',
        category: 'Joining a Queue',
        subject: 'Cannot see live queue wait time',
        description: 'Wait time badge is taking a few seconds to load.',
        screenshotUrl: 'https://example.com/shot.png',
      );

      expect(created.id, isNotEmpty);
      expect(created.userId, testUserId);
      expect(created.subject, 'Cannot see live queue wait time');
      expect(created.status, SupportTicketStatus.open);
      expect(created.formattedTicketId, startsWith('#TICK-'));

      final tickets = await supportRepo.fetchUserTickets(testUserId);
      expect(tickets, isNotEmpty);
      expect(tickets.any((t) => t.id == created.id), isTrue);
    });

    test('SupportTicket JSON serialization and status mapping', () {
      final now = DateTime.now();
      final ticket = SupportTicket(
        id: 'tick-999',
        userId: 'u1',
        userRole: 'salon_owner',
        category: 'Technical Issue',
        subject: 'Standee QR printing inquiry',
        description: 'How do I download high res standee?',
        status: SupportTicketStatus.inProgress,
        createdAt: now,
        updatedAt: now,
        adminResponse: 'You can use the Print button directly.',
      );

      final json = ticket.toJson();
      expect(json['id'], 'tick-999');
      expect(json['status'], 'inProgress');

      final reconstructed = SupportTicket.fromJson(json);
      expect(reconstructed.id, ticket.id);
      expect(reconstructed.status, SupportTicketStatus.inProgress);
      expect(reconstructed.adminResponse, ticket.adminResponse);
    });
  });
}
