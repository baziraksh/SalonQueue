import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/notifications/data/notification_repository.dart';
import 'package:salon_queue/features/notifications/models/app_notification.dart';
import 'package:salon_queue/features/notifications/screens/owner_notifications_screen.dart';
import 'package:salon_queue/features/salon/screens/salon_entry_screen.dart';
import 'package:salon_queue/features/support/data/support_repository.dart';
import 'package:salon_queue/features/support/models/support_ticket.dart';

void main() {
  group('AppNotification Model Tests', () {
    test('AppNotification fromJson and toJson preserves all fields', () {
      final now = DateTime.now();
      final json = {
        'id': 'notif-123',
        'owner_id': 'owner-456',
        'title': 'Customer Joined Queue',
        'message': 'Rajesh Sharma was assigned Token #5',
        'type': 'CUSTOMER_JOINED',
        'related_id': 'ticket-789',
        'is_read': false,
        'created_at': now.toUtc().toIso8601String(),
      };

      final notif = AppNotification.fromJson(json);
      expect(notif.id, equals('notif-123'));
      expect(notif.ownerId, equals('owner-456'));
      expect(notif.title, equals('Customer Joined Queue'));
      expect(notif.message, equals('Rajesh Sharma was assigned Token #5'));
      expect(notif.type, equals(NotificationType.customerJoined));
      expect(notif.relatedId, equals('ticket-789'));
      expect(notif.isRead, isFalse);

      final outJson = notif.toJson();
      expect(outJson['id'], equals('notif-123'));
      expect(outJson['owner_id'], equals('owner-456'));
      expect(outJson['type'], equals('CUSTOMER_JOINED'));
    });

    test('AppNotification copyWith works correctly', () {
      final notif = AppNotification(
        id: 'n1',
        ownerId: 'o1',
        title: 'Original Title',
        message: 'Original Message',
        type: NotificationType.systemUpdate,
        createdAt: DateTime.now(),
      );

      final updated = notif.copyWith(
        isRead: true,
        title: 'Updated Title',
      );

      expect(updated.isRead, isTrue);
      expect(updated.title, equals('Updated Title'));
      expect(updated.message, equals('Original Message'));
    });

    test('AppNotification timeAgo and icons return valid values', () {
      final recent = AppNotification(
        id: 'n1',
        ownerId: 'o1',
        title: 'Title',
        message: 'Message',
        type: NotificationType.supportResolved,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(recent.timeAgo, contains('5m ago'));
      expect(recent.icon, equals(Icons.check_circle_outline_rounded));
    });
  });

  group('NotificationRepository & Support Linkage Tests', () {
    test('NotificationRepository creates, marks read, and deletes notifications', () async {
      final repo = NotificationRepository();
      const testOwner = 'test-owner-abc';

      final notif = await repo.createNotification(
        ownerId: testOwner,
        title: 'Test Notification',
        message: 'Test Message Body',
        type: NotificationType.queueUpdate,
      );

      expect(notif.ownerId, equals(testOwner));
      expect(notif.isRead, isFalse);

      final list = await repo.fetchNotifications(testOwner);
      expect(list.any((n) => n.id == notif.id), isTrue);

      await repo.markAsRead(notif.id);
      final listAfterRead = await repo.fetchNotifications(testOwner);
      final readNotif = listAfterRead.firstWhere((n) => n.id == notif.id);
      expect(readNotif.isRead, isTrue);

      await repo.deleteNotification(notif.id);
      final listAfterDelete = await repo.fetchNotifications(testOwner);
      expect(listAfterDelete.any((n) => n.id == notif.id), isFalse);
    });

    test('Support ticket resolution creates persistent notification for owner', () async {
      final supportRepo = SupportRepository();
      final notifRepo = NotificationRepository();
      const ownerId = 'owner-support-test';

      await supportRepo.updateTicketStatus(
        ticketId: 'test-ticket-99',
        status: SupportTicketStatus.resolved,
        ownerId: ownerId,
        subject: 'Printer configuration inquiry',
        adminResponse: 'Bluetooth printer issue has been resolved in settings.',
      );

      final notifs = await notifRepo.fetchNotifications(ownerId);
      expect(notifs.any((n) => n.type == NotificationType.supportResolved && n.relatedId == 'test-ticket-99'), isTrue);
    });
  });

  group('Owner Notifications Screen Widget Tests', () {
    testWidgets('OwnerNotificationsScreen renders title and filter chips', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerNotificationsScreen(ownerId: 'demo-owner'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });
  });

  group('Owner Dashboard Header & QR Removal Tests', () {
    testWidgets('SalonEntryScreen header has Hamburger Menu, Salon Title, and Notification Bell (NO top-right QR icon)', (tester) async {
      final authService = AuthService(null);
      authService.updateCurrentUserAvatar('https://example.com/avatar.jpg');

      await tester.pumpWidget(
        AuthScope(
          service: authService,
          child: const MaterialApp(
            home: SalonEntryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top-Left Hamburger Menu
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // Center title and dashboard indicator
      expect(find.text('OWNER DASHBOARD'), findsOneWidget);

      // Top-Right Notification Bell
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

      // Verify that QR code icon is NOT in the AppBar actions
      // (The QR code icon remains in the bottom navigation bar as intended)
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.actions, isNotNull);
      final qrIconsInAppBar = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.qr_code_2_rounded),
      );
      expect(qrIconsInAppBar, findsNothing);
    });
  });
}
