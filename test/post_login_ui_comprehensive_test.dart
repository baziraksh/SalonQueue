import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/auth/data/auth_repository.dart';
import 'package:salon_queue/features/auth/models/app_user.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/customer/screens/customer_entry_screen.dart';
import 'package:salon_queue/features/customer/screens/customer_profile_screen.dart';
import 'package:salon_queue/features/notifications/data/notification_repository.dart';
import 'package:salon_queue/features/notifications/models/app_notification.dart';
import 'package:salon_queue/features/queue/screens/customer_queue_screen.dart';
import 'package:salon_queue/features/salon/screens/owner_profile_screen.dart';
import 'package:salon_queue/features/salon/screens/salon_details_screen.dart';
import 'package:salon_queue/features/salon/screens/salon_entry_screen.dart';
import 'package:salon_queue/features/support/data/support_repository.dart';
import 'package:salon_queue/features/support/models/support_ticket.dart';
import 'package:salon_queue/shared/models/queue_ticket.dart';
import 'package:salon_queue/shared/models/salon.dart';
import 'package:salon_queue/shared/models/salon_service.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.user) : super();

  final AppUser user;
  bool signedOut = false;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    return user;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

Future<AuthService> _buildAuthService(AppUser user) async {
  final service = AuthService(_FakeAuthRepository(user));
  await service.signIn(
    email: user.email ?? 'user@example.com',
    password: 'password123',
    requestedRole: user.role,
  );
  return service;
}

