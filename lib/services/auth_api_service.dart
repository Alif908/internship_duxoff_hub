import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AuthApi {
  static const String baseUrl = 'https://api.qkwash.com';
  static const Duration timeoutDuration = Duration(seconds: 30);

  /// SEND OTP
  static Future<Map<String, dynamic>> sendOtp(String mobile) async {
    try {
      final requestBody = {"usermobile": mobile};

      print('========== DEBUG SEND OTP API ==========');
      print('Request URL: $baseUrl/api/login/send-otp');
      print('Request Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/login/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('========================================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ OTP sent successfully');
        return data;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Invalid mobile number');
      } else {
        throw Exception('Failed to send OTP: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Invalid response format from server');
    } catch (e) {
      print('❌ ERROR in sendOtp: $e');
      rethrow;
    }
  }

  /// ADD OR UPDATE USER (GENERATES SESSION TOKEN)
  static Future<Map<String, dynamic>> addOrUpdateUser({
    required String name,
    required String mobile,
    required String userStatus,
  }) async {
    try {
      // API documentation shows "usermame" (typo in backend)
      final requestBody = {
        "usermobile": mobile,
        "userstatus": userStatus,
        "usermame": name, // Keep backend's typo
      };

      print('========== DEBUG ADD/UPDATE USER API ==========');
      print('Request URL: $baseUrl/api/users/addOrUpdate');
      print('Request Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/users/addOrUpdate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('===============================================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ User added/updated successfully');

        // Verify that sessionToken is present
        if (!data.containsKey('sessionToken') ||
            data['sessionToken'] == null ||
            data['sessionToken'].toString().isEmpty) {
          throw Exception('Session token not received from server');
        }

        return data;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Invalid user data');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please try again.');
      } else {
        throw Exception('Failed to add/update user: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Invalid response format from server');
    } catch (e) {
      print('❌ ERROR in addOrUpdateUser: $e');
      rethrow;
    }
  }

  /// VERIFY OTP (Helper method)
  static bool verifyOtp(String enteredOtp, String receivedOtp) {
    return enteredOtp.trim() == receivedOtp.trim();
  }
}
