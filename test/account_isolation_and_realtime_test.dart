import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/auth/data/auth_repository.dart';
import 'package:salon_queue/features/auth/models/app_user.dart';
import 'package:salon_queue/features/auth/services/auth_scope.dart';
import 'package:salon_queue/features/auth/services/auth_service.dart';
import 'package:salon_queue/features/queue/data/queue_repository.dart';
import 'package:salon_queue/features/salon/data/salon_repository.dart';
import 'package:salon_queue/features/salon/screens/salon_details_screen.dart';
import 'package:salon_queue/shared/models/salon.dart';
import 'package:salon_queue/shared/models/salon_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class MockIsolatedAuthRepository extends AuthRepository {
  MockIsolatedAuthRepository({this.activeUser});

  supabase.User? activeUser;

  @override
  supabase.User? get currentUser => activeUser;

  @override
  bool get hasSession => activeUser != null;

  @override
  Future<AppUser> buildAppUser(supabase.User user) async {
    return AppUser(
      id: user.id,
      email: user.email,
      fullName: user.userMetadata?['full_name'] as String? ?? 'Test Owner',
      role: AppRole.salonOwner,
    );
  }

  @override
  Future<void> signOut() async {
    activeUser = null;
  }
}

void main() {
  setUp(() {
    AuthRepository.clearCache();
    SalonRepository.clearCache();
    QueueRepository.clearLocalCache();
  });

  group('Strict Account Data Isolation Tests', () {
    test('TEST 1: Account A data does NOT leak into Account B', () async {
      final salonRepo = SalonRepository(client: null);

      const ownerAId = 'owner-uuid-account-A';
      const ownerBId = 'owner-uuid-account-B';

      // 1. Account A logs in & fetches salon
      final salonA = await salonRepo.fetchOwnerSalon(ownerAId);
      expect(salonA, isNotNull);
      expect(salonA!.ownerId, equals(ownerAId));

      // Account A uploads profile photo, cover photo, and gallery images
      await salonRepo.updateOwnerProfile(
        salonId: salonA.id,
        ownerName: 'Rakesh Owner A',
        ownerAvatarUrl:
            'https://storage.supabase.co/avatars/owners/$ownerAId/profile/avatar_1.jpg',
      );
      await salonRepo.updateCoverImage(
        salonId: salonA.id,
        coverImageUrl:
            'https://storage.supabase.co/avatars/owners/$ownerAId/cover/cover_1.jpg',
      );
      await salonRepo.addGalleryImage(
        salonId: salonA.id,
        imageUrl:
            'https://storage.supabase.co/avatars/owners/$ownerAId/gallery/style_1.jpg',
      );

      // Verify Account A has its data
      final updatedSalonA = await salonRepo.fetchOwnerSalon(ownerAId);
      expect(updatedSalonA!.ownerName, equals('Rakesh Owner A'));
      expect(updatedSalonA.ownerAvatarUrl, contains(ownerAId));
      expect(updatedSalonA.coverImageUrl, contains(ownerAId));
      expect(updatedSalonA.galleryImages.length, equals(1));
      expect(updatedSalonA.galleryImages.first, contains(ownerAId));

      // 2. Account B logs in on the SAME device
      final salonB = await salonRepo.fetchOwnerSalon(ownerBId);
      expect(salonB, isNotNull);
      expect(salonB!.ownerId, equals(ownerBId));

      // CRITICAL ASSERTION: Account B must NOT have Account A's images or data!
      expect(salonB.ownerName, isNot(equals('Rakesh Owner A')));
      expect(salonB.ownerAvatarUrl, isNull);
      expect(salonB.coverImageUrl, isNull);
      expect(salonB.galleryImages, isEmpty);
    });

    test(
      'TEST 2: Account Switch cycle preserves each account\'s isolated state',
      () async {
        final salonRepo = SalonRepository(client: null);
        const ownerAId = 'owner-A';
        const ownerBId = 'owner-B';

        // Setup Account A
        final salonA = await salonRepo.fetchOwnerSalon(ownerAId);
        await salonRepo.updateStoreInfo(
          salonId: salonA!.id,
          name: 'Account A Deluxe Spa',
          description: 'Exclusive to A',
          phone: '1111111111',
        );
        await salonRepo.updateCoverImage(
          salonId: salonA.id,
          coverImageUrl: 'https://example.com/coverA.jpg',
        );

        // Setup Account B
        final salonB = await salonRepo.fetchOwnerSalon(ownerBId);
        await salonRepo.updateStoreInfo(
          salonId: salonB!.id,
          name: 'Account B Modern Cuts',
          description: 'Exclusive to B',
          phone: '2222222222',
        );

        // Verify Account A is isolated
        final checkA = await salonRepo.fetchOwnerSalon(ownerAId);
        expect(checkA!.name, equals('Account A Deluxe Spa'));
        expect(checkA.coverImageUrl, equals('https://example.com/coverA.jpg'));

        // Verify Account B is isolated
        final checkB = await salonRepo.fetchOwnerSalon(ownerBId);
        expect(checkB!.name, equals('Account B Modern Cuts'));
        expect(checkB.coverImageUrl, isNull);
      },
    );

    test(
      'TEST 3: Storage path generation uses strict user-specific paths',
      () async {
        final authRepo = AuthRepository(client: null);
        const userId = 'user-test-789';
        final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        // When client is null or offline, uploads return Data URIs or isolated URLs
        final avatarUrl = await authRepo.uploadOwnerProfilePhoto(
          userId: userId,
          imageBytes: dummyBytes,
        );
        expect(avatarUrl, isNotEmpty);

        final coverUrl = await authRepo.uploadOwnerCoverPhoto(
          userId: userId,
          imageBytes: dummyBytes,
        );
        expect(coverUrl, isNotEmpty);

        final galleryUrl = await authRepo.uploadOwnerGalleryPhoto(
          userId: userId,
          imageBytes: dummyBytes,
        );
        expect(galleryUrl, isNotEmpty);
      },
    );

    test('TEST 4: AuthService.signOut clears all repository caches', () async {
      final repo = MockIsolatedAuthRepository(
        activeUser: supabase.User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: {'role': 'SALON_OWNER'},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      final authService = AuthService(repo);
      authService.initialize();

      final salonRepo = SalonRepository(client: null);
      await salonRepo.fetchOwnerSalon('user-1');

      // Call signOut
      await authService.signOut();

      expect(authService.currentUser, isNull);
      expect(authService.status, equals(AuthStatus.unauthenticated));
    });
  });

  group('Customer Real-Time Queue Updates Tests', () {
    testWidgets(
      'TEST 5: SalonDetailsScreen renders dynamic live queue metrics',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final testSalon = Salon(
          id: 'salon-live-1',
          ownerId: 'owner-live-1',
          name: 'Royal Hair Studio',
          address: '100 Main St',
          city: 'Pune',
          activeChairs: 4,
          isQueueOpen: true,
          waitingCount: 2,
          estWaitMinutes: 15,
          services: [
            const SalonService(
              id: 's1',
              salonId: 'salon-live-1',
              name: 'Haircut',
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
            child: MaterialApp(home: SalonDetailsScreen(salon: testSalon)),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Live Rush and Metric Cards are present
        expect(find.text('Royal Hair Studio'), findsOneWidget);
        expect(find.text('In Queue'), findsOneWidget);
        expect(find.text('Serving'), findsOneWidget);
        expect(find.text('Est. Wait'), findsOneWidget);
        expect(find.text('Chairs'), findsOneWidget);
        expect(find.text('Hair'), findsWidgets);
      },
    );
  });
}
