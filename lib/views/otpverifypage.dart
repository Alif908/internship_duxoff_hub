import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internship_duxoff_hub/services/auth_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:internship_duxoff_hub/views/qkwashome.dart';

class OtpVerifyPage extends StatefulWidget {
  final String mobileNumber;
  final String userName;
  final String userType;
  final String otpFromApi; // For dev testing only

  const OtpVerifyPage({
    super.key,
    required this.mobileNumber,
    required this.userName,
    required this.userType,
    required this.otpFromApi,
  });

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;

  // Timer variables
  int _resendTimer = 30;
  bool _canResend = false;
  Timer? _timer;

  // Stored OTP from SharedPreferences
  String? _storedOtp;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _loadStoredOtp(); // Load OTP from SharedPreferences
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Load OTP from SharedPreferences
  Future<void> _loadStoredOtp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _storedOtp = prefs.getString('current_otp');

      // 🔹 DEVELOPMENT: Print loaded OTP
      debugPrint('========================================');
      debugPrint('LOADING OTP FROM STORAGE...');
      debugPrint('Stored OTP: $_storedOtp');

      // Optional: Check OTP expiration (e.g., 5 minutes)
      final otpTimestamp = prefs.getString('otp_timestamp');
      if (otpTimestamp != null) {
        final timestamp = DateTime.parse(otpTimestamp);
        final now = DateTime.now();
        final difference = now.difference(timestamp);

        debugPrint('OTP Age: ${difference.inSeconds} seconds');

        if (difference.inMinutes > 5) {
          // OTP expired, clear it
          await prefs.remove('current_otp');
          await prefs.remove('otp_timestamp');
          _storedOtp = null;
          debugPrint('⚠️ OTP EXPIRED - Cleared from storage');
        } else {
          debugPrint(
            '✅ OTP is valid (expires in ${300 - difference.inSeconds}s)',
          );
        }
      } else {
        debugPrint('⚠️ No timestamp found for OTP');
      }
      debugPrint('========================================');
    } catch (e) {
      debugPrint('❌ Error loading stored OTP: $e');
    }
  }

  // Start 30 second countdown timer
  void _startResendTimer() {
    setState(() {
      _resendTimer = 30;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleSubmit() async {
    String enteredOtp = _otpControllers.map((c) => c.text).join();

    if (enteredOtp.length != 4) {
      _showSnackBar('Please enter 4-digit OTP', isError: true);
      return;
    }

    // 🔹 VERIFY OTP - Check against stored OTP OR passed OTP
    final otpToVerify = _storedOtp ?? widget.otpFromApi;

    if (enteredOtp != otpToVerify) {
      _showSnackBar('Invalid OTP. Please try again.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔹 CALL ADD/UPDATE USER API TO GET SESSION TOKEN
      final response = await AuthApi.addOrUpdateUser(
        name: widget.userName,
        mobile: widget.mobileNumber,
        userStatus: widget.userType.toLowerCase(), // "existing" or "new"
      );

      // 🔹 FIX: API returns "sessionToken" (camelCase), not "session_token"
      if (response.containsKey('sessionToken')) {
        final prefs = await SharedPreferences.getInstance();

        // 🔹 SAVE SESSION DATA
        await prefs.setString('session_token', response['sessionToken']);
        await prefs.setString('user_mobile', widget.mobileNumber);
        await prefs.setString('user_name', widget.userName);
        await prefs.setString(
          'user_status',
          response['userstatus'] ?? widget.userType,
        );

        // ✅ CLEAR OTP AFTER SUCCESSFUL VERIFICATION
        await prefs.remove('current_otp');
        await prefs.remove('otp_timestamp');

        setState(() => _isLoading = false);

        _showSnackBar('Login successful!', isError: false);

        // Small delay to show success message
        await Future.delayed(const Duration(milliseconds: 500));

        // 🔹 NAVIGATE TO HOME PAGE
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const QKWashHome()),
          );
        }
      } else {
        throw Exception('Session token not received from server');
      }
    } catch (e) {
      setState(() => _isLoading = false);

      String errorMessage = 'Verification failed. Please try again.';
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        errorMessage = 'Network error. Check your internet connection.';
      }

      _showSnackBar(errorMessage, isError: true);
      debugPrint('Error in OTP verification: $e');
    }
  }

  Future<void> _handleResendOTP() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);

    try {
      final response = await AuthApi.sendOtp(widget.mobileNumber);

      // ✅ UPDATE STORED OTP IN SHARED PREFERENCES
      if (response.containsKey('otp')) {
        final newOtp = response['otp'];
        final prefs = await SharedPreferences.getInstance();

        // Store new OTP and timestamp
        await prefs.setString('current_otp', newOtp);
        await prefs.setString(
          'otp_timestamp',
          DateTime.now().toIso8601String(),
        );

        // ✅ UPDATE THE STATE VARIABLE IMMEDIATELY
        setState(() {
          _storedOtp = newOtp;
        });

        // 🔹 DEVELOPMENT ONLY: Show OTP in console
        debugPrint('========================================');
        debugPrint('NEW OTP SENT: $newOtp');
        debugPrint('OTP stored in SharedPreferences: $newOtp');
        debugPrint('========================================');
      }

      // Clear OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }

      _focusNodes[0].requestFocus();
      _startResendTimer();

      setState(() => _isLoading = false);

      _showSnackBar('OTP resent successfully', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to resend OTP. Try again.', isError: true);
      debugPrint('Error resending OTP: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String lastFourDigits = widget.mobileNumber.length >= 4
        ? widget.mobileNumber.substring(widget.mobileNumber.length - 4)
        : widget.mobileNumber;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Title
                const Text(
                  'Verify',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 20),

                // Description
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'We have sent a 4 digit OTP to your registered\nmobile number ending in ',
                      ),
                      TextSpan(
                        text: lastFourDigits,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text:
                            '. Please enter the 4-\ndigit OTP below to proceed.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // OTP Input Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        enabled: !_isLoading,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 3) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 35),

                // Submit Button
                SizedBox(
                  width: 130,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: const Color(
                        0xFF4A90E2,
                      ).withOpacity(0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 25),

                // Resend OTP with Timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Didn't receive the OTP? ",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    GestureDetector(
                      onTap: _canResend && !_isLoading
                          ? _handleResendOTP
                          : null,
                      child: Text(
                        _canResend
                            ? 'Resend OTP'
                            : 'Resend in ${_resendTimer}s',
                        style: TextStyle(
                          fontSize: 13,
                          color: (_canResend && !_isLoading)
                              ? Colors.blue[700]
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                          decoration: (_canResend && !_isLoading)
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // OTP Image
                Image.asset(
                  'assets/images/otppage.png',
                  height: 280,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 280,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.lock_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
