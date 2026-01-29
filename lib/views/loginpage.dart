import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/services/auth_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internship_duxoff_hub/views/otpverifypage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  Future<void> _checkExistingUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName =
          prefs.getString('user_name') ?? prefs.getString('username');
      final savedMobile =
          prefs.getString('user_mobile') ?? prefs.getString('usermobile');

      if (savedName != null && savedName.isNotEmpty) {
        _nameController.text = savedName;
      }
      if (savedMobile != null && savedMobile.isNotEmpty) {
        _mobileController.text = savedMobile;
      }
    } catch (e) {
      debugPrint('Error loading saved user data: $e');
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Name can only contain letters';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter mobile number';
    }
    if (value.trim().length != 10) {
      return 'Mobile number must be 10 digits';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
      return 'Please enter a valid Indian mobile number';
    }
    return null;
  }

  Future<void> _handleContinue() async {
    FocusScope.of(context).unfocus();

    final nameError = _validateName(_nameController.text);
    final mobileError = _validateMobile(_mobileController.text);

    if (nameError != null) {
      _showSnackBar(nameError, isError: true);
      return;
    }

    if (mobileError != null) {
      _showSnackBar(mobileError, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final mobile = _mobileController.text.trim();
      final name = _nameController.text.trim();

      debugPrint('========== SENDING OTP ==========');
      debugPrint('Mobile: $mobile');
      debugPrint('Name: $name');

      final response = await AuthApi.sendOtp(mobile);

      debugPrint('API Response: $response');

      if (!response.containsKey('otp') || response['otp'] == null) {
        throw Exception('OTP not received from server');
      }

      final String otpFromApi = response['otp'].toString();
      final String userType = response['user_type']?.toString() ?? 'New';

      debugPrint('OTP Received: $otpFromApi');
      debugPrint('User Type: $userType');

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('user_name', name);
      await prefs.setString('username', name);
      await prefs.setString('user_mobile', mobile);
      await prefs.setString('usermobile', mobile);

      await prefs.setString('current_otp', otpFromApi);
      await prefs.setString('otp_timestamp', DateTime.now().toIso8601String());

      debugPrint('User data saved to SharedPreferences');
      debugPrint('=================================');

      setState(() => _isLoading = false);

      _showSnackBar('OTP sent successfully!', isError: false);

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyPage(
              mobileNumber: mobile,
              otpFromApi: otpFromApi,
              userType: userType,
              userName: name,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      debugPrint('Error in _handleContinue: $e');

      String errorMessage = 'Failed to send OTP. Please try again.';

      if (e.toString().contains('SocketException')) {
        errorMessage = 'No internet connection. Please check your network.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains('Exception:')) {
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
              color: const Color(0xFFFFFFFF),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFC62828)
            : const Color(0xFF388E3C),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.topLeft,
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'QK ',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A90E2),
                              letterSpacing: 1,
                            ),
                          ),
                          TextSpan(
                            text: 'WASH',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF000000),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Image.asset(
                    'assets/images/6190576 1.png',
                    height: 280,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 280,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Color(0xFF9E9E9E),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Scan : Pay : Wash : Move',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 35),

                  SizedBox(
                    width: 220,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: const Color(0xFF212121),
                          width: 1.5,
                        ),
                        color: const Color(0xFFFFFFFF),
                      ),
                      child: TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isLoading,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: 220,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: const Color(0xFF212121),
                          width: 1.5,
                        ),
                        color: const Color(0xFFFFFFFF),
                      ),
                      child: TextField(
                        controller: _mobileController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        enabled: !_isLoading,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Mobile number',
                          hintStyle: TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: 140,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: const Color(0xFFFFFFFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 2,
                        shadowColor: const Color(0xFF4A90E2).withOpacity(0.4),
                        disabledBackgroundColor: const Color(
                          0xFF4A90E2,
                        ).withOpacity(0.5),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Color(0xFFFFFFFF),
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF212121),
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'By clicking, I accept the '),
                          TextSpan(
                            text: 'terms of service',
                            style: TextStyle(
                              color: const Color(0xFF1976D2),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'privacy policy',
                            style: TextStyle(
                              color: const Color(0xFF1976D2),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
