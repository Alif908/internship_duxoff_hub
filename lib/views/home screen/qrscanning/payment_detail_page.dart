import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/views/home%20screen/qrscanning/paymentsuccessfull_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentDetailsPage extends StatefulWidget {
  final String hubName;
  final String hubId;
  final int deviceId;
  final String machineId;
  final String washType;
  final String washMode;
  final String washTime;
  final String detergent;
  final bool detergentEnabled;
  final double totalPrice;

  const PaymentDetailsPage({
    super.key,
    required this.hubName,
    required this.hubId,
    required this.deviceId,
    required this.machineId,
    required this.washType,
    required this.washMode,
    required this.washTime,
    required this.detergent,
    required this.detergentEnabled,
    required this.totalPrice,
  });

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  // Calculate individual prices based on selections
  Map<String, double> _calculatePriceBreakdown() {
    double basePrice = 50.0;
    double washModePrice = 0.0;
    double washTimePrice = 0.0;
    double detergentPrice = 0.0;

    // Wash mode pricing
    if (widget.washMode == 'Steam') {
      washModePrice = 25.0;
    } else if (widget.washMode == 'Custom') {
      washModePrice = 35.0;
    }

    // Wash time pricing
    if (widget.washTime == '30 Min') {
      washTimePrice = 20.0;
    } else if (widget.washTime == '45 Min') {
      washTimePrice = 40.0;
    }

    // Detergent pricing
    if (widget.detergentEnabled) {
      detergentPrice = 15.0;
    }

    return {
      'base': basePrice,
      'washMode': washModePrice,
      'washTime': washTimePrice,
      'detergent': detergentPrice,
    };
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _calculatePriceBreakdown();
    final baseWashPrice =
        breakdown['base']! + breakdown['washMode']! + breakdown['washTime']!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mode & Payment details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Machine ID
            const Text(
              'Machine ID',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.machineId,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),

            // Table Header
            Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'No. of wash',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Type of Wash',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Wash Mode Row
            Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    '1x',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '${widget.washMode} Wash (${widget.washTime})',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    baseWashPrice.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Detergent Row (only if enabled)
            if (widget.detergentEnabled) ...[
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      '1x',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      widget.detergent,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      breakdown['detergent']!.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 16),

            // Total Price
            Row(
              children: [
                const Expanded(flex: 2, child: SizedBox()),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Total Price',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.totalPrice.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Payment Button
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _processPayment(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Payment',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Only showing the updated _processPayment method
  // Replace this method in your payment_detail_page.dart

  // Replace the _processPayment method in your PaymentDetailsPage with this updated version

  // Replace the _processPayment method in your PaymentDetailsPage with this updated version

  // Replace the _processPayment method in payment_detail_page.dart

  void _processPayment(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
          ),
        );
      },
    );

    try {
      // Get user credentials from SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // ✅ FIX: Try both key variations to ensure we get the values
      final mobile =
          prefs.getString('usermobile') ?? prefs.getString('user_mobile');
      final token =
          prefs.getString('sessionToken') ?? prefs.getString('session_token');
      final userId = prefs.getInt('userid') ?? prefs.getInt('user_id') ?? 0;

      debugPrint('📱 Checking credentials...');
      debugPrint('📱 Mobile from usermobile: ${prefs.getString('usermobile')}');
      debugPrint(
        '📱 Mobile from user_mobile: ${prefs.getString('user_mobile')}',
      );
      debugPrint(
        '🔑 Token from sessionToken: ${prefs.getString('sessionToken')?.substring(0, 8)}...',
      );
      debugPrint(
        '🔑 Token from session_token: ${prefs.getString('session_token')?.substring(0, 8)}...',
      );

      if (mobile == null || mobile.isEmpty || token == null || token.isEmpty) {
        throw Exception('User not authenticated. Please login again.');
      }

      debugPrint('✅ Mobile: $mobile');
      debugPrint('✅ Token: ${token.substring(0, 8)}...');
      debugPrint('✅ User ID: $userId');

      // Step 1: Create payment order
      debugPrint('💳 Creating payment order...');
      final orderResponse = await HomeApi.createPaymentOrder(
        amount: (widget.totalPrice * 100).toInt(), // Convert to paise
        userId: userId,
      );

      debugPrint('✅ Payment order created: ${orderResponse['orderId']}');

      // Step 2: Simulate payment processing (replace with actual payment gateway)
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('✅ Payment completed');

      // Step 3: Calculate start and end times
      final now = DateTime.now();
      final startTime = now.toUtc().toIso8601String();

      // Extract minutes from washTime (e.g., "15 Min" -> 15)
      final durationMinutes = int.parse(widget.washTime.split(' ')[0]);
      final endTime = now
          .add(Duration(minutes: durationMinutes))
          .toUtc()
          .toIso8601String();

      debugPrint('⏰ Start: $startTime');
      debugPrint('⏰ End: $endTime');
      debugPrint('⏱️ Duration: $durationMinutes minutes');

      // Step 4: Book the device
      debugPrint('🔧 Booking device...');
      final bookingResponse = await HomeApi.bookDevice(
        sessionToken: token,
        hubId: widget.hubId,
        deviceId: widget.deviceId,
        deviceCondition: 'Good',
        deviceStatus: '0', // 0 = running
        mobileNumber: mobile,
        startTime: startTime,
        endTime: endTime,
        washMode: widget.washMode,
        detergentPreference: widget.detergentEnabled
            ? widget.detergent
            : 'None',
        duration: widget.washTime,
        transactionStatus: 'Success',
        paymentId:
            orderResponse['orderId'] ??
            'PAY_${DateTime.now().millisecondsSinceEpoch}',
        transactionTime: now.toUtc().toIso8601String(),
        transactionAmount: widget.totalPrice.toInt(),
      );

      debugPrint('✅ Device booked successfully');
      debugPrint('📊 Booking response: $bookingResponse');

      // Verify booking was successful
      if (bookingResponse['success'] != true) {
        throw Exception(
          'Booking failed: ${bookingResponse['message'] ?? 'Unknown error'}',
        );
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Step 5: Navigate to success page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessPage(
              amount: widget.totalPrice,
              machineId: widget.machineId,
              hubName: widget.hubName,
              washTime: widget.washTime,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Payment/Booking error: $e');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.red, size: 24),
                  SizedBox(width: 8),
                  Text('Payment Failed', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: Text(
                e.toString().replaceFirst('Exception: ', ''),
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    }
  }
}
