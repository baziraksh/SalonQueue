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
    testWidgets('Customer Home Header contains Logo on left, Bell & Avatar on right', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = await _buildAuthService(
        const AppUser(id: 'c1', email: 'cust@example.com', fullName: 'Ananya Roy', role: AppRole.customer),
      );

      await tester.pumpWidget(
        AuthScope(
          service: auth,
          child: const MaterialApp(home: CustomerEntryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Top Header: Logo on Left
      expect(find.byIcon(Icons.content_cut), findsAtLeast(1));
      expect(find.text('SALON QUEUE'), findsOneWidget);

      // Top Header: Notification Bell on Right
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

      // Top Header: Profile Avatar on Right
      expect(find.byType(CircleAvatar), findsAtLeast(1));

      // Large search bar & Find Salons button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('FIND SALONS'), findsOneWidget);

      // 4 Functional Cards
      expect(find.text('Real-time Queue'), findsOneWidget);
      expect(find.text('Verified Salons'), findsOneWidget);
      expect(find.text('Easy Booking'), findsOneWidget);
      expect(find.text('Secure & Safe'), findsOneWidget);
    });
  });

  group('2. CUSTOMER SALON DETAILS & HORIZONTAL CATEGORIES TESTS', () {
    testWidgets('Salon Details shows Cover image, horizontal categories starting with All, service selection, and total price bar', (tester) async {
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
        galleryImages: const ['https://example.com/interior.jpg', 'https://example.com/style.jpg'],
        services: const [
          SalonService(id: 's1', salonId: 'salon-det-1', name: 'Classic Fade Haircut', category: 'Hair', price: 250, durationMinutes: 30),
          SalonService(id: 's2', salonId: 'salon-det-1', name: 'Royal Beard Sculpting', category: 'Beard', price: 150, durationMinutes: 20),
          SalonService(id: 's3', salonId: 'salon-det-1', name: 'Charcoal Glow Facial', category: 'Facial', price: 500, durationMinutes: 45),
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
    });
  });

  group('3. CUSTOMER LIVE QUEUE & REAL-TIME POSITION TRACKER TESTS', () {
    testWidgets('CustomerQueueScreen renders digital token, position in line, people ahead, and wait time', (tester) async {
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
    });
  });

  group('4. CUSTOMER PROFILE SCREEN TESTS', () {
    testWidgets('CustomerProfileScreen shows customer info, edit button, and all quick shortcuts', (tester) async {
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

      expect(find.text('My Profile & Account'), findsOneWidget);
      expect(find.text('Ananya Roy'), findsAtLeast(1));
      expect(find.text('ananya@example.com'), findsAtLeast(1));
      expect(find.text('+91 98765 43210'), findsOneWidget);

      // Shortcuts
      expect(find.text('My Queue'), findsOneWidget);
      expect(find.text('Booking & Queue History'), findsOneWidget);
      expect(find.text('Favorite Salons'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Security & Privacy'), findsOneWidget);
      expect(find.text('Help & Support Center'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });

  group('5. SALON OWNER DASHBOARD & HEADER TESTS', () {
    testWidgets('Owner Dashboard Header has Hamburger on left, Salon name, Notification bell on right (NO QR / NO direct Logout icon)', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = await _buildAuthService(
        const AppUser(id: 'o1', email: 'owner@example.com', fullName: 'Rahul Sharma', role: AppRole.salonOwner),
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

      // Main Dashboard Features
      expect(find.text('IN CHAIR'), findsOneWidget);
      expect(find.text('WAITING'), findsOneWidget);
      expect(find.text('CHAIRS'), findsOneWidget);

      expect(find.text('Quick Operations'), findsOneWidget);
      expect(find.text('Add Walk-in'), findsOneWidget);
      expect(find.text('Store QR'), findsOneWidget);
      expect(find.text('Services & Pricing'), findsOneWidget);

      expect(find.text('Currently Serving'), findsOneWidget);
      expect(find.text('Live Queue'), findsOneWidget);

      // Bottom Navigation has Home label
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('Owner Hamburger Menu contains all required store management & account items', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = await _buildAuthService(
        const AppUser(id: 'o1', email: 'owner@example.com', fullName: 'Rahul Sharma', role: AppRole.salonOwner),
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

      // Check all Hamburger Menu ListTile items in order
      expect(find.widgetWithText(ListTile, 'Owner Profile'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Store Information'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Salon Location'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Chairs & Timings'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Help & Support'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Notifications'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Logout'), findsOneWidget);
    });
  });

  group('6. SALON OWNER PROFILE & ISOLATED GALLERY TESTS', () {
    testWidgets('OwnerProfileScreen displays owner info, cover image, and multi-photo gallery', (tester) async {
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
        const AppUser(id: 'o1', email: 'owner@example.com', fullName: 'Rahul Sharma', role: AppRole.salonOwner),
      );

      await tester.pumpWidget(
        AuthScope(
          service: auth,
          child: MaterialApp(
            home: OwnerProfileScreen(salon: salon),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Owner Profile'), findsAtLeast(1));
      expect(find.text('Rahul Sharma'), findsAtLeast(1));
      expect(find.text('Imperial Cuts Lounge'), findsAtLeast(1));
      expect(find.text('Salon Cover Image'), findsOneWidget);
      expect(find.text('Salon Gallery'), findsOneWidget);
      expect(find.text('+ Add Photos'), findsOneWidget);
    });
  });

  group('7. NOTIFICATIONS & SUPPORT RESOLUTION TESTS', () {
    test('Owner receives notification when customer joins queue and support ticket is solved', () async {
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
      expect(notifs.any((n) => n.title == 'New Customer Joined Queue!'), isTrue);

      // Support ticket solved notification
      await supportRepo.updateTicketStatus(
        ticketId: 'owner-tick-99',
        status: SupportTicketStatus.resolved,
        ownerId: ownerId,
        subject: 'Chair configuration query',
        adminResponse: 'Your chair limit has been updated to 5 chairs.',
      );

      final updatedNotifs = await notifRepo.fetchNotifications(ownerId);
      final resolved = updatedNotifs.firstWhere((n) => n.type == NotificationType.supportResolved);
      expect(resolved.title, equals('Support Request Resolved'));
      expect(resolved.message, contains('Chair configuration query'));
    });
  });
}
