import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/salon/screens/owner_profile_screen.dart';
import 'package:salon_queue/features/salon/screens/salon_details_screen.dart';
import 'package:salon_queue/shared/models/salon.dart';
import 'package:salon_queue/shared/models/salon_service.dart';

void main() {
  group('Issue 1: Customer Side Service Category Chips Tests', () {
    late Salon testSalon;

    setUp(() {
      testSalon = Salon(
        id: 'test-salon-1',
        name: 'Royal Cuts & Grooming Lounge',
        address: '123 MG Road',
        city: 'Pune',
        district: 'Pune',
        state: 'Maharashtra',
        ownerName: 'Rahul Sharma',
        ownerAvatarUrl: 'https://example.com/avatar.jpg',
        services: const [
          SalonService(
            id: 'svc-1',
            salonId: 'test-salon-1',
            name: 'Classic Haircut',
            category: 'Hair',
            price: 150,
            durationMinutes: 25,
          ),
          SalonService(
            id: 'svc-2',
            salonId: 'test-salon-1',
            name: 'Beard Trim',
            category: 'Beard',
            price: 80,
            durationMinutes: 15,
          ),
          SalonService(
            id: 'svc-3',
            salonId: 'test-salon-1',
            name: 'Gold Facial',
            category: 'Facial',
            price: 400,
            durationMinutes: 30,
          ),
          SalonService(
            id: 'svc-4',
            salonId: 'test-salon-1',
            name: 'Hair Spa Luxury',
            category: 'Spa',
            price: 600,
            durationMinutes: 45,
          ),
        ],
      );
    });

    testWidgets(
      'Every service category chip displays its name clearly and visibly',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final authService = AuthService(null);

        await tester.pumpWidget(
          MaterialApp(
            home: AuthScope(
              service: authService,
              child: SalonDetailsScreen(salon: testSalon),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify all dynamic category names are rendered and visible
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Hair'), findsWidgets);
        expect(find.text('Beard'), findsWidgets);
        expect(find.text('Facial'), findsWidgets);
        expect(find.text('Spa'), findsWidgets);

        // Under 'All' category, services are visible
        expect(find.text('Classic Haircut'), findsOneWidget);
        expect(find.text('Beard Trim'), findsOneWidget);

        // Tap 'Beard' category chip
        await tester.tap(find.text('Beard').first);
        await tester.pumpAndSettle();

        // Verify Beard service is now shown and Hair service is filtered out
        expect(find.text('Beard Trim'), findsOneWidget);
        expect(find.text('Classic Haircut'), findsNothing);

        // Tap 'Facial' category chip
        await tester.tap(find.text('Facial'));
        await tester.pumpAndSettle();

        // Verify Facial service is now shown
        expect(find.text('Gold Facial'), findsOneWidget);
        expect(find.text('Beard Trim'), findsNothing);
      },
    );
  });

  group('Issue 2: Owner Profile Delete Photo Tests', () {
    late Salon testSalon;

    setUp(() {
      testSalon = Salon(
        id: 'test-salon-1',
        ownerId: 'owner-user-1',
        name: 'Royal Cuts & Grooming Lounge',
        address: '123 MG Road',
        city: 'Pune',
        district: 'Pune',
        state: 'Maharashtra',
        ownerName: 'Rahul Sharma',
        ownerAvatarUrl: 'https://example.com/avatar.jpg',
      );
    });

    testWidgets(
      'Delete photo button shows confirmation dialog and removes photo on confirmation',
      (tester) async {
        final authService = AuthService(null);

        await tester.pumpWidget(
          MaterialApp(
            home: AuthScope(
              service: authService,
              child: OwnerProfileScreen(salon: testSalon),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial state: Photo uploaded is displayed, delete trash button is present
        expect(find.text('Photo uploaded'), findsOneWidget);
        final deleteBtnFinder = find.byIcon(Icons.delete_outline);
        expect(deleteBtnFinder, findsOneWidget);

        // Tap delete button -> Confirmation dialog appears
        await tester.tap(deleteBtnFinder);
        await tester.pumpAndSettle();

        expect(find.text('Delete Profile Photo?'), findsOneWidget);
        expect(
          find.text('Are you sure you want to remove your profile photo?'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);

        // Tap Cancel -> Dialog dismissed, photo remains
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Photo uploaded'), findsOneWidget);

        // Tap delete button again -> Confirm deletion
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Verify photo state updated to 'No photo uploaded' and delete button is removed
        expect(find.text('No photo uploaded'), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
      },
    );
  });
}
