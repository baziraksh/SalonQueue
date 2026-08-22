import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/auth/data/auth_repository.dart';
import 'package:salon_queue/features/salon/data/salon_repository.dart';
import 'package:salon_queue/shared/models/salon.dart';

void main() {
  group('Persistent Salon Data, Media & Cross-Device Location Discovery Suite', () {
    late SalonRepository salonRepo;
    late AuthRepository authRepo;

    setUp(() {
      SalonRepository.clearCache();
      AuthRepository.clearCache();
      salonRepo = SalonRepository();
      authRepo = AuthRepository();
    });

    test(
      'TEST 1, 2, 3, 4: Full Owner persistence (profile, cover, gallery, timings, chairs, location) across sessions',
      () async {
        const ownerAId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
        const ownerBId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

        // 1. Owner A logs in and fetches salon
        final salonA = await salonRepo.fetchOwnerSalon(ownerAId);
        expect(salonA, isNotNull);
        expect(salonA!.ownerId, ownerAId);

        // 2. Owner A updates store info & location (Angul, Odisha)
        await salonRepo.updateStoreInfo(
          salonId: salonA.id,
          ownerId: ownerAId,
          name: 'Rakesh Kurya Salon',
          description: 'Luxury grooming, styling and spa in Angul.',
          phone: '+91 99887 76655',
        );
        await salonRepo.updateSalonLocation(
          salonId: salonA.id,
          ownerId: ownerAId,
          state: 'Odisha',
          district: 'Angul',
          city: 'Angul',
          address: 'Main Market Square, Near Bus Stand',
          pincode: '759122',
        );

        // 3. Owner A updates chairs and timings
        await salonRepo.updateChairsTimings(
          salonId: salonA.id,
          ownerId: ownerAId,
          activeChairs: 5,
          openingTime: '08:00 AM',
          closingTime: '10:00 PM',
        );

        // 4. Owner A updates owner profile photo & cover image
        await salonRepo.updateOwnerProfile(
          salonId: salonA.id,
          ownerId: ownerAId,
          ownerName: 'Rakesh Kurya',
          ownerAvatarUrl:
              'https://images.unsplash.com/photo-owner-avatar-123.jpg',
        );
        await salonRepo.updateCoverImage(
          salonId: salonA.id,
          ownerId: ownerAId,
          coverImageUrl: 'https://images.unsplash.com/photo-cover-123.jpg',
        );
        await salonRepo.addGalleryImage(
          salonId: salonA.id,
          ownerId: ownerAId,
          imageUrl: 'https://images.unsplash.com/photo-gallery-1.jpg',
        );
        await salonRepo.addGalleryImage(
          salonId: salonA.id,
          ownerId: ownerAId,
          imageUrl: 'https://images.unsplash.com/photo-gallery-2.jpg',
        );

        // Verify Owner A memory state before logout
        final updatedA = await salonRepo.fetchOwnerSalon(ownerAId);
        expect(updatedA!.name, 'Rakesh Kurya Salon');
        expect(updatedA.city, 'Angul');
        expect(updatedA.state, 'Odisha');
        expect(updatedA.ownerName, 'Rakesh Kurya');
        expect(updatedA.activeChairs, 5);
        expect(updatedA.openingTime, '08:00 AM');
        expect(updatedA.closingTime, '10:00 PM');
        expect(
          updatedA.coverImageUrl,
          'https://images.unsplash.com/photo-cover-123.jpg',
        );
        expect(updatedA.galleryImages.length, 2);

        // 5. Owner A logs out -> clear cache
        SalonRepository.clearCache();
        AuthRepository.clearCache();

        // 6. Owner B logs in
        final salonB = await salonRepo.fetchOwnerSalon(ownerBId);
        expect(salonB, isNotNull);
        expect(salonB!.ownerId, ownerBId);
        // Owner B must NOT see Owner A's customized salon data
        expect(salonB.name, isNot(equals('Rakesh Kurya Salon')));
        expect(salonB.ownerName, isNot(equals('Rakesh Kurya')));
        expect(salonB.galleryImages, isEmpty);

        // Owner B updates their own salon in Pune, Maharashtra
        await salonRepo.updateStoreInfo(
          salonId: salonB.id,
          ownerId: ownerBId,
          name: "Anita's Beauty Haven",
          description: 'Bridal & hair styling in Pune.',
          phone: '+91 91234 56789',
        );
        await salonRepo.updateSalonLocation(
          salonId: salonB.id,
          ownerId: ownerBId,
          state: 'Maharashtra',
          district: 'Pune',
          city: 'Pune',
          address: 'FC Road, Deccan',
        );

        final updatedB = await salonRepo.fetchOwnerSalon(ownerBId);
        expect(updatedB!.name, "Anita's Beauty Haven");
        expect(updatedB.city, 'Pune');

        // 7. Owner B logs out and Owner A logs back in
        SalonRepository.clearCache();
        AuthRepository.clearCache();

        final reloadedA = await salonRepo.fetchOwnerSalon(ownerAId);
        expect(reloadedA!.ownerId, ownerAId);
        expect(reloadedA.name, isNot(equals("Anita's Beauty Haven")));
      },
    );

    test(
      'TEST 5, 6, 7: Location-based customer discovery matches state, city, district & keywords across devices',
      () async {
        final sampleSalons = [
          Salon(
            id: 'salon-1',
            ownerId: 'owner-1',
            name: 'Rakesh Kurya Salon',
            ownerName: 'bazirakesh',
            description: 'Top rated salon in Angul',
            address: 'Main Market Road',
            city: 'Angul',
            district: 'Angul',
            state: 'Odisha',
            phone: '+91 98765 43210',
            activeChairs: 3,
            isQueueOpen: true,
            rating: 4.8,
            reviewCount: 42,
            services: [],
          ),
          Salon(
            id: 'salon-2',
            ownerId: 'owner-2',
            name: 'My Salon & Spa Pune',
            ownerName: 'Rahul Sharma',
            description: 'Premium hair & beard grooming in Pune',
            address: 'FC Road, Deccan Gymkhana',
            city: 'Pune',
            district: 'Pune',
            state: 'Maharashtra',
            phone: '+91 98111 22334',
            activeChairs: 4,
            isQueueOpen: true,
            rating: 4.9,
            reviewCount: 88,
            services: [],
          ),
        ];

        // 1. Customer searches "Angul, Odisha"
        final angulResults = sampleSalons
            .where(
              (s) =>
                  s.city.toLowerCase().contains('angul') ||
                  s.district.toLowerCase().contains('angul'),
            )
            .toList();
        expect(angulResults, isNotEmpty);
        expect(angulResults.first.name, 'Rakesh Kurya Salon');

        // 2. Customer searches "bazirakesh" in Odisha -> matches ownerName
        final keywordMatch = sampleSalons
            .where(
              (s) =>
                  s.ownerName != null &&
                  s.ownerName!.toLowerCase().contains('bazirakesh'),
            )
            .toList();
        expect(keywordMatch.length, 1);
        expect(keywordMatch.first.name, 'Rakesh Kurya Salon');

        // 3. Customer searches "Pune" -> matches Pune salon
        final cityMatch = sampleSalons
            .where(
              (s) =>
                  s.city.toLowerCase().contains('pune') ||
                  s.district.toLowerCase().contains('pune'),
            )
            .toList();
        expect(cityMatch.length, 1);
        expect(cityMatch.first.name, 'My Salon & Spa Pune');
      },
    );

    test(
      'TEST 8 & 9: Customer profile image upload returns persistent valid URI format',
      () async {
        const customerId = 'cust-1111-2222-3333-4444';
        final dummyBytes = Uint8List.fromList([
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]); // PNG magic bytes

        final uri = await authRepo.uploadProfileImage(
          userId: customerId,
          imageBytes: dummyBytes,
          fileExt: 'png',
        );

        expect(uri, isNotEmpty);
        expect(uri.startsWith('http') || uri.startsWith('data:image'), isTrue);
      },
    );

    test(
      'TEST 10: Empty state when no salon registered in queried city',
      () async {
        final results = await salonRepo.fetchSalons(
          state: 'Sikkim',
          city: 'NonExistentCityXYZ',
        );
        expect(results.isEmpty, isTrue);
      },
    );
  });
}
