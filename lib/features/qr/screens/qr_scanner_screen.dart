import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../salon/data/salon_repository.dart';
import '../../salon/screens/salon_details_screen.dart';
import '../services/qr_payload_service.dart';

/// Real Camera QR Scanner screen for customers to scan salon counter QR code and join queue instantly.
/// Cryptographically validates SalonQueue QR payloads, rejects arbitrary/unrecognized QR codes,
/// and securely navigates to the verified salon.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final SalonRepository _salonRepo = SalonRepository();
  late MobileScannerController _scannerController;
  late AnimationController _laserController;

  bool _isProcessing = false;
  bool _hasScanned = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _scannerController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _scannerController.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _laserController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeCapture(BarcodeCapture capture) async {
    if (_isProcessing || _hasScanned) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    // Cryptographically validate the QR payload and verify against the database
    final result = await QrPayloadService.validateAndFetchSalon(
      rawContent: rawValue,
      salonRepo: _salonRepo,
    );

    if (!mounted) return;

    if (result.isValid && result.salon != null) {
      // Valid SalonQueue QR code! Stop camera and navigate to salon
      await _scannerController.stop();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SalonDetailsScreen(salon: result.salon!),
        ),
      );
    } else {
      // Invalid, tampered, or unknown QR code. Show error alert and resume scanner
      _showInvalidQrDialog(
        title: _getErrorTitle(result.status),
        message: result.errorMessage,
      );
    }
  }

  String _getErrorTitle(QrValidationStatus status) {
    switch (status) {
      case QrValidationStatus.unrecognizedApp:
      case QrValidationStatus.invalidFormat:
        return 'Invalid SalonQueue QR Code';
      case QrValidationStatus.invalidSignature:
        return 'Tampered QR Signature';
      case QrValidationStatus.salonNotFound:
        return 'Salon Not Registered';
      case QrValidationStatus.unsupportedVersion:
        return 'Update App Required';
      case QrValidationStatus.queueClosed:
        return 'Queue Paused';
      case QrValidationStatus.valid:
        return 'Success';
    }
  }

  void _showInvalidQrDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF4B5563),
            height: 1.4,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Cooldown before scanning again to avoid immediate re-trigger
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) {
                    setState(() {
                      _isProcessing = false;
                      _hasScanned = false;
                    });
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Scan Again',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const scanAreaSize = 265.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Real Device Camera Preview ──────────────────────────────
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcodeCapture,
            errorBuilder: (context, error, child) {
              return _buildPermissionErrorView(error);
            },
          ),

          // ── 2. Modern Dark Overlay with Rounded Cutout ─────────────────
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.60),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: const Alignment(0.0, -0.15),
                  child: Container(
                    width: scanAreaSize,
                    height: scanAreaSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 3. Modern Scanner Frame, Purple/Pink Corners & Laser ───────
          Align(
            alignment: const Alignment(0.0, -0.15),
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize,
              child: Stack(
                children: [
                  // Subtle Rounded Border
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF6D28D9).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),

                  // 4 Modern Vibrant Corner Markers
                  ..._buildCornerMarkers(),

                  // Animated Gradient Laser Scanning Line
                  AnimatedBuilder(
                    animation: _laserController,
                    builder: (context, _) {
                      return Align(
                        alignment: Alignment(
                          0.0,
                          (_laserController.value * 2) - 1,
                        ),
                        child: Container(
                          width: scanAreaSize - 16,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFFE91E63),
                                Colors.white,
                                Color(0xFF8B5CF6),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF8B5CF6,
                                ).withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Loading / Processing Overlay
                  if (_isProcessing)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF8B5CF6),
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Verifying Salon QR...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── 4. Top Clean Floating Header ───────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Circular Back Button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF111827),
                        size: 18,
                      ),
                    ),
                  ),

                  // Centered Title & Subtitle
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Scan salon counter QR to check-in',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),

                  // Action Controls (Torch & Camera Flip)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Torch Toggle Button
                      GestureDetector(
                        onTap: () {
                          _scannerController.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isTorchOn
                                ? const Color(0xFF6D28D9)
                                : Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isTorchOn
                                  ? const Color(0xFFA78BFA)
                                  : Colors.white30,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _isTorchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Camera Flip Button
                      GestureDetector(
                        onTap: () => _scannerController.switchCamera(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white30,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.flip_camera_ios_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── 5. Helper Instruction Badge Below Frame ────────────────────
          Align(
            alignment: const Alignment(0.0, 0.42),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFFA78BFA),
                    size: 17,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Align QR code inside the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 6. Bottom Information Card (Matches Home/Bookings Theme) ──
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Gradient Icon Container (Orange -> Pink -> Purple)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF5A1F), // Vibrant Orange
                          Color(0xFFE91E63), // Hot Pink
                          Color(0xFF6D28D9), // Purple
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Quick Salon Check-In',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Scan the official QR code at the salon reception to view services & join the live queue.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerMarkers() {
    const markerLength = 28.0;
    const markerThickness = 4.0;
    const cornerColor = Color(0xFF8B5CF6); // Vibrant Purple accent
    const borderRadius = 24.0;

    return [
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: markerLength,
          height: markerLength,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: cornerColor, width: markerThickness),
              left: BorderSide(color: cornerColor, width: markerThickness),
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(borderRadius),
            ),
          ),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: markerLength,
          height: markerLength,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: cornerColor, width: markerThickness),
              right: BorderSide(color: cornerColor, width: markerThickness),
            ),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(borderRadius),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: markerLength,
          height: markerLength,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cornerColor, width: markerThickness),
              left: BorderSide(color: cornerColor, width: markerThickness),
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(borderRadius),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: markerLength,
          height: markerLength,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cornerColor, width: markerThickness),
              right: BorderSide(color: cornerColor, width: markerThickness),
            ),
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(borderRadius),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildPermissionErrorView(MobileScannerException error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6D28D9).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                size: 54,
                color: Color(0xFFA78BFA),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Camera Access Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please allow camera permission to scan official Salon Queue counter QR codes.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _scannerController.start();
              },
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Allow Camera Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
