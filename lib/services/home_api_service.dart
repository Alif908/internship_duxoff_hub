import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeApi {
  static const String baseUrl = 'https://api.qkwash.com';
  static const Duration timeoutDuration = Duration(seconds: 30);

  /// Helper method to get user credentials
  /// Helper method to get user credentials
/// ✅ FIXED: Now checks both key variations for compatibility
static Future<Map<String, String>> _getUserCredentials() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Try both key variations (usermobile and user_mobile)
  final mobile = prefs.getString('usermobile') ?? 
                 prefs.getString('user_mobile');
  
  // Try both key variations (sessionToken and session_token)
  final token = prefs.getString('sessionToken') ?? 
                prefs.getString('session_token');

  print('🔍 Credential Check:');
  print('   usermobile: ${prefs.getString('usermobile')}');
  print('   user_mobile: ${prefs.getString('user_mobile')}');
  print('   sessionToken: ${prefs.getString('sessionToken')?.substring(0, 8)}...');
  print('   session_token: ${prefs.getString('session_token')?.substring(0, 8)}...');

  if (mobile == null || mobile.isEmpty) {
    throw Exception('Mobile number not found. Please login again.');
  }

  if (token == null || token.isEmpty) {
    throw Exception('Session token not found. Please login again.');
  }

  return {'mobile': mobile, 'token': token};
}

  /// GET USER PROFILE
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final credentials = await _getUserCredentials();
      final mobile = credentials['mobile']!;
      final token = credentials['token']!;

      print('========== DEBUG USER PROFILE API ==========');
      print('Mobile: $mobile');
      print(
        'Token: ${token.substring(0, token.length > 10 ? 10 : token.length)}...',
      );

      final requestBody = {"usermobile": mobile, "sessiontoken": token};

      print('Request URL: $baseUrl/api/settings/userProfile');
      print('Request Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/settings/userProfile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('===========================================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Successfully loaded user profile');
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to fetch user profile: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Invalid response format from server');
    } catch (e) {
      print('❌ ERROR in getUserProfile: $e');
      rethrow;
    }
  }

  /// GET RUNNING JOBS
  static Future<List<dynamic>> getRunningJobs() async {
    try {
      final credentials = await _getUserCredentials();
      final mobile = credentials['mobile']!;
      final token = credentials['token']!;

      print('========== DEBUG RUNNING JOBS API ==========');
      print('Mobile: $mobile');
      print(
        'Token: ${token.substring(0, token.length > 10 ? 10 : token.length)}...',
      );

      final requestBody = {"usermobile": mobile, "sessiontoken": token};

      print('Request URL: $baseUrl/api/user/runningjobs');
      print('Request Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/user/runningjobs'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('===========================================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          print('✅ Successfully loaded ${data.length} running jobs');

          // Convert all items to Map<String, dynamic>
          return data.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          }).toList();
        } else {
          print('⚠️ Unexpected response format, returning empty list');
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        print('ℹ️ No running jobs found');
        return [];
      } else {
        throw Exception('Failed to fetch running jobs: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Invalid response format from server');
    } catch (e) {
      print('❌ ERROR in getRunningJobs: $e');
      rethrow;
    }
  }

  /// GET BOOKING HISTORY
  /// ✅ ENHANCED: Merges history from both /history and completed jobs from /runningjobs
  static Future<List<Map<String, dynamic>>> getBookingHistory() async {
    try {
      final credentials = await _getUserCredentials();
      final mobile = credentials['mobile']!;
      final token = credentials['token']!;

      print('========== DEBUG BOOKING HISTORY API ==========');
      print('Mobile: $mobile');
      print(
        'Token: ${token.substring(0, token.length > 10 ? 10 : token.length)}...',
      );

      final requestBody = {"usermobile": mobile, "sessiontoken": token};

      print('Request URL: $baseUrl/api/user/history');
      print('Request Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/user/history'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      List<Map<String, dynamic>> historyList = [];

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          print(
            '✅ Successfully loaded ${data.length} history records from /history',
          );

          historyList = data.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          }).toList();
        } else if (data is Map &&
            data.containsKey('data') &&
            data['data'] is List) {
          print('✅ Found wrapped response format');
          final List dataList = data['data'] as List;
          historyList = dataList.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          }).toList();
        }
      } else if (response.statusCode == 404) {
        print('ℹ️ No booking history found in /history endpoint (404)');
      } else if (response.statusCode != 401) {
        print('⚠️ History API returned ${response.statusCode}, continuing...');
      }

      // ✅ NEW: Fetch completed jobs from running jobs endpoint
      print('🔍 Checking /runningjobs for completed jobs...');
      try {
        final runningJobs = await getRunningJobs();
        final now = DateTime.now();

        int completedFromRunning = 0;

        for (var job in runningJobs) {
          final endTimeString = job['device_booked_user_end_time']?.toString();
          if (endTimeString != null && endTimeString.isNotEmpty) {
            try {
              final endTime = DateTime.parse(endTimeString).toLocal();

              // If job is completed (end time passed)
              if (now.isAfter(endTime)) {
                // Check if this job already exists in history (by deviceid and endtime)
                final exists = historyList.any(
                  (h) =>
                      h['deviceid']?.toString() ==
                          job['deviceid']?.toString() &&
                      h['device_booked_user_end_time']?.toString() ==
                          endTimeString,
                );

                if (!exists) {
                  historyList.add(job);
                  completedFromRunning++;
                }
              }
            } catch (e) {
              print('⚠️ Error parsing job end time: $e');
            }
          }
        }

        if (completedFromRunning > 0) {
          print(
            '✅ Added $completedFromRunning completed jobs from /runningjobs',
          );
        }
      } catch (e) {
        print('⚠️ Could not fetch running jobs for history merge: $e');
      }

      print('📊 Total history records: ${historyList.length}');
      print('===============================================');

      return historyList;
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Invalid response format from server');
    } catch (e) {
      print('❌ ERROR in getBookingHistory: $e');
      rethrow;
    }
  }

  /// GET HUB DETAILS (after QR scan)
  static Future<List<dynamic>> getHubDetails({required String hubId}) async {
    try {
      final credentials = await _getUserCredentials();
      final mobile = credentials['mobile']!;
      final token = credentials['token']!;

      print('========== DEBUG HUB DETAILS API ==========');
      print('Hub ID: $hubId');
      print('Mobile: $mobile');
      print(
        'Token: ${token.substring(0, token.length > 10 ? 10 : token.length)}...',
      );

      final requestBody = {
        "hubId": hubId,
        "usermobile": mobile,
        "sessionToken": token,
      };

      print('Request URL: $baseUrl/api/hubs/hubs/details');
      print('Request Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/hubs/hubs/details'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('==========================================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          print('✅ Successfully loaded ${data.length} devices');
          return data;
        } else {
          print('⚠️ Unexpected response format, returning empty list');
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Hub not found. Please scan a valid QR code.');
      } else {
        throw Exception('Failed to fetch hub details: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Invalid response format from server');
    } catch (e) {
      print('❌ ERROR in getHubDetails: $e');
      rethrow;
    }
  }

  /// CREATE PAYMENT ORDER
  static Future<Map<String, dynamic>> createPaymentOrder({
    required int amount,
    required int userId,
  }) async {
    try {
      final requestBody = {"amount": amount, "userId": userId};

      print('========== DEBUG CREATE PAYMENT ORDER ==========');
      print('Request URL: $baseUrl/api/users/createOrder');
      print('Request Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/users/createOrder'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('===============================================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!data.containsKey('success') || !data.containsKey('orderId')) {
          throw Exception('Invalid payment order response');
        }

        print('✅ Payment order created successfully');
        return data;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Invalid payment details');
      } else {
        throw Exception(
          'Failed to create payment order: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Invalid response format from server');
    } catch (e) {
      print('❌ ERROR in createPaymentOrder: $e');
      rethrow;
    }
  }

  /// BOOK DEVICE
  static Future<Map<String, dynamic>> bookDevice({
    required String hubId,
    required int deviceId,
    required String deviceCondition,
    required String deviceStatus,
    required String mobileNumber,
    required String startTime,
    required String endTime,
    required String washMode,
    required String detergentPreference,
    required String duration,
    required String transactionStatus,
    required String paymentId,
    required String transactionTime,
    required int transactionAmount,
    required String sessionToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('sessionToken');
      final storedMobile = prefs.getString('usermobile');

      final token = sessionToken;
      final mobile = mobileNumber.isNotEmpty
          ? mobileNumber
          : (storedMobile ?? '');

      if (token.isEmpty || mobile.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url = Uri.parse('$baseUrl/api/hubs/hubs/book');

      final body = {
        'hubid': hubId,
        'deviceid': deviceId,
        'devicecondition': deviceCondition,
        'devicestatus': deviceStatus,
        'device_booked_user_mobile_no': mobile,
        'device_booked_user_start_time': startTime,
        'device_booked_user_end_time': endTime,
        'booked_user_selected_wash_mode': washMode,
        'booked_user_selected_detergent_preference': detergentPreference,
        'booked_user_selected_duration': duration,
        'transactionstatus': transactionStatus,
        'paymentid': paymentId,
        'transactiontime': transactionTime,
        'transactionamount': transactionAmount,
        'sessiontoken': token,
      };

      debugPrint('📤 Booking device: $deviceId at hub: $hubId');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timed out'),
          );

      debugPrint('📥 Booking response status: ${response.statusCode}');
      debugPrint('📥 Booking response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data is Map<String, dynamic>) {
          if (data['success'] == true ||
              data['message']?.toString().toLowerCase().contains('success') ==
                  true) {
            return {
              'success': true,
              'message': data['message'] ?? 'Booking successful',
              'data': data,
            };
          } else {
            throw Exception(data['message'] ?? 'Booking failed');
          }
        } else if (data is List && data.isNotEmpty) {
          return {
            'success': true,
            'message': 'Booking successful',
            'data': data[0],
          };
        } else {
          return {
            'success': true,
            'message': 'Booking successful',
            'data': data,
          };
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Invalid booking request');
      } else {
        throw Exception('Booking failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Booking error: $e');
      rethrow;
    }
  }
}
