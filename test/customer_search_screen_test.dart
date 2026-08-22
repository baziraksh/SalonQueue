import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/customer/screens/customer_entry_screen.dart';
import 'package:salon_queue/features/customer/screens/customer_search_screen.dart';
import 'package:salon_queue/features/salon/data/salon_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SalonRepository.clearCache();
    SalonRepository.enableDiskPersistence = false;
  });

  group('Customer Search Screen & Navigation Tests', () {
    testWidgets(
      'CustomerSearchScreen displays Header, Location, SearchBar, Chips, and Salon Cards',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: CustomerSearchScreen(initialLocation: 'Bhubaneswar, Odisha'),
          ),
        );
        await tester.pumpAndSettle();

        // Top Header: Back Arrow & Centered Title "Search"
        expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);

        // Location Field
        expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
        expect(find.text('Bhubaneswar, Odisha'), findsOneWidget);
        expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

        // Search Bar
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Search salon or service'), findsOneWidget);

        // Filter Chips: All, Men, Women, Unisex
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Men'), findsOneWidget);
        expect(find.text('Women'), findsOneWidget);
        expect(find.text('Unisex'), findsOneWidget);
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

        // Tap Filter Chip 'Men'
        await tester.tap(find.text('Men'));
        await tester.pumpAndSettle();

        // Tap Filter button to open Sort & Filter modal
        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Sort & Filter Salons'), findsOneWidget);
        expect(find.text('Apply Filters'), findsOneWidget);

        // Close modal
        await tester.tap(find.text('Apply Filters'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Tapping Home Search Bar navigates directly to CustomerSearchScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final authService = AuthService(null);

        await tester.pumpWidget(
          AuthScope(
            service: authService,
            child: const MaterialApp(home: CustomerEntryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Search Bar on Home
        await tester.tap(find.byType(TextField).first, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Verify we are now on CustomerSearchScreen
        expect(find.byType(CustomerSearchScreen), findsOneWidget);
        expect(find.text('Search salon or service'), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);

        // Back navigation returns to Customer Home
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        expect(find.byType(CustomerEntryScreen), findsOneWidget);
        expect(find.text('Skip the Wait'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping See all on Nearby Salons navigates to CustomerSearchScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final authService = AuthService(null);

        await tester.pumpWidget(
          AuthScope(
            service: authService,
            child: const MaterialApp(home: CustomerEntryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "See all" on Nearby Salons
        final seeAllButtons = find.text('See all');
        expect(seeAllButtons, findsAtLeast(1));
        await tester.tap(seeAllButtons.first);
        await tester.pumpAndSettle();

        // Verify on CustomerSearchScreen
        expect(find.byType(CustomerSearchScreen), findsOneWidget);
      },
    );
  });
}
