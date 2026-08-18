import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../shared/models/salon.dart';
import '../../salon/data/salon_repository.dart';

/// Validation status enum for QR scanning.
enum QrValidationStatus {
  valid,
  invalidFormat,
  unrecognizedApp,
  unsupportedVersion,
  invalidSignature,
  salonNotFound,
  queueClosed,
}

/// Result object returned by QR validation.
class QrValidationResult {
  final QrValidationStatus status;
  final String? salonId;
  final String? queueId;
  final Salon? salon;
  final String errorMessage;

  const QrValidationResult._({
    required this.status,
    this.salonId,
    this.queueId,
    this.salon,
    this.errorMessage = '',
  });

  bool get isValid => status == QrValidationStatus.valid && salon != null;

  factory QrValidationResult.valid({
    required String salonId,
    required String queueId,
    required Salon salon,
  }) {
    return QrValidationResult._(
      status: QrValidationStatus.valid,
      salonId: salonId,
      queueId: queueId,
      salon: salon,
    );
  }

  factory QrValidationResult.invalidFormat([String? customMessage]) {
    return QrValidationResult._(
      status: QrValidationStatus.invalidFormat,
      errorMessage: customMessage ??
          'Invalid QR Code format. Please scan a valid SalonQueue QR code.',
    );
  }

  factory QrValidationResult.unrecognizedApp() {
    return const QrValidationResult._(
      status: QrValidationStatus.unrecognizedApp,
      errorMessage:
          'This QR code is not a valid SalonQueue salon code. Please scan the QR displayed by the salon.',
    );
  }

  factory QrValidationResult.unsupportedVersion() {
    return const QrValidationResult._(
      status: QrValidationStatus.unsupportedVersion,
      errorMessage:
          'Unsupported QR version. Please update your SalonQueue app to the latest version.',
    );
  }

  factory QrValidationResult.invalidSignature() {
    return const QrValidationResult._(
      status: QrValidationStatus.invalidSignature,
      errorMessage:
          'Invalid or tampered SalonQueue QR code signature. Verification failed.',
    );
  }

  factory QrValidationResult.salonNotFound() {
    return const QrValidationResult._(
      status: QrValidationStatus.salonNotFound,
      errorMessage:
          'Salon not found in the SalonQueue network. Please check with the salon manager.',
    );
  }

  factory QrValidationResult.queueClosed({required Salon salon}) {
    return QrValidationResult._(
      status: QrValidationStatus.queueClosed,
      salon: salon,
      salonId: salon.id,
      errorMessage:
          '${salon.name}\'s queue is currently paused or closed. Please ask the front desk to resume the queue.',
    );
  }
}

/// Service for generating and cryptographically verifying structured SalonQueue QR payloads.
class QrPayloadService {
  static const String qrTypePrimary = 'SALONQUEUE_SALON';
  static const String qrTypeSecondary = 'SALONSPOT_SALON';
  static const int currentVersion = 1;

  // Secret signing key for authenticating SalonQueue QR payloads
  static const String _signingSecret = 'SalonQueue_Secured_Token_v1_2026';

  /// Computes HMAC-SHA256 signature for a salon QR payload.
  static String computeSignature({
    required String type,
    required int version,
    required String salonId,
    required String queueId,
  }) {
    final key = utf8.encode(_signingSecret);
    final data = utf8.encode('$type:$version:$salonId:$queueId');
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(data);
    return digest.toString();
  }

  /// Generates a structured JSON QR code payload for a salon.
  static String generateSalonQrPayload({
    required String salonId,
    String? queueId,
    String type = qrTypePrimary,
  }) {
    final effectiveQueueId = queueId ?? salonId;
    final signature = computeSignature(
      type: type,
      version: currentVersion,
      salonId: salonId,
      queueId: effectiveQueueId,
    );

    final payloadMap = {
      'type': type,
      'version': currentVersion,
      'salonId': salonId,
      'queueId': effectiveQueueId,
      'signature': signature,
    };

    return jsonEncode(payloadMap);
  }

  /// Extracts salon ID from various supported QR formats:
  /// - URI: `salonqueue://salon/{salon_id}` or `salonqueue://queue/{salon_id}`
  /// - JSON: `{"type": "salon", "salon_id": "..."}`, `{"salonId": "..."}`, `{"type": "SALONQUEUE_SALON", ...}`
  /// - Plain canonical UUID/ID string
  static String? extractSalonId(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) return null;

