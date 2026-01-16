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

  /// Check if user data exists in SharedPreferences and auto-fill
  Future<void> _checkExistingUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name');
      final savedMobile = prefs.getString('user_mobile');

      if (savedName != null) {
        _nameController.text = savedName;
      }
      if (savedMobile != null) {
        _mobileController.text = savedMobile;
      }
    } catch (e) {
      debugPrint('Error loading saved user data: $e');
    }
  }

  

Future<void> _handleContinue() async {
  // ... existing validation code ...

  setState(() => _isLoading = true);

  try {
    final mobile = _mobileController.text.trim();
    final name = _nameController.text.trim();

    // 🔹 CALL SEND OTP API
    final response = await AuthApi.sendOtp(mobile);

    if (!response.containsKey('otp')) {
      throw Exception('OTP sending failed');
    }

    final String otpFromApi = response['otp']; // DEV ONLY
    final String userType = response['user_type'] ?? 'New';

    // 🔹 SAVE USER DATA + OTP IN SHARED PREFERENCES
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_mobile', mobile);
    
    // ✅ STORE OTP (for development/testing only)
    await prefs.setString('current_otp', otpFromApi);
    
    // Optional: Store OTP timestamp for expiration checking
    await prefs.setString('otp_timestamp', DateTime.now().toIso8601String());

    setState(() => _isLoading = false);

    _showSnackBar('OTP sent successfully!', isError: false);

    // 🔹 NAVIGATE TO OTP PAGE
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyPage(
            mobileNumber: mobile,
            otpFromApi: otpFromApi,  // Still pass for backward compatibility
            userType: userType,
            userName: name,
          ),
        ),
      );
    }
  } catch (e) {
    setState(() => _isLoading = false);
    
    // ... existing error handling ...
  }
}

  /// Show snackbar with custom styling
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // Top Logo Text
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
                              color: Colors.black,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Main Illustration Image
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
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Title
                  const Text(
                    'Scan : Pay : Wash : Move',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 35),

                  // Name Input
                  SizedBox(
                    width: 220,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.black87, width: 1.5),
                        color: Colors.white,
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
                            color: Colors.grey,
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

                  // Mobile Number Input
                  SizedBox(
                    width: 220,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.black87, width: 1.5),
                        color: Colors.white,
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
                            color: Colors.grey,
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

                  // Continue Button
                  SizedBox(
                    width: 140,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
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
                                color: Colors.white,
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

                  // Terms and Privacy
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'By clicking, I accept the '),
                          TextSpan(
                            text: 'terms of service',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'privacy policy',
                            style: TextStyle(
                              color: Colors.blue[700],
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
