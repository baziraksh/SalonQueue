import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/color_schemes.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColorSchemes.busy.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColorSchemes.busy,
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
                  color: AppColorSchemes.charcoal,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
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
                backgroundColor: AppColorSchemes.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Scan Again',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const scanAreaSize = 260.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColorSchemes.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          children: [
            Text(
              'Scan Salon QR Code',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              'Scan a salon QR code to check in',
              style: TextStyle(fontSize: 11, color: AppColorSchemes.goldLight),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? AppColorSchemes.gold : Colors.white70,
            ),
            tooltip: 'Toggle Flashlight',
            onPressed: () {
              _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.flip_camera_ios_rounded,
              color: Colors.white70,
              size: 20,
            ),
            tooltip: 'Switch Camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
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

          // ── 2. Semi-translucent Overlay with Cutout ────────────────────
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.65),
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
                  alignment: const Alignment(0.0, -0.2),
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

          // ── 3. Premium Scanner Frame, Corner Marks & Laser ─────────────
          Align(
            alignment: const Alignment(0.0, -0.2),
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize,
              child: Stack(
                children: [
                  // Outer Gold Border with Rounded Corners
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColorSchemes.gold.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  ),

                  // 4 Corner Markers
                  ..._buildCornerMarkers(),

                  // Animated Laser Scanning Line
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
                                AppColorSchemes.gold,
                                Colors.white,
                                AppColorSchemes.gold,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColorSchemes.gold.withValues(
                                  alpha: 0.8,
                                ),
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
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppColorSchemes.gold,
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Verifying Salon QR...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
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

          // ── 4. Instructions Below Frame ────────────────────────────────
          Align(
            alignment: const Alignment(0.0, 0.38),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColorSchemes.gold,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Align the QR code inside the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 5. Bottom Rounded Information Card ─────────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColorSchemes.gold.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColorSchemes.navy,
                          AppColorSchemes.navyLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColorSchemes.gold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Quick Store Check-in',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColorSchemes.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Scan an official SalonQueue counter QR code to join the live queue.',
                          style: TextStyle(
                            fontSize: 11,
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
    const markerLength = 26.0;
    const markerThickness = 4.0;
    const cornerColor = AppColorSchemes.gold;
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
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                size: 54,
                color: AppColorSchemes.gold,
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
                backgroundColor: AppColorSchemes.gold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
