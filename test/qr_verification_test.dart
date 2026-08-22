import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_queue/features/qr/services/qr_payload_service.dart';
import 'package:salon_queue/features/salon/data/salon_repository.dart';

void main() {
  late SalonRepository salonRepo;

  setUp(() async {
    salonRepo = SalonRepository();
    await salonRepo.updateSalonLocation(
      salonId: '11111111-1111-1111-1111-111111111111',
      ownerId: 'owner-1',
      state: 'Maharashtra',
      district: 'Pune',
      city: 'Pune',
      address: 'FC Road',
      pincode: '411004',
      latitude: 18.5196,
      longitude: 73.8413,
    );
    await salonRepo.updateStoreInfo(
      salonId: '11111111-1111-1111-1111-111111111111',
      ownerId: 'owner-1',
      name: 'Royal Cuts & Grooming Lounge',
      description: 'Luxury grooming',
      phone: '+91 98765 43210',
    );

    await salonRepo.updateSalonLocation(
      salonId: '22222222-2222-2222-2222-222222222222',
      ownerId: 'owner-2',
      state: 'Maharashtra',
      district: 'Pune',
      city: 'Pune',
      address: 'Koregaon Park',
      pincode: '411001',
      latitude: 18.5362,
      longitude: 73.8940,
    );
    await salonRepo.updateStoreInfo(
      salonId: '22222222-2222-2222-2222-222222222222',
      ownerId: 'owner-2',
      name: 'Scissors & Combs Unisex Studio',
      description: 'Trendy unisex studio',
      phone: '+91 98234 56789',
    );
  });

  group('SalonQueue QR Verification Suite', () {
    test(
      'TEST 1: Owner generates SalonQueue QR -> User scans it -> VALID',
      () async {
        const salonId = '11111111-1111-1111-1111-111111111111'; // Royal Cuts
        final rawQr = QrPayloadService.generateSalonQrPayload(salonId: salonId);

        final result = await QrPayloadService.validateAndFetchSalon(
          rawContent: rawQr,
          salonRepo: salonRepo,
        );

        expect(result.isValid, isTrue);
        expect(result.status, QrValidationStatus.valid);
        expect(result.salonId, salonId);
        expect(result.salon, isNotNull);
        expect(result.salon!.name, contains('Royal Cuts'));
      },
    );

    test(
      'TEST 2: User scans unrelated QR (UPI, Wi-Fi, WhatsApp) -> INVALID -> rejected',
      () async {
        const upiQr = 'upi://pay?pa=salon@okhdfcbank&pn=RoyalCuts&am=500';
        const wifiQr = 'WIFI:S:MySalonWifi;T:WPA;P:secret123;;';
        const whatsappQr = 'https://wa.me/919876543210?text=Hello';

        final resUpi = await QrPayloadService.validateAndFetchSalon(
          rawContent: upiQr,
          salonRepo: salonRepo,
        );
        final resWifi = await QrPayloadService.validateAndFetchSalon(
          rawContent: wifiQr,
          salonRepo: salonRepo,
        );
        final resWa = await QrPayloadService.validateAndFetchSalon(
          rawContent: whatsappQr,
          salonRepo: salonRepo,
        );

        expect(resUpi.isValid, isFalse);
        expect(resUpi.status, QrValidationStatus.unrecognizedApp);

        expect(resWifi.isValid, isFalse);
        expect(resWifi.status, QrValidationStatus.unrecognizedApp);

        expect(resWa.isValid, isFalse);
        expect(resWa.status, QrValidationStatus.unrecognizedApp);
      },
    );

    test(
      'TEST 3: User scans random website URL QR -> INVALID -> rejected',
      () async {
        const googleUrl = 'https://www.google.com';
        const randomUrl = 'https://example.com/salon/11111111-1111';

        final resGoogle = await QrPayloadService.validateAndFetchSalon(
          rawContent: googleUrl,
          salonRepo: salonRepo,
        );
        final resRandom = await QrPayloadService.validateAndFetchSalon(
          rawContent: randomUrl,
          salonRepo: salonRepo,
        );

        expect(resGoogle.isValid, isFalse);
        expect(resGoogle.status, QrValidationStatus.unrecognizedApp);

        expect(resRandom.isValid, isFalse);
        expect(resRandom.status, QrValidationStatus.unrecognizedApp);
      },
    );

    test(
      'TEST 4: User scans modified/tampered/fake SalonQueue payload -> INVALID -> rejected',
      () async {
        // Create a payload with altered salonId without updating the signature
        final fakePayload = {
          'type': 'SALONQUEUE_SALON',
          'version': 1,
          'salonId': '22222222-2222-2222-2222-222222222222',
          'queueId': '22222222-2222-2222-2222-222222222222',
          'signature': 'invalid_fake_or_tampered_signature_12345',
        };

        final result = await QrPayloadService.validateAndFetchSalon(
          rawContent: jsonEncode(fakePayload),
          salonRepo: salonRepo,
        );

        expect(result.isValid, isFalse);
        expect(result.status, QrValidationStatus.invalidSignature);
      },
    );

    test(
      'TEST 5: Two different SalonQueue salons have different QR codes -> open corresponding salon',
      () async {
        const salonId1 = '11111111-1111-1111-1111-111111111111'; // Royal Cuts
        const salonId2 =
            '22222222-2222-2222-2222-222222222222'; // Scissors & Combs

        final qr1 = QrPayloadService.generateSalonQrPayload(salonId: salonId1);
        final qr2 = QrPayloadService.generateSalonQrPayload(salonId: salonId2);

        expect(qr1, isNot(equals(qr2)));

        final res1 = await QrPayloadService.validateAndFetchSalon(
          rawContent: qr1,
          salonRepo: salonRepo,
        );
        final res2 = await QrPayloadService.validateAndFetchSalon(
          rawContent: qr2,
          salonRepo: salonRepo,
        );

        expect(res1.isValid, isTrue);
        expect(res1.salon!.id, salonId1);
        expect(res1.salon!.name, contains('Royal Cuts'));

        expect(res2.isValid, isTrue);
        expect(res2.salon!.id, salonId2);
        expect(res2.salon!.name, contains('Scissors & Combs'));
      },
    );

    test(
      'TEST 6: Expired/inactive/non-existent salon QR -> rejected',
      () async {
        const ghostSalonId = '00000000-0000-0000-0000-000000000000';
        final rawGhostQr = QrPayloadService.generateSalonQrPayload(
          salonId: ghostSalonId,
        );

        final result = await QrPayloadService.validateAndFetchSalon(
          rawContent: rawGhostQr,
          salonRepo: salonRepo,
        );

        expect(result.isValid, isFalse);
        expect(result.status, QrValidationStatus.salonNotFound);
        expect(result.errorMessage, contains('Salon not found'));
      },
    );
  });
}
