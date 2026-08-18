import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/salon/data/salon_repository.dart';
import 'package:salon_queue/features/salon/screens/chairs_timings_screen.dart';
import 'package:salon_queue/features/salon/screens/owner_profile_screen.dart';
import 'package:salon_queue/features/salon/screens/salon_location_screen.dart';
import 'package:salon_queue/features/salon/screens/store_info_screen.dart';
import 'package:salon_queue/features/auth/data/auth_repository.dart';
import 'package:salon_queue/features/auth/models/app_user.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/shared/models/salon.dart';

void main() {
  group('Salon Model & Gallery / Cover Image Serialization Tests', () {
    test('Salon fromJson and toJson preserves gallery and cover image', () {
      final json = {
        'id': 'test-salon-123',
        'name': 'Elite Styles Barbershop',
        'description': 'Modern salon',
        'address': 'MG Road',
        'city': 'Pune',
        'district': 'Pune',
        'state': 'Maharashtra',
        'cover_image_url': 'https://example.com/cover.jpg',
        'owner_avatar_url': 'https://example.com/avatar.jpg',
        'owner_name': 'Vikram Patel',
        'gallery_images': [
          'https://example.com/photo1.jpg',
          'https://example.com/photo2.jpg',
        ],
        'active_chairs': 4,
        'is_queue_open': true,
      };

      final salon = Salon.fromJson(json);
      expect(salon.name, equals('Elite Styles Barbershop'));
      expect(salon.effectiveCoverImage, equals('https://example.com/cover.jpg'));
      expect(salon.ownerAvatarUrl, equals('https://example.com/avatar.jpg'));
      expect(salon.ownerName, equals('Vikram Patel'));
      expect(salon.galleryImages.length, equals(2));
      expect(salon.galleryImages[0], equals('https://example.com/photo1.jpg'));

      final outJson = salon.toJson();
      expect(outJson['cover_image_url'], equals('https://example.com/cover.jpg'));
      expect(outJson['owner_avatar_url'], equals('https://example.com/avatar.jpg'));
      expect(outJson['gallery_images'], equals(['https://example.com/photo1.jpg', 'https://example.com/photo2.jpg']));
    });

    test('Salon copyWith correctly updates gallery and cover', () {
      final salon = Salon(
        id: 's1',
        name: 'Initial Name',
        address: 'Addr',
        city: 'City',
        galleryImages: ['img1.jpg'],
      );

      final updated = salon.copyWith(
        coverImageUrl: 'new_cover.jpg',
        galleryImages: ['img1.jpg', 'img2.jpg'],
        ownerName: 'Rahul',
      );

      expect(updated.coverImageUrl, equals('new_cover.jpg'));
      expect(updated.galleryImages.length, equals(2));
      expect(updated.ownerName, equals('Rahul'));
    });
  });

  group('SalonRepository Modular Update Tests', () {
    final repo = SalonRepository();
    const testId = '11111111-1111-1111-1111-111111111111';

    test('updateStoreInfo updates fallback salon', () async {
      await repo.updateStoreInfo(
        salonId: testId,
        name: 'Royal Cuts Updated',
        description: 'New Description',
        phone: '+91 99999 88888',
      );

      final salon = await repo.fetchSalonById(testId);
      expect(salon, isNotNull);
      expect(salon!.name, equals('Royal Cuts Updated'));
      expect(salon.description, equals('New Description'));
      expect(salon.phone, equals('+91 99999 88888'));
    });

    test('updateSalonLocation updates fallback salon address details', () async {
      await repo.updateSalonLocation(
        salonId: testId,
        state: 'Karnataka',
        district: 'Bengaluru Urban',
        city: 'Bengaluru',
        address: 'Indiranagar 100ft Rd',
        pincode: '560038',
      );

      final salon = await repo.fetchSalonById(testId);
      expect(salon, isNotNull);
      expect(salon!.state, equals('Karnataka'));
      expect(salon.district, equals('Bengaluru Urban'));
      expect(salon.city, equals('Bengaluru'));
      expect(salon.address, equals('Indiranagar 100ft Rd'));
      expect(salon.pincode, equals('560038'));
    });

    test('updateChairsTimings updates chairs and times', () async {
      await repo.updateChairsTimings(
        salonId: testId,
        activeChairs: 5,
        openingTime: '08:00 AM',
        closingTime: '10:00 PM',
      );

      final salon = await repo.fetchSalonById(testId);
      expect(salon, isNotNull);
      expect(salon!.activeChairs, equals(5));
      expect(salon.openingTime, equals('08:00 AM'));
      expect(salon.closingTime, equals('10:00 PM'));
    });

    test('updateCoverImage, addGalleryImage and removeGalleryImage work accurately', () async {
      await repo.updateCoverImage(
        salonId: testId,
        coverImageUrl: 'https://example.com/new_cover.jpg',
      );

      var salon = await repo.fetchSalonById(testId);
      expect(salon!.effectiveCoverImage, equals('https://example.com/new_cover.jpg'));

      await repo.addGalleryImage(
        salonId: testId,
        imageUrl: 'https://example.com/gallery1.jpg',
      );

      salon = await repo.fetchSalonById(testId);
      expect(salon!.galleryImages.contains('https://example.com/gallery1.jpg'), isTrue);

      await repo.removeGalleryImage(
        salonId: testId,
        imageUrl: 'https://example.com/gallery1.jpg',
      );

      salon = await repo.fetchSalonById(testId);
      expect(salon!.galleryImages.contains('https://example.com/gallery1.jpg'), isFalse);
    });
  });

  group('Dedicated Screen Rendering Tests', () {
    const testSalon = Salon(
      id: 'screen-test-salon',
      name: 'Royal Cuts Lounge',
      description: 'Luxury grooming',
      address: 'FC Road',
      city: 'Pune',
      district: 'Pune',
      state: 'Maharashtra',
      pincode: '411004',
      phone: '+91 98765 43210',
      activeChairs: 3,
      openingTime: '09:00 AM',
      closingTime: '09:00 PM',
      galleryImages: ['img_a.jpg', 'img_b.jpg'],
    );

    testWidgets('StoreInfoScreen renders basic fields and save button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StoreInfoScreen(salon: testSalon),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Store Information'), findsOneWidget);
      expect(find.text('Salon / Business Name *'), findsOneWidget);
      expect(find.text('Royal Cuts Lounge'), findsOneWidget);
      expect(find.text('Save Store Information'), findsOneWidget);
    });

    testWidgets('SalonLocationScreen renders state, district and city fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SalonLocationScreen(salon: testSalon),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Salon Location'), findsOneWidget);
      expect(find.text('State *'), findsOneWidget);
      expect(find.text('District *'), findsOneWidget);
      expect(find.text('Save Salon Location'), findsOneWidget);
    });

    testWidgets('ChairsTimingsScreen renders chairs and timings controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChairsTimingsScreen(salon: testSalon),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chairs & Timings'), findsOneWidget);
      expect(find.text('Active Chairs / Stylists *'), findsOneWidget);
      expect(find.text('Opening Time'), findsOneWidget);
      expect(find.text('Save Chairs & Timings'), findsOneWidget);
    });

    testWidgets('OwnerProfileScreen renders profile, cover, and gallery sections', (tester) async {
      const user = AppUser(id: 'test-owner', email: 'owner@salon.com', fullName: 'Rahul Sharma', role: AppRole.salonOwner);
      final authService = AuthService(_FakeAuthRepo(user));
      await tester.pumpWidget(
        AuthScope(
          service: authService,
          child: const MaterialApp(
            home: OwnerProfileScreen(salon: testSalon),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Owner Profile'), findsOneWidget);
      expect(find.text('SALON OWNER'), findsOneWidget);
      expect(find.text('Salon Cover Image'), findsOneWidget);
      expect(find.text('Salon Gallery'), findsOneWidget);
      expect(find.text('+ Add Photos'), findsOneWidget);
    });
  });
}

class _FakeAuthRepo extends AuthRepository {
  _FakeAuthRepo(this.user) : super();
  final AppUser user;
  @override
  Future<AppUser> signIn({required String email, required String password}) async => user;
}
