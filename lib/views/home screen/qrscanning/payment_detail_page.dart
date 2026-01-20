import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/views/home%20screen/qrscanning/paymentsuccessfull_page.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
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
  late Razorpay _razorpay;
  bool _isProcessing = false;
  String? _pendingOrderId;

  // ✅ NEW: Controllers for editable amount
  late TextEditingController _amountController;
  late double _currentAmount;
  bool _isEditingAmount = false;

  static const String razorpayKeyId = 'rzp_live_MtPtY0alVfSmZc';

  @override
  void initState() {
    super.initState();
    // Initialize amount
    _currentAmount = widget.totalPrice;
    _amountController = TextEditingController(
      text: _currentAmount.toStringAsFixed(2),
    );
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    try {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      debugPrint('✅ Razorpay initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Razorpay: $e');
      _showErrorDialog(
        'Initialization Error',
        'Payment gateway initialization failed. Please restart the app.',
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    try {
      _razorpay.clear();
    } catch (e) {
      debugPrint('Error disposing Razorpay: $e');
    }
    super.dispose();
  }

  // ✅ NEW: Update amount when user edits
  void _updateAmount() {
    final newAmount = double.tryParse(_amountController.text);
    if (newAmount != null && newAmount > 0) {
      setState(() {
        _currentAmount = newAmount;
        _isEditingAmount = false;
      });
      debugPrint('✅ Amount updated to: $_currentAmount');
    } else {
      _showErrorDialog(
        'Invalid Amount',
        'Please enter a valid amount greater than 0',
      );
      _amountController.text = _currentAmount.toStringAsFixed(2);
    }
  }

  // ✅ NEW: Reset to original amount
  void _resetAmount() {
    setState(() {
      _currentAmount = widget.totalPrice;
      _amountController.text = _currentAmount.toStringAsFixed(2);
      _isEditingAmount = false;
    });
    debugPrint('🔄 Amount reset to original: $_currentAmount');
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('========== PAYMENT SUCCESS ==========');
    debugPrint('Payment ID: ${response.paymentId}');
    debugPrint('Order ID: ${response.orderId}');
    debugPrint('Signature: ${response.signature}');

    if (_isProcessing) {
      debugPrint('⚠️ Already processing, ignoring duplicate callback');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final mobile =
          prefs.getString('user_mobile') ?? prefs.getString('usermobile') ?? '';
      final token =
          prefs.getString('session_token') ??
          prefs.getString('sessionToken') ??
          '';

      if (mobile.isEmpty || token.isEmpty) {
        throw Exception('User not authenticated. Please login again.');
      }

      final now = DateTime.now();
      final startTime = now.toUtc().toIso8601String();
      final durationMinutes = int.parse(widget.washTime.split(' ')[0]);
      final endTime = now
          .add(Duration(minutes: durationMinutes))
          .toUtc()
          .toIso8601String();

      debugPrint('🔧 Booking device after successful payment...');
      debugPrint('💰 Amount being sent: ${_currentAmount.toInt()}');

      final bookingResponse = await HomeApi.bookDevice(
        sessionToken: token,
        hubId: widget.hubId,
        deviceId: widget.deviceId,
        deviceCondition: 'Good',
        deviceStatus: '0',
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
            response.paymentId ??
            _pendingOrderId ??
            'RAZORPAY_${DateTime.now().millisecondsSinceEpoch}',
        transactionTime: now.toUtc().toIso8601String(),
        transactionAmount: _currentAmount.toInt(),
      );

      if (bookingResponse['success'] != true) {
        throw Exception(bookingResponse['message'] ?? 'Booking failed');
      }

      debugPrint('✅ Device booked successfully');

      // ✅ CRITICAL: Store booking locally with amount
      try {
        final bookingData = {
          'deviceid': widget.deviceId.toString(),
          'hubname': widget.hubName,
          'hubid': widget.hubId,
          'machineid': widget.machineId,
          'amount': _currentAmount,
          'washmode': widget.washMode,
          'washtime': widget.washTime,
          'detergent': widget.detergentEnabled ? widget.detergent : 'None',
          'paymentid': response.paymentId ?? '',
          'starttime': startTime,
          'endtime': endTime,
          'timestamp': DateTime.now().toIso8601String(),
        };

        final bookingKey =
            'booking_${widget.deviceId}_${now.millisecondsSinceEpoch}';
        await prefs.setString(bookingKey, jsonEncode
        (bookingData));
        debugPrint(
          '💾 Stored booking locally: $bookingKey with amount: $_currentAmount',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to store booking locally: $e');
        // Continue anyway - not critical
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessPage(
              amount: _currentAmount,
              machineId: widget.machineId,
              hubName: widget.hubName,
              washTime: widget.washTime,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Booking error after payment: $e');
      if (mounted) {
        _showErrorDialog(
          'Booking Failed',
          'Payment successful but booking failed: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('========== PAYMENT ERROR ==========');
    debugPrint('Code: ${response.code}');
    debugPrint('Message: ${response.message}');
    debugPrint('==================================');

    if (mounted && !_isProcessing) {
      setState(() => _isProcessing = false);

      if (response.code == 0 ||
          response.message?.toLowerCase().contains('cancel') == true ||
          response.message?.toLowerCase().contains('user cancelled') == true) {
        debugPrint('ℹ️ Payment cancelled by user - no error dialog shown');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment cancelled'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String errorMessage = 'Payment failed. Please try again.';

      if (response.message != null) {
        if (response.message!.toLowerCase().contains('failed')) {
          errorMessage = 'Payment failed. Please check your payment details.';
        } else {
          errorMessage = response.message!;
        }
      }

      _showErrorDialog('Payment Failed', errorMessage);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('🔔 External Wallet Selected: ${response.walletName}');
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
              const Icon(Icons.error_outline, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 14)),
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

  void _openRazorpayCheckout({
    required String orderId,
    required String name,
    required String mobile,
    required String email,
  }) {
    try {
      debugPrint('========== OPENING RAZORPAY CHECKOUT ==========');
      debugPrint('Order ID: $orderId');
      debugPrint('Amount: $_currentAmount'); // Use current amount
      debugPrint('Mobile: $mobile');
      debugPrint('Name: $name');

      final options = {
        'key': razorpayKeyId,
        'amount': (_currentAmount * 100).toInt(), // Use current amount
        'currency': 'INR',
        'name': 'QK Wash',
        'description': '${widget.washMode} Wash - ${widget.washTime}',
        'order_id': orderId,
        'prefill': {'contact': mobile, 'email': email, 'name': name},
        'theme': {'color': '#4A90E2'},
        'timeout': 600,
        'retry': {'enabled': true, 'max_count': 1},
      };

      debugPrint('💳 Razorpay options: $options');
      _razorpay.open(options);
      debugPrint('✅ Razorpay.open() called successfully');
      debugPrint('=============================================');
    } catch (e, stackTrace) {
      debugPrint('❌ CRITICAL ERROR opening Razorpay: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog(
          'Payment Gateway Error',
          'Could not open payment gateway: ${e.toString()}. Please try again.',
        );
      }
    }
  }

  Future<int> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    int userId =
        prefs.getInt('user_id') ??
        prefs.getInt('userid') ??
        prefs.getInt('userId') ??
        0;

    debugPrint('🆔 Checking userId from SharedPreferences:');
    debugPrint('   user_id: ${prefs.getInt('user_id')}');
    debugPrint('   userid: ${prefs.getInt('userid')}');
    debugPrint('   userId: ${prefs.getInt('userId')}');
    debugPrint('   Final userId: $userId');

    if (userId == 0) {
      final mobile =
          prefs.getString('user_mobile') ?? prefs.getString('usermobile') ?? '';
      if (mobile.isNotEmpty) {
        userId = mobile.hashCode.abs() % 1000000;
        debugPrint('⚠️ Using mobile-based userId as fallback: $userId');
        await prefs.setInt('user_id', userId);
        await prefs.setInt('userid', userId);
      }
    }

    return userId;
  }

  void _processPayment(BuildContext context) async {
    if (_isProcessing) {
      debugPrint('⚠️ Payment already in progress, ignoring duplicate tap');
      return;
    }

    setState(() => _isProcessing = true);

    bool dialogShown = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final mobile =
          prefs.getString('user_mobile') ?? prefs.getString('usermobile') ?? '';
      final token =
          prefs.getString('session_token') ??
          prefs.getString('sessionToken') ??
          '';
      final userName =
          prefs.getString('user_name') ??
          prefs.getString('username') ??
          prefs.getString('usermame') ??
          'User';

      debugPrint('========== PROCESSING PAYMENT ==========');
      debugPrint('Mobile: $mobile');
      debugPrint('Name: $userName');
      debugPrint('Token exists: ${token.isNotEmpty}');
      debugPrint('Amount (paise): ${(_currentAmount * 100).toInt()}');

      if (mobile.isEmpty || token.isEmpty) {
        throw Exception('User not authenticated. Please login again.');
      }

      final userId = await _getUserId();
      debugPrint('User ID: $userId');

      if (userId == 0) {
        throw Exception('Unable to retrieve user ID. Please login again.');
      }

      // Show loading dialog only before API call
      if (mounted) {
        dialogShown = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF4A90E2),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text('Creating payment order...'),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }

      debugPrint('💳 Creating payment order...');
      final orderResponse = await HomeApi.createPaymentOrder(
        amount: (_currentAmount * 100).toInt(),
        userId: userId,
      );

      debugPrint('📦 Order Response: $orderResponse');

      if (orderResponse['success'] != true) {
        throw Exception(
          orderResponse['message'] ?? 'Failed to create payment order',
        );
      }

      if (!orderResponse.containsKey('orderId') ||
          orderResponse['orderId'] == null ||
          orderResponse['orderId'].toString().isEmpty) {
        throw Exception('Invalid order ID received from server');
      }

      final orderId = orderResponse['orderId'].toString();
      debugPrint('✅ Order created: $orderId');

      _pendingOrderId = orderId;

      // Close loading dialog
      if (mounted && dialogShown) {
        Navigator.pop(context);
        dialogShown = false;
      }

      // Small delay to ensure dialog is closed
      await Future.delayed(const Duration(milliseconds: 300));

      // Reset processing state before opening Razorpay
      if (mounted) {
        setState(() => _isProcessing = false);
      }

      // Open Razorpay checkout
      if (mounted) {
        _openRazorpayCheckout(
          orderId: orderId,
          name: userName,
          mobile: mobile,
          email: '$mobile@qkwash.com',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Payment initialization error: $e');
      debugPrint('Stack trace: $stackTrace');

      // Close loading dialog if shown
      if (mounted && dialogShown) {
        Navigator.pop(context);
      }

      // Reset processing state
      if (mounted) {
        setState(() => _isProcessing = false);
      }

      // Show error dialog
      if (mounted) {
        _showErrorDialog(
          'Payment Failed',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Map<String, double> _calculatePriceBreakdown() {
    double basePrice = 50.0;
    double washModePrice = 0.0;
    double washTimePrice = 0.0;
    double detergentPrice = 0.0;

    if (widget.washMode == 'Steam') {
      washModePrice = 25.0;
    } else if (widget.washMode == 'Custom') {
      washModePrice = 35.0;
    }

    if (widget.washTime == '30 Min') {
      washTimePrice = 20.0;
    } else if (widget.washTime == '45 Min') {
      washTimePrice = 40.0;
    }

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

            // ✅ NEW: Editable Total Price Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total Price',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (!_isEditingAmount) ...[
                        Text(
                          '₹ ${_currentAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          color: const Color(0xFF4A90E2),
                          onPressed: () {
                            setState(() => _isEditingAmount = true);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ] else ...[
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              prefix: Text('₹ '),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            autofocus: true,
                            onSubmitted: (_) => _updateAmount(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, size: 20),
                          color: Colors.green,
                          onPressed: _updateAmount,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: Colors.red,
                          onPressed: () {
                            setState(() {
                              _isEditingAmount = false;
                              _amountController.text = _currentAmount
                                  .toStringAsFixed(2);
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                  if (_currentAmount != widget.totalPrice) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Original: ₹${widget.totalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _resetAmount,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reset'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _processPayment(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isProcessing
                        ? Colors.grey
                        : const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Pay ₹${_currentAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
