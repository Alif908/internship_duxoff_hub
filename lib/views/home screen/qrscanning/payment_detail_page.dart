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
  final String washMode;
  final String washTime;
  final double totalPrice;

  const PaymentDetailsPage({
    super.key,
    required this.hubName,
    required this.hubId,
    required this.deviceId,
    required this.machineId,
    required this.washMode,
    required this.washTime,
    required this.totalPrice,
  });

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  late Razorpay _razorpay;
  bool _isProcessing = false;
  String? _pendingOrderId;

  late TextEditingController _amountController;
  late double _currentAmount;
  bool _isEditingAmount = false;

  static const String razorpayKeyId = 'rzp_live_MtPtY0alVfSmZc';
  static const int paymentTimeout = 600; // 10 minutes

  @override
  void initState() {
    super.initState();
    // Initialize with offer price (discounted price)
    final breakdown = _calculatePriceBreakdown();
    _currentAmount = breakdown['offer']!;
    _amountController = TextEditingController(
      text: _currentAmount.toStringAsFixed(0),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog(
          'Initialization Error',
          'Payment gateway initialization failed. Please restart the app.',
        );
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    try {
      _razorpay.clear();
    } catch (e) {
      debugPrint('⚠️ Error disposing Razorpay: $e');
    }
    super.dispose();
  }

  // ==================== AMOUNT MANAGEMENT ====================

  void _updateAmount() {
    final newAmount = double.tryParse(_amountController.text);
    if (newAmount == null || newAmount <= 0) {
      _showErrorDialog(
        'Invalid Amount',
        'Please enter a valid amount greater than 0',
      );
      _amountController.text = _currentAmount.toStringAsFixed(2);
      return;
    }

    setState(() {
      _currentAmount = newAmount;
      _isEditingAmount = false;
    });
    debugPrint('💰 Amount updated to: $_currentAmount');
  }

  void _resetAmount() {
    final breakdown = _calculatePriceBreakdown();
    final offerPrice = breakdown['offer']!;

    setState(() {
      _currentAmount = offerPrice;
      _amountController.text = _currentAmount.toStringAsFixed(0);
      _isEditingAmount = false;
    });
    debugPrint('🔄 Amount reset to offer price: $_currentAmount');
  }

  // ==================== USER CREDENTIALS ====================

  Future<Map<String, String>> _getUserCredentials() async {
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

    if (mobile.isEmpty || token.isEmpty) {
      throw Exception('User not authenticated. Please login again.');
    }

    return {'mobile': mobile, 'token': token, 'name': userName};
  }

  Future<int> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    int userId =
        prefs.getInt('user_id') ??
        prefs.getInt('userid') ??
        prefs.getInt('userId') ??
        0;

    if (userId == 0) {
      final mobile =
          prefs.getString('user_mobile') ?? prefs.getString('usermobile') ?? '';
      if (mobile.isNotEmpty) {
        userId = mobile.hashCode.abs() % 1000000;
        debugPrint('📱 Using mobile-based userId as fallback: $userId');
        await Future.wait([
          prefs.setInt('user_id', userId),
          prefs.setInt('userid', userId),
        ]);
      } else {
        throw Exception('Unable to retrieve user ID. Please login again.');
      }
    }

    return userId;
  }

  // ==================== BOOKING ====================

  Future<void> _bookDevice({
    required String paymentId,
    required String mobile,
    required String token,
  }) async {
    final now = DateTime.now();
    final startTime = now.toUtc().toIso8601String();
    final durationMinutes = int.tryParse(widget.washTime.split(' ')[0]) ?? 30;
    final endTime = now
        .add(Duration(minutes: durationMinutes))
        .toUtc()
        .toIso8601String();

    debugPrint('📤 Booking device...');
    debugPrint('   Amount: ${_currentAmount.toInt()}');
    debugPrint('   Duration: $durationMinutes minutes');

    final bookingResponse = await HomeApi.bookDevice(
      sessionToken: token,
      hubId: widget.hubId,
      deviceId: widget.deviceId,
      deviceCondition: 'Good',
     
      mobileNumber: mobile,
      startTime: startTime,
      endTime: endTime,
      washMode: widget.washMode,
      detergentPreference: 'None',
      duration: widget.washTime,
      transactionStatus: 'Success',
      paymentId: paymentId,
      transactionTime: now.toUtc().toIso8601String(),
      transactionAmount: _currentAmount.toInt(),
    );

    if (bookingResponse['success'] != true) {
      throw Exception(bookingResponse['message'] ?? 'Booking failed');
    }

    // Store booking locally for backup
    await _storeBookingLocally(
      paymentId: paymentId,
      startTime: startTime,
      endTime: endTime,
    );

    debugPrint('✅ Device booked successfully');
  }

  Future<void> _storeBookingLocally({
    required String paymentId,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookingData = {
        'deviceid': widget.deviceId.toString(),
        'hubname': widget.hubName,
        'hubid': widget.hubId,
        'machineid': widget.machineId,
        'amount': _currentAmount,
        'washmode': widget.washMode,
        'washtime': widget.washTime,
        'paymentid': paymentId,
        'starttime': startTime,
        'endtime': endTime,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final bookingKey =
          'booking_${widget.deviceId}_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(bookingKey, jsonEncode(bookingData));
      debugPrint('💾 Stored booking locally: $bookingKey');
    } catch (e) {
      debugPrint('⚠️ Failed to store booking locally: $e');
      // Non-critical error, don't throw
    }
  }

  // ==================== RAZORPAY HANDLERS ====================

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('========== PAYMENT SUCCESS ==========');
    debugPrint('💳 Payment ID: ${response.paymentId}');
    debugPrint('📋 Order ID: ${response.orderId}');
    debugPrint('🔐 Signature: ${response.signature}');

    if (_isProcessing) {
      debugPrint('⚠️ Already processing, ignoring duplicate callback');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final credentials = await _getUserCredentials();

      await _bookDevice(
        paymentId:
            response.paymentId ??
            _pendingOrderId ??
            'RAZORPAY_${DateTime.now().millisecondsSinceEpoch}',
        mobile: credentials['mobile']!,
        token: credentials['token']!,
      );

      if (!mounted) return;

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
    debugPrint('❌ Code: ${response.code}');
    debugPrint('📝 Message: ${response.message}');
    debugPrint('==================================');

    if (!mounted || _isProcessing) return;

    setState(() => _isProcessing = false);

    // User cancelled payment - show snackbar instead of dialog
    if (response.code == 0 ||
        response.message?.toLowerCase().contains('cancel') == true ||
        response.message?.toLowerCase().contains('user cancelled') == true) {
      debugPrint('ℹ️ Payment cancelled by user');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment cancelled'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Actual payment error - show dialog
    String errorMessage = 'Payment failed. Please try again.';
    if (response.message != null && response.message!.isNotEmpty) {
      errorMessage = response.message!.toLowerCase().contains('failed')
          ? 'Payment failed. Please check your payment details.'
          : response.message!;
    }

    _showErrorDialog('Payment Failed', errorMessage);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('👛 External Wallet Selected: ${response.walletName}');
  }

  // ==================== PAYMENT FLOW ====================

  Future<void> _processPayment(BuildContext context) async {
    if (_isProcessing) {
      debugPrint('⚠️ Payment already in progress');
      return;
    }

    setState(() => _isProcessing = true);

    BuildContext? dialogContext;

    try {
      final credentials = await _getUserCredentials();
      final userId = await _getUserId();

      debugPrint('========== PROCESSING PAYMENT ==========');
      debugPrint('👤 User: ${credentials['name']}');
      debugPrint('📱 Mobile: ${credentials['mobile']}');
      debugPrint('🆔 User ID: $userId');
      debugPrint(
        '💰 Amount: ₹$_currentAmount (${(_currentAmount * 100).toInt()} paise)',
      );

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            dialogContext = ctx;
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

      // Create payment order
      debugPrint('🔄 Creating payment order...');
      final orderResponse = await HomeApi.createPaymentOrder(
        amount: (_currentAmount * 100).toInt(),
        userId: userId,
      );

      if (orderResponse['success'] != true ||
          !orderResponse.containsKey('orderId') ||
          orderResponse['orderId'] == null ||
          orderResponse['orderId'].toString().isEmpty) {
        throw Exception(
          orderResponse['message'] ?? 'Failed to create payment order',
        );
      }

      final orderId = orderResponse['orderId'].toString();
      _pendingOrderId = orderId;
      debugPrint('✅ Order created: $orderId');

      // Close loading dialog
      if (dialogContext != null && mounted) {
        Navigator.pop(dialogContext!);
        dialogContext = null;
      }

      // Small delay before opening Razorpay
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() => _isProcessing = false);
        _openRazorpayCheckout(
          orderId: orderId,
          name: credentials['name']!,
          mobile: credentials['mobile']!,
          email: '${credentials['mobile']}@qkwash.com',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Payment initialization error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (dialogContext != null && mounted) {
        Navigator.pop(dialogContext!);
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog(
          'Payment Failed',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void _openRazorpayCheckout({
    required String orderId,
    required String name,
    required String mobile,
    required String email,
  }) {
    try {
      debugPrint('========== OPENING RAZORPAY ==========');
      debugPrint('📋 Order ID: $orderId');
      debugPrint('💰 Amount: ₹$_currentAmount');

      final options = {
        'key': razorpayKeyId,
        'amount': (_currentAmount * 100).toInt(),
        'currency': 'INR',
        'name': 'QK Wash',
        'description': '${widget.washMode} Wash - ${widget.washTime}',
        'order_id': orderId,
        'prefill': {'contact': mobile, 'email': email, 'name': name},
        'theme': {'color': '#4A90E2'},
        'timeout': paymentTimeout,
        'retry': {'enabled': true, 'max_count': 1},
      };

      _razorpay.open(options);
      debugPrint('✅ Razorpay opened successfully');
      debugPrint('=====================================');
    } catch (e, stackTrace) {
      debugPrint('❌ CRITICAL ERROR opening Razorpay: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog(
          'Payment Gateway Error',
          'Could not open payment gateway. Please try again.',
        );
      }
    }
  }

  // ==================== UI HELPERS ====================

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

  Map<String, double> _calculatePriceBreakdown() {
    double actualPrice = 0.0;
    double offerPrice = 0.0;

    // Wash mode pricing
    if (widget.washMode == 'Quick Wash') {
      actualPrice = 100.0;
      offerPrice = 1.0;
    } else if (widget.washMode == 'Normal Wash') {
      actualPrice = 150.0;
      offerPrice = 100.0;
    }

    return {
      'actual': actualPrice,
      'offer': offerPrice,
      'discount': actualPrice - offerPrice,
    };
  }

  // ==================== BUILD UI ====================

  @override
  Widget build(BuildContext context) {
    final breakdown = _calculatePriceBreakdown();
    final actualPrice = breakdown['actual']!;
    final offerPrice = breakdown['offer']!;
    final discount = breakdown['discount']!;

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
        child: SingleChildScrollView(
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
                      '${widget.washMode} (${widget.washTime})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (discount > 0)
                          Text(
                            '₹${actualPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          '₹${offerPrice.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            color: discount > 0
                                ? const Color(0xFF4CAF50)
                                : Colors.black87,
                            fontWeight: discount > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              const SizedBox(height: 16),

              // OFFER BADGE
              if (discount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'OFFER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '-₹${discount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),
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
                            '₹ ${_currentAmount.toStringAsFixed(0)}',
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                    if (_currentAmount != offerPrice) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Original: ₹${offerPrice.toStringAsFixed(0)}',
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
                            'Pay ₹${_currentAmount.toStringAsFixed(0)}',
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
      ),
    );
  }
}
