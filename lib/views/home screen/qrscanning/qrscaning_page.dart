import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/views/home%20screen/qrscanning/machinelist_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isScanned = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isScanned || _isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isScanned = true;
      _isProcessing = true;
    });

    debugPrint('QR Code Scanned: $code');

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          );
        },
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final mobile = prefs.getString('user_mobile');
      final sessionToken = prefs.getString('session_token');

      debugPrint('User Mobile: $mobile');
      debugPrint('Session Token: ${sessionToken?.substring(0, 10)}...');

      if (mobile == null || mobile.isEmpty) {
        throw Exception('Mobile number not found. Please login again.');
      }

      if (sessionToken == null || sessionToken.isEmpty) {
        throw Exception('Session token not found. Please login again.');
      }

      if (sessionToken.length < 6) {
        throw Exception('Invalid session token. Please login again.');
      }

      debugPrint('Calling API with Hub ID: $code');

      final hubDetails = await HomeApi.getHubDetails(hubId: code);

      debugPrint('API Response: ${hubDetails.length} devices found');

      if (mounted) {
        Navigator.pop(context);
      }

      if (hubDetails.isEmpty) {
        _showErrorSnackBar('No devices found for this hub');
        setState(() {
          _isScanned = false;
          _isProcessing = false;
        });
        return;
      }

      final String hubName = hubDetails[0]['hubname'] ?? 'Unknown Hub';

      debugPrint('Hub Name: $hubName');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MachineListPage(
              hubId: code,
              hubName: hubName,
              devices: hubDetails,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }

      String errorMessage = 'Failed to fetch hub details';

      if (e.toString().contains('401')) {
        errorMessage = 'Session expired. Please login again.';
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('session_token');
        await prefs.remove('user_mobile');

        if (mounted) {
          Navigator.pop(context);
          _showErrorDialog(
            'Authentication Required',
            'Your session has expired. Please login again.',
          );
          return;
        }
      } else if (e.toString().contains('404')) {
        errorMessage = 'Hub not found. Please scan a valid QR code.';
      } else if (e.toString().contains('not authenticated') ||
          e.toString().contains('not found')) {
        errorMessage = 'Please login again to continue.';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        errorMessage = 'Network error. Check your connection.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }

      _showErrorSnackBar(errorMessage);
      debugPrint('QR Scan Error: $e');

      setState(() {
        _isScanned = false;
        _isProcessing = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: cameraController, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  _buildCornerBracket(Alignment.topLeft, true, true),
                  _buildCornerBracket(Alignment.topRight, true, false),
                  _buildCornerBracket(Alignment.bottomLeft, false, true),
                  _buildCornerBracket(Alignment.bottomRight, false, false),
                  if (!_isScanned) const AnimatedScanLine(),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Scan QR Code to view Hub details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerBracket(Alignment alignment, bool isTop, bool isLeft) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? const BorderSide(color: Colors.black, width: 4)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Colors.black, width: 4)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: Colors.black, width: 4)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Colors.black, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class AnimatedScanLine extends StatefulWidget {
  const AnimatedScanLine({super.key});

  @override
  State<AnimatedScanLine> createState() => _AnimatedScanLineState();
}

class _AnimatedScanLineState extends State<AnimatedScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          left: 0,
          right: 0,
          top: _animation.value * 245,
          child: Container(height: 2, color: Colors.black),
        );
      },
    );
  }
}