    // 1. Check deep link URL: salonqueue://salon/{salon_id}
    if (trimmed.startsWith('salonqueue://') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        if (uri.scheme == 'salonqueue') {
          if (uri.host == 'salon' || uri.host == 'queue') {
            final seg = uri.pathSegments;
            if (seg.isNotEmpty) return seg.first;
            final queryId = uri.queryParameters['salon_id'] ??
                uri.queryParameters['salonId'] ??
                uri.queryParameters['id'];
            if (queryId != null && queryId.isNotEmpty) return queryId;
          }
          if (uri.pathSegments.isNotEmpty) {
            final idx = uri.pathSegments.indexOf('salon');
            if (idx != -1 && idx + 1 < uri.pathSegments.length) {
              return uri.pathSegments[idx + 1];
            }
            return uri.pathSegments.last;
          }
        } else if (uri.pathSegments.contains('salon')) {
          final idx = uri.pathSegments.indexOf('salon');
          if (idx != -1 && idx + 1 < uri.pathSegments.length) {
            return uri.pathSegments[idx + 1];
          }
        }
      } catch (_) {}
    }

    // 2. Check structured JSON format
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final id = decoded['salonId'] ??
              decoded['salon_id'] ??
              decoded['id'] ??
              decoded['queueId'] ??
              decoded['queue_id'];
          if (id != null && id.toString().trim().isNotEmpty) {
            return id.toString().trim();
          }
        }
      } catch (_) {}
    }

    // 3. Check plain UUID format (36 chars) or alphanumeric ID
    if (RegExp(r'^[a-zA-Z0-9_-]{4,64}$').hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  /// Validates raw QR code content and verifies with the database/repository.
  static Future<QrValidationResult> validateAndFetchSalon({
    required String rawContent,
    required SalonRepository salonRepo,
    bool checkQueueOpen = false,
  }) async {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) {
      return QrValidationResult.invalidFormat();
    }

    String? targetSalonId;

    // 1. Check if payload is structured JSON
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final type = decoded['type']?.toString();

          // A) If signed SalonQueue QR payload
          if (type == qrTypePrimary || type == qrTypeSecondary) {
            final version = decoded['version'];
            if (version != currentVersion) {
              return QrValidationResult.unsupportedVersion();
            }

            final salonId = decoded['salonId']?.toString().trim() ??
                decoded['salon_id']?.toString().trim();
            final queueId = (decoded['queueId'] ?? decoded['queue_id'] ?? salonId)
                ?.toString()
                .trim();
            final signature = decoded['signature']?.toString().trim();

            if (salonId == null || salonId.isEmpty || queueId == null || queueId.isEmpty) {
              return QrValidationResult.invalidFormat('Missing salon identifier in QR code.');
            }

            if (signature == null || signature.isEmpty) {
              return QrValidationResult.invalidSignature();
            }

            final expectedSignature = computeSignature(
              type: type!,
              version: version as int,
              salonId: salonId,
              queueId: queueId,
            );

            if (signature != expectedSignature) {
              return QrValidationResult.invalidSignature();
            }

            targetSalonId = salonId;
          } else if (type == 'salon' || type == 'queue' || decoded.containsKey('salon_id') || decoded.containsKey('salonId')) {
            // B) Standard JSON payload: {"type": "salon", "salon_id": "..."}
            targetSalonId = decoded['salon_id']?.toString().trim() ??
                decoded['salonId']?.toString().trim() ??
                decoded['id']?.toString().trim();
          } else {
            return QrValidationResult.unrecognizedApp();
          }
        }
      } catch (_) {
        return QrValidationResult.unrecognizedApp();
      }
    }

    // 2. Check deep link: salonqueue://salon/{salon_id}
    if (targetSalonId == null && trimmed.startsWith('salonqueue://')) {
      try {
        final uri = Uri.parse(trimmed);
        if (uri.host == 'salon' || uri.host == 'queue') {
          if (uri.pathSegments.isNotEmpty) {
            targetSalonId = uri.pathSegments.first;
          } else {
            targetSalonId = uri.queryParameters['salon_id'] ??
                uri.queryParameters['salonId'] ??
                uri.queryParameters['id'];
          }
        } else if (uri.pathSegments.isNotEmpty) {
          final idx = uri.pathSegments.indexOf('salon');
          if (idx != -1 && idx + 1 < uri.pathSegments.length) {
            targetSalonId = uri.pathSegments[idx + 1];
          } else {
            targetSalonId = uri.pathSegments.last;
          }
        }
      } catch (_) {}
    }

    if (targetSalonId == null || targetSalonId.isEmpty) {
      return QrValidationResult.unrecognizedApp();
    }

    // 3. Query Supabase / Database to ensure Salon exists
    try {
      final salon = await salonRepo.fetchSalonById(targetSalonId);
      if (salon == null) {
        return QrValidationResult.salonNotFound();
      }

      // Check if queue is open
      if (checkQueueOpen && !salon.isQueueOpen) {
        return QrValidationResult.queueClosed(salon: salon);
      }

      return QrValidationResult.valid(
        salonId: salon.id,
        queueId: salon.id,
        salon: salon,
      );
    } catch (e) {
      return QrValidationResult.invalidFormat('Failed to verify salon: $e');
    }
  }
}
