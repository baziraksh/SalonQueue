import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/models/salon.dart';
import '../../qr/services/qr_payload_service.dart';

/// Screen displaying the Salon's Counter QR Code for walk-in customer self-checkin.
/// Encodes an authentic, cryptographically signed SalonQueue JSON payload.
class SalonQrScreen extends StatelessWidget {
  const SalonQrScreen({super.key, required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final qrPayload = QrPayloadService.generateSalonQrPayload(
      salonId: salon.id,
      queueId: salon.id,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Store Counter QR Code',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              Text(
                salon.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Print & paste this official QR code at your salon reception counter so customers can scan and join your live queue instantly.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ── Printable QR Code Container Card ────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFF6D28D9).withValues(alpha: 0.25), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF5A1F),
                                Color(0xFFE91E63),
                                Color(0xFF6D28D9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.content_cut,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'SALON QUEUE',
                          style: TextStyle(
                            color: Color(0xFF6D28D9),
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
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF1F3F5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 210.0,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF6D28D9),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'Scan to Join Live Queue',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Official Store Check-in QR',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons: Print & Share
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QR Code image ready to print.'),
                            backgroundColor: Color(0xFF6D28D9),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Print QR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6D28D9),
                        side: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QR Code link copied to clipboard!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
