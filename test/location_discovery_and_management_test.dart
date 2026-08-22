import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/customer/screens/customer_entry_screen.dart';
import 'package:salon_queue/features/customer/services/location_suggestion_service.dart';
import 'package:salon_queue/features/salon/data/salon_repository.dart';
import 'package:salon_queue/features/salon/screens/salon_details_screen.dart';
import 'package:salon_queue/features/salon/screens/salon_location_screen.dart';
import 'package:salon_queue/shared/models/salon.dart';
import 'package:salon_queue/shared/models/salon_service.dart';
import 'package:salon_queue/shared/widgets/salon_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SalonRepository.clearCache();
    SalonRepository.enableDiskPersistence = false;
  });

  group('LocationSuggestionService Tests', () {
    test('calculateDistanceKm computes accurate Haversine distance', () {
      // Pune (18.5204, 73.8567) to Mumbai (19.0760, 72.8777) is ~119-125 km
      final distMumbai = LocationSuggestionService.calculateDistanceKm(
        18.5204,
        73.8567,
        19.0760,
        72.8777,
      );
      expect(distMumbai, greaterThan(110.0));
      expect(distMumbai, lessThan(135.0));

      // Same location is 0.0 km
      final distZero = LocationSuggestionService.calculateDistanceKm(
        20.8398,
        85.1013,
        20.8398,
        85.1013,
      );
      expect(distZero, equals(0.0));

      // Angul (20.8398, 85.1013) to Saheed Nagar, Bhubaneswar (20.2961, 85.8245) is ~95-105 km
      final distOdisha = LocationSuggestionService.calculateDistanceKm(
        20.8398,
        85.1013,
        20.2961,
        85.8245,
      );
      expect(distOdisha, greaterThan(80.0));
      expect(distOdisha, lessThan(120.0));
    });

    test('fromNominatim parses OpenStreetMap JSON correctly', () {
      final osmJson = {
        'lat': '20.2961',
        'lon': '85.8245',
        'display_name':
            'Saheed Nagar, Bhubaneswar, Khordha, Odisha, 751007, India',
        'address': {
          'suburb': 'Saheed Nagar',
          'city': 'Bhubaneswar',
          'county': 'Khordha',
          'state': 'Odisha',
          'postcode': '751007',
          'country': 'India',
        },
      };

      final suggestion = LocationSuggestion.fromNominatim(osmJson);
      expect(suggestion.title, equals('Saheed Nagar'));
      expect(suggestion.city, equals('Bhubaneswar'));
      expect(suggestion.district, equals('Khordha'));
      expect(suggestion.state, equals('Odisha'));
      expect(suggestion.pincode, equals('751007'));
      expect(suggestion.latitude, equals(20.2961));
      expect(suggestion.longitude, equals(85.8245));
    });

    test('searchLocationSuggestions finds offline Indian locations', () async {
      final results = await LocationSuggestionService.searchLocationSuggestions(
        'Angul',
      );
      expect(results.isNotEmpty, isTrue);
      final match = results.firstWhere(
        (r) => r.title.toLowerCase().contains('angul'),
      );
      expect(match.state, equals('Odisha'));
      expect(match.latitude, isNotNull);
      expect(match.longitude, isNotNull);
    });

    test('geocodeAddress resolves coordinates with fallback', () async {
      final coords = await LocationSuggestionService.geocodeAddress(
        address: 'Main Market Road',
        city: 'Angul',
        district: 'Angul',
        state: 'Odisha',
        pincode: '759119',
      );

      expect(coords['latitude'], isNotNull);
      expect(coords['longitude'], isNotNull);
      expect(coords['latitude']!, greaterThan(20.0));
      expect(coords['longitude']!, greaterThan(84.0));
    });
  });

  group('SalonRepository Location & 10km Recommendation Tests', () {
    test(
      'updateSalonLocation persists coordinates and location fields',
      () async {
        final repo = SalonRepository();
        const salonId = 'test-salon-location-1';
        const ownerId = 'owner-test-location-1';

        await repo.updateSalonLocation(
          salonId: salonId,
          ownerId: ownerId,
          state: 'Odisha',
          district: 'Angul',
          city: 'Angul',
          address: 'Main Market Road, Near Clock Tower',
          pincode: '759119',
          latitude: 20.8398,
          longitude: 85.1013,
        );

        final salon = await repo.fetchSalonById(salonId);
        expect(salon, isNotNull);
        expect(salon!.state, equals('Odisha'));
        expect(salon.district, equals('Angul'));
        expect(salon.city, equals('Angul'));
        expect(salon.address, equals('Main Market Road, Near Clock Tower'));
        expect(salon.pincode, equals('759119'));
        expect(salon.latitude, equals(20.8398));
        expect(salon.longitude, equals(85.1013));
      },
    );

    test(
      'fetchSalons filters by pincode, city, and sorts by nearest distance',
      () async {
        final repo = SalonRepository();
        await repo.updateSalonLocation(
          salonId: 'pune-test-1',
          ownerId: 'owner-pune-1',
          state: 'Maharashtra',
          district: 'Pune',
          city: 'Pune',
          address: 'FC Road',
          pincode: '411004',
          latitude: 18.5196,
          longitude: 73.8413,
        );

        // Query with Pune coordinates (18.5204, 73.8567)
        final salons = await repo.fetchSalons(
          city: 'Pune',
          userLat: 18.5204,
          userLng: 73.8567,
          sortBy: 'nearest',
        );

        expect(salons.isNotEmpty, isTrue);
        expect(salons.first.city.toLowerCase(), equals('pune'));
        expect(salons.first.distanceKm, isNotNull);
        expect(salons.first.distanceKm!, lessThan(10.0));
      },
    );

    test(
      'fetchSalons 10km proximity fallback when exact city has no salon',
      () async {
        final repo = SalonRepository();
        await repo.updateSalonLocation(
          salonId: 'pune-test-2',
          ownerId: 'owner-pune-2',
          state: 'Maharashtra',
          district: 'Pune',
          city: 'Pune',
          address: 'Deccan Gymkhana',
          pincode: '411004',
          latitude: 18.5196,
          longitude: 73.8413,
        );

        // Query for a non-existent city near Pune coordinates
        final nearbySalons = await repo.fetchSalons(
          city: 'NonExistentLocalArea',
          userLat: 18.5204, // Center of Pune
          userLng: 73.8567,
          maxRadiusKm: 10.0,
        );

        // Should find nearby registered salons within 10 km
        expect(nearbySalons.isNotEmpty, isTrue);
        for (final s in nearbySalons) {
          expect(s.distanceKm, isNotNull);
          expect(s.distanceKm!, lessThanOrEqualTo(10.0));
        }
      },
    );
  });

  group('Owner SalonLocationScreen Widget Test', () {
    testWidgets(
      'Owner can edit and save State, District, City, Address, Pincode',
      (tester) async {
        const initialSalon = Salon(
          id: 'owner-widget-salon-1',
          ownerId: 'owner-user-123',
          name: 'Grooming Hub',
          address: 'Old Road',
          city: 'Pune',
          district: 'Pune',
          state: 'Maharashtra',
          pincode: '411001',
        );

        final authService = AuthService(null);

        await tester.pumpWidget(
          AuthScope(
            service: authService,
            child: const MaterialApp(
              home: SalonLocationScreen(salon: initialSalon),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Salon Location'), findsOneWidget);
        expect(find.text('Save Salon Location'), findsOneWidget);

        // Verify form fields
        expect(find.text('Address & Region'), findsOneWidget);
        expect(find.text('State *'), findsOneWidget);
        expect(find.text('District *'), findsOneWidget);
        expect(find.text('City / Village / Area *'), findsOneWidget);
        expect(find.text('Street Address & Locality *'), findsOneWidget);
        expect(find.text('PIN Code'), findsOneWidget);

        // Enter new address
        final addressFinder = find.widgetWithText(TextFormField, 'Old Road');
        expect(addressFinder, findsOneWidget);
        await tester.enterText(addressFinder, 'Saheed Nagar Janpath');

        // Tap Save Salon Location
        await tester.tap(find.text('Save Salon Location'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Salon location updated successfully!'),
          findsOneWidget,
        );
      },
    );
  });

  group('Customer Location Selector & Salon Details Navigation Test', () {
    testWidgets('Customer sees location selector and can drilldown or search', (
      tester,
    ) async {
      final authService = AuthService(null);

      await tester.pumpWidget(
        AuthScope(
          service: authService,
          child: const MaterialApp(home: CustomerEntryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Check search area
      expect(find.text('Search salon, services or location'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // Tap the Search bar
      await tester.tap(find.byType(TextField).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Check CustomerSearchScreen contents
      expect(find.text('Search'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);

      // Tap Location selector in Search
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // Check bottom sheet contents
      expect(find.text('Select Location across India 🇮🇳'), findsOneWidget);
      expect(find.text('📍 Near Me'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'All India 🇮🇳'), findsOneWidget);

      // Tap "All India 🇮🇳" chip
      await tester.tap(find.widgetWithText(ActionChip, 'All India 🇮🇳'));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'SalonCard displays distance badge, owner details, and join queue CTA',
      (tester) async {
        const salon = Salon(
          id: 'salon-card-test-1',
          name: 'Royal Cuts & Grooming Lounge',
          address: 'FC Road, Near Deccan Gymkhana',
          city: 'Pune',
          district: 'Pune',
          state: 'Maharashtra',
          distanceKm: 1.6,
          rating: 4.9,
          reviewCount: 142,
          ownerName: 'Rahul Sharma',
          isVerified: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SalonCard(
                salon: salon,
                isFavorite: false,
                onFavoriteTap: () {},
                onTap: () {},
                onJoinQueue: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Royal Cuts & Grooming Lounge'), findsAtLeast(1));
        expect(find.text('1.6 km away'), findsOneWidget);
        expect(find.text('Rahul Sharma'), findsOneWidget);
        expect(find.text('JOIN QUEUE'), findsOneWidget);
      },
    );

    testWidgets(
      'SalonDetailsScreen displays owner profile, service menu, and booking options',
      (tester) async {
        const salon = Salon(
          id: 'salon-details-test-1',
          name: 'Kalinga Cuts & Grooming Studio',
          address: 'Saheed Nagar, Janpath',
          city: 'Bhubaneswar',
          district: 'Khordha',
          state: 'Odisha',
          ownerName: 'Subhashish Das',
          distanceKm: 1.0,
          services: [
            SalonService(
              id: 's1',
              salonId: 'salon-details-test-1',
              name: 'Smart Cut & Wash',
              category: 'Hair',
              price: 150,
              durationMinutes: 20,
            ),
          ],
        );

        final authService = AuthService(null);

        await tester.pumpWidget(
          AuthScope(
            service: authService,
            child: const MaterialApp(home: SalonDetailsScreen(salon: salon)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kalinga Cuts & Grooming Studio'), findsAtLeast(1));
        expect(find.text('Join Live Queue'), findsOneWidget);

        // Scroll to services list
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();

        expect(find.text('Select Services'), findsOneWidget);
        expect(find.text('Smart Cut & Wash'), findsOneWidget);
        expect(find.text('₹150'), findsOneWidget);
      },
    );
  });
}
