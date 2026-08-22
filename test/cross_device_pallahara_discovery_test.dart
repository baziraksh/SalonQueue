import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/salon/data/salon_repository.dart';
import 'package:salon_queue/shared/data/india_locations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SalonRepository.clearCache();
    SalonRepository.enableDiskPersistence = false;
  });

  group('Canonical Cross-Device Salon Discovery Tests (Pallahara / Odisha / Spa)', () {
    test(
      'Location normalization handles mixed case, whitespace and spacing identically',
      () {
        expect(
          SalonRepository.normalizeLocation(' Pallahara '),
          equals('pallahara'),
        );
        expect(
          SalonRepository.normalizeLocation('PALLAHARA'),
          equals('pallahara'),
        );
        expect(SalonRepository.normalizeLocation('Angul  '), equals('angul'));
        expect(
          SalonRepository.normalizeLocation(' Odisha  '),
          equals('odisha'),
        );
      },
    );

    test(
      'IndiaLocations correctly resolves Angul district for Pallahara village',
      () {
        final district = IndiaLocations.resolveDistrictForCity(
          'Pallahara',
          'Odisha',
        );
        expect(district, equals('Angul'));
      },
    );

    test(
      'Owner creates Spa in Pallahara, Customer searches Odisha/Angul/Pallahara with "spa" and discovers it',
      () async {
        final repo = SalonRepository();
        const ownerId = 'owner-pallahara-test-uuid';
        const salonId = 'salon-pallahara-test-uuid';

        // 1. Owner saves store info & location
        await repo.updateStoreInfo(
          salonId: salonId,
          ownerId: ownerId,
          name: 'Spa',
          description: 'Luxury Spa & Grooming in Pallahara',
          phone: '+91 98765 43210',
        );

        await repo.updateSalonLocation(
          salonId: salonId,
          ownerId: ownerId,
          state: 'Odisha',
          district: 'Angul',
          city: 'Pallahara',
          address: 'Pallahara Main Road',
          pincode: '759119',
          latitude: 21.4321,
          longitude: 85.1987,
        );

        await repo.updateChairsTimings(
          salonId: salonId,
          ownerId: ownerId,
          activeChairs: 3,
          openingTime: '09:00 AM',
          closingTime: '09:00 PM',
        );

        // 2. Customer performs search on another device instance with location filter
        final customerSalons = await repo.fetchSalons(
          state: 'Odisha',
          district: 'Angul',
          city: 'Pallahara',
          search: 'spa',
        );

        expect(
          customerSalons.isNotEmpty,
          isTrue,
          reason: 'Customer must discover Spa in Pallahara',
        );
        final discoveredSalon = customerSalons.first;
        expect(discoveredSalon.name, equals('Spa'));
        expect(discoveredSalon.state, equals('Odisha'));
        expect(discoveredSalon.district, equals('Angul'));
        expect(discoveredSalon.city, equals('Pallahara'));
        expect(discoveredSalon.address, equals('Pallahara Main Road'));
        expect(discoveredSalon.pincode, equals('759119'));
        expect(discoveredSalon.activeChairs, equals(3));
        expect(discoveredSalon.isQueueOpen, isTrue);

        // 3. Customer searches with lowercase 'pallahara' and mixed-case 'SPA'
        final caseInsensitiveSalons = await repo.fetchSalons(
          state: 'ODISHA',
          district: 'angul',
          city: 'PALLAHARA',
          search: 'SPA',
        );
        expect(caseInsensitiveSalons.isNotEmpty, isTrue);
        expect(caseInsensitiveSalons.first.name, equals('Spa'));
      },
    );

    test('Realtime queue toggle update reflects in salon discovery', () async {
      final repo = SalonRepository();
      const ownerId = 'owner-live-test';
      const salonId = 'salon-live-test';

      await repo.updateStoreInfo(
        salonId: salonId,
        ownerId: ownerId,
        name: 'Spa',
        description: 'Live Queue Test',
        phone: '+91 99999 11111',
      );

      await repo.updateSalonLocation(
        salonId: salonId,
        ownerId: ownerId,
        state: 'Odisha',
        district: 'Angul',
        city: 'Pallahara',
        address: 'Pallahara',
      );

      // Owner turns queue OFF
      await repo.setQueueStatus(salonId, false, ownerId: ownerId);
      final offlineFetch = await repo.fetchSalons(
        state: 'Odisha',
        city: 'Pallahara',
      );
      expect(offlineFetch.first.isQueueOpen, isFalse);

      // Owner turns queue ON and updates chairs to 5
      await repo.setQueueStatus(salonId, true, ownerId: ownerId);
      await repo.updateChairsTimings(
        salonId: salonId,
        ownerId: ownerId,
        activeChairs: 5,
        openingTime: '08:00 AM',
        closingTime: '10:00 PM',
      );

      final onlineFetch = await repo.fetchSalons(
        state: 'Odisha',
        city: 'Pallahara',
      );
      expect(onlineFetch.first.isQueueOpen, isTrue);
      expect(onlineFetch.first.activeChairs, equals(5));
    });
  });
}