void main() {
  group('1. CUSTOMER POST-LOGIN UI & HEADER TESTS', () {
    testWidgets('Customer Home Header contains Greeting, Bell & Avatar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = await _buildAuthService(
        const AppUser(
          id: 'c1',
          email: 'cust@example.com',
          fullName: 'Ananya Roy',
          role: AppRole.customer,
        ),
      );

      await tester.pumpWidget(
        AuthScope(
          service: auth,
          child: const MaterialApp(home: CustomerEntryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Top Header: Greeting & Subtitle
      expect(find.text('Hi, Ananya 👋'), findsOneWidget);
      expect(find.text('Find and book the best salons'), findsOneWidget);

      // Top Header: Notification Bell & Profile Avatar
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person), findsAtLeast(1));

      // Modern Search bar
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search salon, services or location'), findsOneWidget);

      // Promotional Banner & Sections
      expect(find.text('Skip the Wait'), findsOneWidget);
      expect(find.text('Book Your'), findsOneWidget);
      expect(find.text('Slot Now'), findsOneWidget);
      expect(find.text('Book Now'), findsNothing);
      expect(find.text('Nearby Salons'), findsOneWidget);
      expect(find.text('Popular Services'), findsOneWidget);

      // Old feature cards are removed
      expect(find.text('Real-time Queue'), findsNothing);
      expect(find.text('Verified Salons'), findsNothing);
    });
  });

  group('2. CUSTOMER SALON DETAILS & HORIZONTAL CATEGORIES TESTS', () {
    testWidgets(
      'Salon Details shows Cover image, horizontal categories starting with All, service selection, and total price bar',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final salon = Salon(
          id: 'salon-det-1',
          name: 'Grand Royal Salon',
          address: 'FC Road, Pune',
          city: 'Pune',
          ownerName: 'Vikram Mehta',
          ownerAvatarUrl: 'https://example.com/vikram.jpg',
          isVerified: true,
          galleryImages: const [
            'https://example.com/interior.jpg',
            'https://example.com/style.jpg',
          ],
          services: const [
            SalonService(
              id: 's1',
              salonId: 'salon-det-1',
              name: 'Classic Fade Haircut',
              category: 'Hair',
              price: 250,
              durationMinutes: 30,
            ),
            SalonService(
              id: 's2',
              salonId: 'salon-det-1',
              name: 'Royal Beard Sculpting',
              category: 'Beard',
              price: 150,
              durationMinutes: 20,
            ),
            SalonService(
              id: 's3',
              salonId: 'salon-det-1',
              name: 'Charcoal Glow Facial',
              category: 'Facial',
              price: 500,
              durationMinutes: 45,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(home: SalonDetailsScreen(salon: salon)),
        );
        await tester.pumpAndSettle();

        // Salon details & owner card
        expect(find.text('Grand Royal Salon'), findsAtLeast(1));
        expect(find.text('Vikram Mehta'), findsOneWidget);
        expect(find.text('OWNER'), findsOneWidget);

        // Horizontal categories bar with All, Hair, Beard, Facial
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Hair'), findsAtLeast(1));
        expect(find.text('Beard'), findsAtLeast(1));
        expect(find.text('Facial'), findsAtLeast(1));

        // Selectable services
        expect(find.text('Classic Fade Haircut'), findsOneWidget);
        expect(find.text('Royal Beard Sculpting'), findsOneWidget);
        expect(find.text('Charcoal Glow Facial'), findsOneWidget);

        // Initial Join button and 0 selected text
        expect(find.text('Join Live Queue'), findsOneWidget);
        expect(find.text('0 service(s) selected'), findsOneWidget);

        // Select first service (Classic Fade Haircut)
        await tester.tap(find.text('Classic Fade Haircut'));
        await tester.pumpAndSettle();

        // Bottom bar updates total price & duration
        expect(find.text('1 service(s) selected'), findsOneWidget);
        expect(find.text('₹250 • ~30 mins'), findsOneWidget);

        // Multi-select second service (Royal Beard Sculpting)
        await tester.tap(find.text('Royal Beard Sculpting'));
        await tester.pumpAndSettle();

        expect(find.text('2 service(s) selected'), findsOneWidget);
        expect(find.text('₹400 • ~50 mins'), findsOneWidget);
      },
    );
  });

  group('3. CUSTOMER LIVE QUEUE & REAL-TIME POSITION TRACKER TESTS', () {
    testWidgets(
      'CustomerQueueScreen renders digital token, position in line, people ahead, and wait time',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final ticket = QueueTicket(
          id: 't-123',
          salonId: 'salon-1',
          tokenNumber: 5,
          customerName: 'Ananya Roy',
          customerId: 'c1',
          serviceNames: const ['Classic Haircut'],
          totalPrice: 250,
          totalDurationMinutes: 30,
          status: QueueStatus.waiting,
          createdAt: DateTime.now(),
        );

        final salon = Salon(
          id: 'salon-1',
          name: 'The Barber Lounge',
          address: 'JM Road, Pune',
          city: 'Pune',
          activeChairs: 3,
          services: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CustomerQueueScreen(ticket: ticket, salon: salon),
          ),
        );
        await tester.pumpAndSettle();

        // Digital Token Number (#A-05)
        expect(find.text('#A-05'), findsOneWidget);
        expect(find.text('Ananya Roy'), findsOneWidget);
        expect(find.text('The Barber Lounge'), findsOneWidget);

        // Live Position and Wait metrics
        expect(find.text('CURRENT POSITION'), findsOneWidget);
        expect(find.text('ESTIMATED WAIT'), findsOneWidget);
        expect(find.text('Live Queue Token'), findsOneWidget);

        // Stepper
        expect(find.text('Token Confirmed'), findsOneWidget);
        expect(find.text('Almost Your Turn'), findsOneWidget);
        expect(find.text('In Chair / Service Started'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
      },
    );
  });

  group('4. CUSTOMER PROFILE SCREEN TESTS', () {
    testWidgets(
      'CustomerProfileScreen shows customer info, edit button, and all quick shortcuts',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final auth = await _buildAuthService(
          const AppUser(
            id: 'c1',
            email: 'ananya@example.com',
            fullName: 'Ananya Roy',
            phone: '+91 98765 43210',
            role: AppRole.customer,
          ),
        );

        await tester.pumpWidget(
          AuthScope(
            service: auth,
            child: const MaterialApp(home: CustomerProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ananya Roy'), findsAtLeast(1));
        expect(find.text('+91 98765 43210'), findsOneWidget);
        expect(find.byIcon(Icons.mode_edit_outline_rounded), findsOneWidget);

        // Redesigned Reference Menu Items
        expect(find.text('My Bookings'), findsOneWidget);
        expect(find.text('Favorite Salons'), findsOneWidget);
        expect(find.text('My Wallet'), findsOneWidget);
        expect(find.text('My Reviews'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('ananya@example.com'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Help & Support'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Invite Friends'), findsOneWidget);
        expect(find.text('Logout'), findsOneWidget);
      },
    );
  });

  group('5. SALON OWNER DASHBOARD & HEADER TESTS', () {
    testWidgets(
      'Owner Dashboard Header has Hamburger on left, Salon name, Notification bell on right (NO QR / NO direct Logout icon)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final auth = await _buildAuthService(
          const AppUser(
            id: 'o1',
            email: 'owner@example.com',
            fullName: 'Rahul Sharma',
            role: AppRole.salonOwner,
          ),
        );

        await tester.pumpWidget(
          AuthScope(
            service: auth,
            child: const MaterialApp(home: SalonEntryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Hamburger on left
        expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

        // Notification bell on right
        expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

        // Header has clean title and NO OWNER DASHBOARD badge
        expect(find.text('OWNER DASHBOARD'), findsNothing);

        // Main Dashboard Features
        expect(find.text('IN CHAIR'), findsOneWidget);
        expect(find.text('WAITING'), findsOneWidget);
        expect(find.text('CHAIRS'), findsOneWidget);

        expect(find.text('Quick Actions'), findsOneWidget);
        expect(find.text('Add Walk-in'), findsOneWidget);
        expect(find.text('Store QR'), findsOneWidget);
        expect(find.text('Services & Pricing'), findsOneWidget);

        // Bottom Navigation has Dashboard, Bookings, Live Queue, Customers, More
        expect(find.text('Dashboard'), findsWidgets);
        expect(find.text('Bookings'), findsWidgets);
        expect(find.text('Live Queue'), findsWidgets);
        expect(find.text('Customers'), findsWidgets);
        expect(find.text('More'), findsOneWidget);
      },
    );

    testWidgets(
      'Owner Bookings Screen displays Top Header, Filter Tabs, Date Selector, Booking Rows & FAB',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final auth = await _buildAuthService(
          const AppUser(
            id: 'o1',
            email: 'owner@example.com',
            fullName: 'Rahul Sharma',
            role: AppRole.salonOwner,
          ),
        );

        await tester.pumpWidget(
          AuthScope(
            service: auth,
            child: const MaterialApp(home: SalonEntryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Bookings Tab (index 1) via Bottom Navigation Bar
        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.byIcon(Icons.calendar_today_outlined),
          ),
        );
        await tester.pumpAndSettle();

        // Header: Bookings Title & Compose/New Booking Icon
        expect(find.text('Bookings'), findsWidgets);
        expect(find.byIcon(Icons.drive_file_rename_outline_rounded), findsOneWidget);

        // Filter Tabs: All, Upcoming, Completed, Cancelled
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Upcoming'), findsWidgets);
        expect(find.text('Completed'), findsWidgets);
        expect(find.text('Cancelled'), findsWidgets);

        // Date selector cards
        expect(find.text('Mon'), findsOneWidget);
        expect(find.text('Tue'), findsOneWidget);
        expect(find.text('Wed'), findsOneWidget);
        expect(find.text('Thu'), findsOneWidget);
        expect(find.text('Fri'), findsOneWidget);

        // Booking rows with customer names and services
        expect(find.text('Ravi Kumar'), findsOneWidget);
        expect(find.text('Haircut'), findsWidgets);
        expect(find.text('Anita Singh'), findsOneWidget);

        // Floating Action Button (+)
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'Owner Live Queue Screen displays Header, Waiting Badge, 3 Stat Cards, Manage Queue & Action Buttons',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final auth = await _buildAuthService(
          const AppUser(
            id: 'o1',
            email: 'owner@example.com',
            fullName: 'Rahul Sharma',
            role: AppRole.salonOwner,
          ),
        );

        await tester.pumpWidget(
          AuthScope(
            service: auth,
            child: const MaterialApp(home: SalonEntryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Live Queue Tab (index 2) via Bottom Navigation Bar
        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.byIcon(Icons.groups_outlined),
          ),
        );
        await tester.pumpAndSettle();

        // Header: Live Queue Title & Staff Icon (NO Settings icon in Live Queue)
        expect(find.text('Live Queue'), findsWidgets);
        expect(find.byIcon(Icons.people_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsNothing);

        // Waiting Badge
        expect(find.text('5 waiting'), findsOneWidget);

        // 3 Statistic Cards: IN CHAIR, WAITING, CHAIRS
        expect(find.text('IN CHAIR'), findsOneWidget);
        expect(find.text('Serving Now'), findsOneWidget);

        expect(find.text('WAITING'), findsOneWidget);
        expect(find.text('In Live Line'), findsOneWidget);

        expect(find.text('CHAIRS'), findsOneWidget);
        expect(find.text('Capacity'), findsOneWidget);

        // Manage Queue Card with Auto Call toggle
        expect(find.text('Manage Queue'), findsOneWidget);
        expect(find.text('Auto call'), findsOneWidget);
        expect(find.byType(Switch), findsOneWidget);

        // Queue Customer List
        expect(find.text('Ankit Singh'), findsOneWidget);
        expect(find.text('Hair Spa'), findsOneWidget);
        expect(find.text('Vikash Patel'), findsOneWidget);
        expect(find.text('Beard Trim'), findsOneWidget);
        expect(find.text('Next'), findsWidgets);
        expect(find.text('Call'), findsWidgets);

        // Call Next and Pause Queue Buttons
        expect(find.widgetWithText(ElevatedButton, 'Call Next'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Pause Queue'), findsOneWidget);
      },
    );

    testWidgets(
      'Owner Customers Screen displays Header, Search Bar, Statistics, Customer Rows & FAB',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final auth = await _buildAuthService(
          const AppUser(
            id: 'o1',
            email: 'owner@example.com',
            fullName: 'Rahul Sharma',
            role: AppRole.salonOwner,
          ),
        );

        await tester.pumpWidget(
          AuthScope(
            service: auth,
            child: const MaterialApp(home: SalonEntryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Customers Tab (index 3) via Bottom Navigation Bar
        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.byIcon(Icons.person_outline_rounded),
          ),
        );
        await tester.pumpAndSettle();

        // Header: Customers Title & No Bell Icon
        expect(find.text('Customers'), findsWidgets);

        // Search Field & Filter Button
        expect(find.text('Search customers'), findsOneWidget);
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

        // Statistics Cards: Total Customers (128) & New This Month (23)
        expect(find.text('Total Customers'), findsOneWidget);
        expect(find.text('128'), findsOneWidget);
        expect(find.text('New This Month'), findsOneWidget);
        expect(find.text('23'), findsOneWidget);

        // Customer Cards: Ravi Kumar, Anita Singh, phone numbers, visit badges
        expect(find.text('Ravi Kumar'), findsOneWidget);
        expect(find.text('+91 12345 67890'), findsOneWidget);
        expect(find.text('12 Visits'), findsOneWidget);

        expect(find.text('Anita Singh'), findsOneWidget);
        expect(find.text('+91 98765 43210'), findsOneWidget);
        expect(find.text('8 Visits'), findsOneWidget);

        // Floating Action Button (+)
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);

        // Test Real-Time Search Filtering
        await tester.enterText(find.byType(TextField).first, 'Anita');
        await tester.pumpAndSettle();

        expect(find.text('Anita Singh'), findsOneWidget);
        expect(find.text('Ravi Kumar'), findsNothing);

        // Clear search text
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pumpAndSettle();
        expect(find.text('Ravi Kumar'), findsOneWidget);
      },
    );

    testWidgets(
      'Owner Settings Screen displays Header, Back Arrow, and all 9 Settings Cards',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final auth = await _buildAuthService(
          const AppUser(
            id: 'o1',
            email: 'owner@example.com',
            fullName: 'Rahul Sharma',
            role: AppRole.salonOwner,
          ),
        );

        await tester.pumpWidget(
          AuthScope(
            service: auth,
            child: const MaterialApp(home: SalonEntryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to More / Settings Tab (index 4) via Bottom Navigation Bar
        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.byIcon(Icons.more_horiz_outlined),
          ),
        );
        await tester.pumpAndSettle();

        // Header: Settings Title & Back Arrow (No Hamburger, No Bell)
        expect(find.text('Settings'), findsWidgets);
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

        // 9 Setting Cards
        expect(find.text('Salon Profile'), findsOneWidget);
        expect(find.text('Business Information'), findsOneWidget);
        expect(find.text('Working Hours'), findsOneWidget);
        expect(find.text('Services & Pricing'), findsOneWidget);
        expect(find.text('Payment Methods'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text('Help & Support'), findsOneWidget);
        expect(find.text('Logout'), findsOneWidget);

        // Tapping Back Arrow returns to Dashboard
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Dashboard'), findsWidgets);
      },
    );

    testWidgets(
      'Owner Hamburger Menu contains 11 designated owner feature items and excludes removed store setup items',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final auth = await _buildAuthService(
          const AppUser(
            id: 'o1',
            email: 'owner@example.com',
            fullName: 'Rahul Sharma',
            role: AppRole.salonOwner,
          ),
        );

        await tester.pumpWidget(
          AuthScope(
            service: auth,
            child: const MaterialApp(home: SalonEntryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Open drawer using hamburger
        await tester.tap(find.byIcon(Icons.menu_rounded));
        await tester.pumpAndSettle();

        // Check all 11 Owner Feature items exist in Hamburger Menu
        expect(find.widgetWithText(ListTile, 'Dashboard'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Bookings'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Live Queue'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Customers'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Staff'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Services'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Reviews'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Wallet'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Analytics'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Settings'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'QR Code'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Logout'), findsOneWidget);

        // Verify the 6 removed store setup / support items are NOT in Hamburger Menu
        expect(find.widgetWithText(ListTile, 'Owner Profile'), findsNothing);
        expect(find.widgetWithText(ListTile, 'Store Information'), findsNothing);
        expect(find.widgetWithText(ListTile, 'Salon Location'), findsNothing);
        expect(find.widgetWithText(ListTile, 'Chairs & Timings'), findsNothing);
        expect(find.widgetWithText(ListTile, 'Help & Support'), findsNothing);
        expect(find.widgetWithText(ListTile, 'Notifications'), findsNothing);
      },
    );
  });

  group('6. SALON OWNER PROFILE & ISOLATED GALLERY TESTS', () {
    testWidgets(
      'OwnerProfileScreen displays owner info, cover image, and multi-photo gallery',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final salon = Salon(
          id: 'salon-own-1',
          ownerId: 'o1',
          name: 'Imperial Cuts Lounge',
          address: 'MG Road, Pune',
          city: 'Pune',
          ownerName: 'Rahul Sharma',
          ownerAvatarUrl: 'https://example.com/rahul.jpg',
          coverImageUrl: 'https://example.com/cover.jpg',
          galleryImages: const [
            'https://example.com/interior.jpg',
            'https://example.com/fade_haircut.jpg',
          ],
          services: const [],
        );

        final auth = await _buildAuthService(
          const AppUser(
            id: 'o1',
            email: 'owner@example.com',
            fullName: 'Rahul Sharma',
            role: AppRole.salonOwner,
          ),
        );

        await tester.pumpWidget(
          AuthScope(
            service: auth,
            child: MaterialApp(home: OwnerProfileScreen(salon: salon)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Owner Profile'), findsAtLeast(1));
        expect(find.text('Rahul Sharma'), findsAtLeast(1));
        expect(find.text('Imperial Cuts Lounge'), findsAtLeast(1));
        expect(find.text('Salon Cover Image'), findsOneWidget);
        expect(find.text('Salon Gallery'), findsOneWidget);
        expect(find.text('+ Add Photos'), findsOneWidget);
      },
    );
  });

  group('7. NOTIFICATIONS & SUPPORT RESOLUTION TESTS', () {
    test(
      'Owner receives notification when customer joins queue and support ticket is solved',
      () async {
        final notifRepo = NotificationRepository();
        final supportRepo = SupportRepository();
        const ownerId = 'owner-test-456';

        // Customer joins queue notification
        await notifRepo.notifyOwnerCustomerJoined(
          ownerId: ownerId,
          customerName: 'Kunal Patil',
          tokenNumber: 8,
          serviceNames: ['Haircut & Beard Trim'],
        );

        final notifs = await notifRepo.fetchNotifications(ownerId);
        expect(
          notifs.any((n) => n.title == 'New Customer Joined Queue!'),
          isTrue,
        );

        // Support ticket solved notification
        await supportRepo.updateTicketStatus(
          ticketId: 'owner-tick-99',
          status: SupportTicketStatus.resolved,
          ownerId: ownerId,
          subject: 'Chair configuration query',
          adminResponse: 'Your chair limit has been updated to 5 chairs.',
        );

        final updatedNotifs = await notifRepo.fetchNotifications(ownerId);
        final resolved = updatedNotifs.firstWhere(
          (n) => n.type == NotificationType.supportResolved,
        );
        expect(resolved.title, equals('Support Request Resolved'));
        expect(resolved.message, contains('Chair configuration query'));
      },
    );
  });

  group('8. PROMOTIONAL BANNER & ZERO FAKE SALONS AUDIT TESTS', () {
    testWidgets(
      'Promotional banner renders balanced text & chair without Book Now button',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final auth = await _buildAuthService(
          const AppUser(
            id: 'cust-find-1',
            email: 'cust@example.com',
            fullName: 'Akash Kumar',
            role: AppRole.customer,
          ),
        );

        await tester.pumpWidget(
          AuthScope(
            service: auth,
            child: const MaterialApp(home: CustomerEntryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Banner text is present
        expect(find.text('Skip the Wait'), findsOneWidget);
        expect(find.text('Book Your'), findsOneWidget);
        expect(find.text('Slot Now'), findsOneWidget);

        // Book Now button is removed
        final bookNowButton = find.widgetWithText(ElevatedButton, 'Book Now');
        expect(bookNowButton, findsNothing);
      },
    );

    test(
      'Salon.fromJson does not fabricate fake ratings, reviews or cities',
      () {
        final json = {
          'id': 'real-salon-uuid-1',
          'owner_id': 'real-owner-uuid-1',
          'name': 'Actual Barbershop',
        };

        final salon = Salon.fromJson(json);
        expect(salon.id, equals('real-salon-uuid-1'));
        expect(salon.ownerId, equals('real-owner-uuid-1'));
        expect(salon.name, equals('Actual Barbershop'));
        expect(salon.city, equals(''));
        expect(salon.state, equals(''));
        expect(salon.rating, equals(0.0));
        expect(salon.reviewCount, equals(0));
        expect(salon.isVerified, isFalse);
      },
    );
  });
}
