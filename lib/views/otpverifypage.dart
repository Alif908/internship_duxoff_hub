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
  final String otpFromApi;

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

  int _resendTimer = 30;
  bool _canResend = false;
  Timer? _timer;

  String? _storedOtp;
  bool _hasAutoFilled = false; // Track if auto-fill has happened

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _loadStoredOtp();
    _scheduleAutoFill(); // Schedule auto-fill after 3 seconds
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

  /// AUTO-FILL OTP AFTER 3 SECONDS
  void _scheduleAutoFill() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_hasAutoFilled) {
        _autoFillOtp();
      }
    });
  }

  /// Auto-fill the OTP from stored value
  void _autoFillOtp() async {
    final otpToFill = _storedOtp ?? widget.otpFromApi;

    if (otpToFill.length == 4) {
      setState(() {
        _hasAutoFilled = true;
      });

      debugPrint('🔄 Auto-filling OTP: $otpToFill');

      // Fill each digit with a small animation delay
      for (int i = 0; i < 4; i++) {
        await Future.delayed(Duration(milliseconds: 100 * i));
        if (mounted) {
          _otpControllers[i].text = otpToFill[i];
        }
      }

      // Wait 2 seconds then auto-submit
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        _handleSubmit();
      }
    }
  }

  Future<void> _loadStoredOtp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _storedOtp = prefs.getString('current_otp');

      debugPrint('========== LOADING OTP FROM STORAGE ==========');
      debugPrint('Stored OTP: $_storedOtp');

      final otpTimestamp = prefs.getString('otp_timestamp');
      if (otpTimestamp != null) {
        final timestamp = DateTime.parse(otpTimestamp);
        final now = DateTime.now();
        final difference = now.difference(timestamp);

        debugPrint('OTP Age: ${difference.inSeconds} seconds');

        if (difference.inMinutes > 5) {
          await prefs.remove('current_otp');
          await prefs.remove('otp_timestamp');
          _storedOtp = null;
          debugPrint('OTP EXPIRED - Cleared from storage');
        } else {
          debugPrint(
            'OTP is valid (expires in ${300 - difference.inSeconds}s)',
          );
        }
      }
      debugPrint('=============================================');
    } catch (e) {
      debugPrint('Error loading stored OTP: $e');
    }
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 30;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) {
            _resendTimer--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _handleSubmit() async {
    String enteredOtp = _otpControllers.map((c) => c.text).join();

    if (enteredOtp.length != 4) {
      _showSnackBar('Please enter 4-digit OTP', isError: true);
      return;
    }

    final otpToVerify = _storedOtp ?? widget.otpFromApi;

    if (enteredOtp != otpToVerify) {
      _showSnackBar('Invalid OTP. Please try again.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('========== VERIFYING OTP & GETTING SESSION ==========');
      debugPrint('Mobile: ${widget.mobileNumber}');
      debugPrint('Name: ${widget.userName}');
      debugPrint('User Type: ${widget.userType}');

      final response = await AuthApi.addOrUpdateUser(
        name: widget.userName,
        mobile: widget.mobileNumber,
        userStatus: widget.userType.toLowerCase(),
      );

      debugPrint('Full API Response: $response');
      debugPrint('Response Keys: ${response.keys.toList()}');

      if (!response.containsKey('sessionToken') ||
          response['sessionToken'] == null ||
          response['sessionToken'].toString().isEmpty) {
        throw Exception('Session token not received from server');
      }

      final prefs = await SharedPreferences.getInstance();

      int userId = 0;

      if (response.containsKey('userid')) {
        userId = response['userid'] is int
            ? response['userid']
            : int.tryParse(response['userid'].toString()) ?? 0;
        debugPrint('Found userid field: $userId');
      } else if (response.containsKey('userId')) {
        userId = response['userId'] is int
            ? response['userId']
            : int.tryParse(response['userId'].toString()) ?? 0;
        debugPrint('Found userId field: $userId');
      }

      debugPrint('========== SAVING USER SESSION ==========');
      debugPrint('User ID: $userId');
      debugPrint(
        'Session Token: ${response['sessionToken'].toString().substring(0, 10)}...',
      );
      debugPrint('Mobile: ${widget.mobileNumber}');
      debugPrint('Name: ${widget.userName}');

      if (userId == 0) {
        debugPrint('❌ CRITICAL: User ID is still 0!');
        debugPrint('❌ This will cause payment to fail');
        debugPrint('❌ Full API response: $response');
        throw Exception(
          'User ID not received from server. Please contact support.',
        );
      }

      await prefs.setString(
        'session_token',
        response['sessionToken'].toString(),
      );
      await prefs.setString(
        'sessionToken',
        response['sessionToken'].toString(),
      );

      await prefs.setString('user_mobile', widget.mobileNumber);
      await prefs.setString('usermobile', widget.mobileNumber);

      await prefs.setString('user_name', widget.userName);
      await prefs.setString('username', widget.userName);

      await prefs.setInt('user_id', userId);
      await prefs.setInt('userid', userId);

      await prefs.setString(
        'user_status',
        response['userstatus']?.toString() ?? widget.userType,
      );

      await prefs.remove('current_otp');
      await prefs.remove('otp_timestamp');

      debugPrint('========== VERIFICATION ==========');
      debugPrint('Saved user_id: ${prefs.getInt('user_id')}');
      debugPrint('Saved userid: ${prefs.getInt('userid')}');
      debugPrint('Saved user_mobile: ${prefs.getString('user_mobile')}');
      debugPrint('Saved usermobile: ${prefs.getString('usermobile')}');
      debugPrint(
        'Saved session_token: ${prefs.getString('session_token')?.substring(0, 10)}...',
      );
      debugPrint(
        'Saved sessionToken: ${prefs.getString('sessionToken')?.substring(0, 10)}...',
      );

      debugPrint('📋 All SharedPreferences keys:');
      for (var key in prefs.getKeys()) {
        final value = prefs.get(key);
        if (key.contains('token') || key.contains('Token')) {
          debugPrint('   $key: ${value.toString().substring(0, 10)}...');
        } else {
          debugPrint('   $key: $value');
        }
      }
      debugPrint('==================================');

      setState(() => _isLoading = false);

      _showSnackBar('Login successful!', isError: false);

      // Wait 2 seconds before navigation
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const QKWashHome()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      debugPrint('Error in OTP verification: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      String errorMessage = 'Verification failed. Please try again.';
      if (e.toString().contains('SocketException')) {
        errorMessage = 'No internet connection. Check your network.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }

      _showSnackBar(errorMessage, isError: true);
    }
  }

  Future<void> _handleResendOTP() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('========== RESENDING OTP ==========');
      debugPrint('Mobile: ${widget.mobileNumber}');

      final response = await AuthApi.sendOtp(widget.mobileNumber);

      if (!response.containsKey('otp') || response['otp'] == null) {
        throw Exception('OTP not received from server');
      }

      final newOtp = response['otp'].toString();
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('current_otp', newOtp);
      await prefs.setString('otp_timestamp', DateTime.now().toIso8601String());

      setState(() {
        _storedOtp = newOtp;
        _hasAutoFilled = false; // Reset auto-fill flag
      });

      debugPrint('NEW OTP: $newOtp');
      debugPrint('===================================');

      for (var controller in _otpControllers) {
        controller.clear();
      }

      _focusNodes[0].requestFocus();
      _startResendTimer();

      setState(() => _isLoading = false);

      _showSnackBar('OTP resent successfully', isError: false);

      // Schedule auto-fill for the new OTP
      _scheduleAutoFill();
    } catch (e) {
      setState(() => _isLoading = false);

      debugPrint('Error resending OTP: $e');

      String errorMessage = 'Failed to resend OTP. Try again.';
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }

      _showSnackBar(errorMessage, isError: true);
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

                const Text(
                  'Verify',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 20),

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
