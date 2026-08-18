import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../shared/models/salon.dart';
import '../../qr/services/qr_payload_service.dart';

/// Screen displaying the Salon's Counter QR Code for walk-in customer self-checkin.
/// Encodes an authentic, cryptographically signed SalonQueue JSON payload.
class SalonQrScreen extends StatelessWidget {
  const SalonQrScreen({super.key, required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrPayload = QrPayloadService.generateSalonQrPayload(
      salonId: salon.id,
      queueId: salon.id,
    );

    return Scaffold(
      backgroundColor: AppColorSchemes.ivory,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Store Counter QR Code',
          style: TextStyle(
            color: AppColorSchemes.charcoal,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColorSchemes.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text(
                salon.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColorSchemes.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Print & paste this official QR code at your counter so customers can scan and join your live queue instantly.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Printable QR Code Container Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: AppColorSchemes.gold, width: 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColorSchemes.navy,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.content_cut, color: AppColorSchemes.gold, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'SALON QUEUE',
                          style: TextStyle(
                            color: AppColorSchemes.navy,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Scannable Real QR Code Widget
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColorSchemes.navy,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColorSchemes.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Scan to Join Live Queue',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColorSchemes.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Official SalonQueue Verified Standee',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColorSchemes.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Share & Print Actions
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('QR Code Standee ready for printing & counter display.'),
                        backgroundColor: AppColorSchemes.available,
                      ),
                    );
                  },
                  icon: const Icon(Icons.print_rounded, color: AppColorSchemes.gold),
                  label: const Text(
                    'Print QR Code Standee',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColorSchemes.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
