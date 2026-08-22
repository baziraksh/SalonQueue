import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/customer/screens/customer_entry_screen.dart';
import 'package:salon_queue/features/customer/screens/easy_booking_screen.dart';
import 'package:salon_queue/features/customer/screens/security_privacy_screen.dart';
import 'package:salon_queue/features/notifications/data/notification_repository.dart';
import 'package:salon_queue/features/notifications/models/app_notification.dart';
import 'package:salon_queue/features/notifications/screens/customer_notifications_screen.dart';
import 'package:salon_queue/features/salon/screens/salon_details_screen.dart';
import 'package:salon_queue/features/support/data/support_repository.dart';
import 'package:salon_queue/features/support/models/support_ticket.dart';
import 'package:salon_queue/shared/models/salon.dart';
import 'package:salon_queue/shared/models/salon_service.dart';
import 'package:salon_queue/shared/widgets/benefit_item.dart';
import 'package:salon_queue/shared/widgets/salon_card.dart';

void main() {
  group('1. Customer Salon Card & Images Tests', () {
    testWidgets(
      'SalonCard renders cover image and verified badge when present',
      (tester) async {
        final verifiedSalon = Salon(
          id: 'salon-v1',
          name: 'Royal Crown Saloon',
          address: 'MG Road',
          city: 'Pune',
          coverImageUrl: 'https://example.com/cover.jpg',
          ownerName: 'Vikram Mehta',
          ownerAvatarUrl: 'https://example.com/owner.jpg',
          isVerified: true,
          galleryImages: [
            'https://example.com/photo1.jpg',
            'https://example.com/photo2.jpg',
          ],
          services: const [
            SalonService(
              id: 's1',
              salonId: 'salon-v1',
              name: 'Haircut',
              category: 'Hair',
              price: 150,
              durationMinutes: 20,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SalonCard(
                salon: verifiedSalon,
                isFavorite: false,
                onFavoriteTap: () {},
                onTap: () {},
                onJoinQueue: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Royal Crown Saloon'), findsAtLeast(1));
        expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
        expect(find.text('2 photos'), findsOneWidget);
        expect(find.text('Vikram Mehta'), findsOneWidget);
        expect(find.text('JOIN QUEUE'), findsOneWidget);
      },
    );

    testWidgets(
      'SalonDetailsScreen displays Owner Card, Verified badge, and Gallery',
      (tester) async {
        final salon = Salon(
          id: 'salon-d1',
          name: 'Elite Grooming Studio',
          address: 'FC Road',
          city: 'Pune',
          ownerName: 'Sameer Khan',
          ownerAvatarUrl: 'https://example.com/sameer.jpg',
          isVerified: true,
          galleryImages: ['https://example.com/g1.jpg'],
          services: const [
            SalonService(
              id: 'srv1',
              salonId: 'salon-d1',
              name: 'Fade Cut',
              category: 'Hair',
              price: 200,
              durationMinutes: 25,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(home: SalonDetailsScreen(salon: salon)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Elite Grooming Studio'), findsAtLeast(1));
        expect(find.text('Sameer Khan'), findsOneWidget);
        expect(find.text('OWNER'), findsOneWidget);
        expect(find.text('Verified Salon Management'), findsOneWidget);
        expect(find.text('Salon Gallery'), findsOneWidget);
      },
    );
  });

  group('2. Customer Notification System Tests', () {
    test(
      'Customer receives notification when joining queue and when called',
      () async {
        final notifRepo = NotificationRepository();
        const customerId = 'cust-test-123';

        await notifRepo.notifyCustomerQueueJoined(
          customerId: customerId,
          salonName: 'Style Studio',
          tokenNumber: 5,
          estWaitMinutes: 25,
        );

        final notifs = await notifRepo.fetchNotifications(customerId);
        expect(
          notifs.any((n) => n.title.contains('Queue Joined Successfully')),
          isTrue,
        );

        await notifRepo.notifyCustomerTurnArrived(
          customerId: customerId,
          salonName: 'Style Studio',
          chairNumber: 2,
        );

        final updatedNotifs = await notifRepo.fetchNotifications(customerId);
        expect(
          updatedNotifs.any((n) => n.title.contains('Your Turn Has Arrived')),
          isTrue,
        );
      },
    );

    testWidgets(
      'CustomerNotificationsScreen renders tabs and notification list',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: CustomerNotificationsScreen(customerId: 'cust-test-123'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Queue'), findsOneWidget);
        expect(find.text('Support'), findsOneWidget);
        expect(find.text('System'), findsOneWidget);
      },
    );
  });

  group('3. Support Query Resolution -> Customer Notification Flow', () {
    test(
      'Support ticket resolution automatically creates customer notification',
      () async {
        final supportRepo = SupportRepository();
        final notifRepo = NotificationRepository();
        const customerId = 'cust-support-user';

        await supportRepo.updateTicketStatus(
          ticketId: 'cust-tick-55',
          status: SupportTicketStatus.resolved,
          ownerId: customerId,
          subject: 'Wait time inquiry',
          adminResponse:
              'The estimated calculation has been adjusted for peak times.',
        );

        final notifs = await notifRepo.fetchNotifications(customerId);
        final resolvedNotif = notifs.firstWhere(
          (n) =>
              n.type == NotificationType.supportResolved &&
              n.relatedId == 'cust-tick-55',
        );
        expect(resolvedNotif.title, equals('Support Request Resolved'));
        expect(resolvedNotif.message, contains('Wait time inquiry'));
      },
    );
  });

  group('4. Four Interactive Feature Cards Tests', () {
    testWidgets('BenefitItem responds to tap events with ripple', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BenefitItem(
              icon: Icons.timer_outlined,
              title: 'Real-time Queue',
              subtitle: 'Live wait times',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Real-time Queue'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets(
      'SecurityPrivacyScreen displays security pillars and account actions',
      (tester) async {
        final authService = AuthService(null);

        await tester.pumpWidget(
          AuthScope(
            service: authService,
            child: const MaterialApp(home: SecurityPrivacyScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Security & Privacy'), findsOneWidget);
        expect(find.text('Encrypted Authentication'), findsOneWidget);
        expect(find.text('Queue & Contact Privacy'), findsOneWidget);
        expect(find.text('Row Level Security (RLS)'), findsOneWidget);
        expect(find.text('Cryptographic QR Verification'), findsOneWidget);
        expect(find.text('Change Password'), findsOneWidget);
      },
    );

    testWidgets('EasyBookingScreen renders title and instructions banner', (
      tester,
    ) async {
      final authService = AuthService(null);

      await tester.pumpWidget(
        AuthScope(
          service: authService,
          child: const MaterialApp(home: EasyBookingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1-Tap Easy Booking'), findsOneWidget);
      expect(find.text('Instant Digital Queue Token'), findsOneWidget);
    });

    testWidgets(
      'CustomerEntryScreen top header contains notification bell with unread badge and greeting',
      (tester) async {
        final authService = AuthService(null);

        await tester.pumpWidget(
          AuthScope(
            service: authService,
            child: const MaterialApp(home: CustomerEntryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Find and book the best salons'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

        // Verify the 4 Quick Benefits cards are removed from Customer Home
        expect(find.text('Real-time Queue'), findsNothing);
        expect(find.text('Verified Salons'), findsNothing);
        expect(find.text('Easy Booking'), findsNothing);
        expect(find.text('Secure & Safe'), findsNothing);
        expect(find.text('Popular Services'), findsOneWidget);
      },
    );
  });
}
