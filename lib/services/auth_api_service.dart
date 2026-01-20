import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthApi {
  static const String baseUrl = 'https://api.qkwash.com';
  static const Duration timeoutDuration = Duration(seconds: 30);

  
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

  
  static Future<Map<String, dynamic>> addOrUpdateUser({
    required String name,
    required String mobile,
    required String userStatus,
  }) async {
    try {
      final requestBody = {
        "usermobile": mobile,
        "userstatus": userStatus,
        "usermame": name, 
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
      print('Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print(' Parsed Response: $data');
        print(' Response Type: ${data.runtimeType}');
        print(' Available Keys: ${data is Map ? data.keys.toList() : "N/A"}');

        
        if (!data.containsKey('sessionToken') ||
            data['sessionToken'] == null ||
            data['sessionToken'].toString().isEmpty) {
          throw Exception('Session token not received from server');
        }

        
        int userId = 0;
        String? userIdField;

       
        final possibleFields = [
          'userid',
          'userId',
          'id',
          'user_id',
          'usermobileno',
        ];

        for (var field in possibleFields) {
          if (data.containsKey(field) && data[field] != null) {
            final value = data[field];
            userId = value is int ? value : int.tryParse(value.toString()) ?? 0;
            if (userId != 0) {
              userIdField = field;
              break;
            }
          }
        }

        print('========== USER ID EXTRACTION ==========');
        print('Found userId in field: $userIdField');
        print('Extracted userId: $userId');

        
        if (userId == 0) {
          print(' WARNING: userId not found in response');
          print(' All response fields:');
          if (data is Map) {
            data.forEach((key, value) {
              print('   $key: $value (${value.runtimeType})');
            });
          }

          
          userId = mobile.hashCode.abs() % 1000000;
          print(' Created userId from mobile: $userId');
        }
        print('========================================');

       
        final prefs = await SharedPreferences.getInstance();

        
        await prefs.setInt('user_id', userId);
        await prefs.setInt('userid', userId);
        await prefs.setInt('userId', userId);

       
        await prefs.setString('session_token', data['sessionToken'].toString());
        await prefs.setString('sessionToken', data['sessionToken'].toString());
        await prefs.setString('user_mobile', mobile);
        await prefs.setString('usermobile', mobile);
        await prefs.setString('user_name', name);
        await prefs.setString('username', name);
        await prefs.setString('usermame', name);
        await prefs.setString('user_status', userStatus);
        await prefs.setString('userstatus', userStatus);

        print('   Saved to SharedPreferences:');
        print('   userId (all variants): $userId');
        print('   mobile (all variants): $mobile');
        print('   name (all variants): $name');
        print(
          '   token saved: ${data['sessionToken'].toString().substring(0, 10)}...',
        );

        print('User added/updated successfully');

        // Return normalized response
        return {
          'sessionToken': data['sessionToken'].toString(),
          'userid': userId,
          'userId': userId,
          'user_id': userId,
          'usermobile': mobile,
          'usermame': name,
          'userstatus': data['userstatus'] ?? userStatus,
          ...data,
        };
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
      print('ERROR in addOrUpdateUser: $e');
      rethrow;
    }
  }

  
  static bool verifyOtp(String enteredOtp, String receivedOtp) {
    return enteredOtp.trim() == receivedOtp.trim();
  }
}
