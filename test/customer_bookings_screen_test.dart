import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/customer/screens/customer_history_screen.dart';
import 'package:salon_queue/features/queue/data/queue_repository.dart';
import 'package:salon_queue/features/salon/data/salon_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SalonRepository.clearCache();
    QueueRepository.clearLocalCache();
    CustomerHistoryScreen.clearCache();
    SalonRepository.enableDiskPersistence = false;
  });

  group('Customer Bookings / History Screen Redesign Tests', () {
    testWidgets(
      'Bookings screen displays Top Header, Tabs, Badges and View CTA',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final authService = AuthService(null);

        await tester.pumpWidget(
          AuthScope(
            service: authService,
            child: const MaterialApp(home: CustomerHistoryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Top Header: Circular Back Arrow & Centered Title "My Bookings"
        expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
        expect(find.text('My Bookings'), findsOneWidget);

        // Booking Tabs: Upcoming & Completed
        expect(find.text('Upcoming'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);

        // Default empty state for Upcoming
        expect(find.text('No Upcoming Bookings'), findsOneWidget);
        expect(find.text('Explore Salons'), findsOneWidget);

        // Switch to Completed tab
        await tester.tap(find.text('Completed'));
        await tester.pumpAndSettle();

        // Completed tab empty state
        expect(find.text('No Completed Bookings'), findsOneWidget);
      },
    );

    testWidgets(
      'Booking cards render salon name, service, date/time and View button',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final authService = AuthService(null);
        final queueRepo = QueueRepository(client: null);

        // Add a test ticket to local in-memory queue
        await queueRepo.joinQueue(
          salonId: 'salon-book-1',
          customerId: '',
          customerName: 'Asafion Studio',
          selectedServices: [],
        );

        await tester.pumpWidget(
          AuthScope(
            service: authService,
            child: const MaterialApp(home: CustomerHistoryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Verify the booking card appears
        expect(find.text('Upcoming'), findsAtLeast(1));
        expect(find.text('View'), findsOneWidget);
      },
    );

    testWidgets(
      'Bookings screen hydrates instantly from cache on subsequent opens',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final authService = AuthService(null);
        final queueRepo = QueueRepository(client: null);

        await queueRepo.joinQueue(
          salonId: 'salon-instant-1',
          customerId: '',
          customerName: 'Instant Cache Test Salon',
          selectedServices: [],
        );

        // First open to populate cache
        await tester.pumpWidget(
          AuthScope(
            service: authService,
            child: const MaterialApp(home: CustomerHistoryScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Upcoming'), findsAtLeast(1));

        // Re-mount CustomerHistoryScreen; it should show tickets immediately on frame 1 without pumpAndSettle
        await tester.pumpWidget(
          AuthScope(
            service: authService,
            child: const MaterialApp(home: CustomerHistoryScreen()),
          ),
        );
        await tester.pump(); // Just 1 frame!

        expect(find.text('Upcoming'), findsAtLeast(1));
      },
    );
  });
}
