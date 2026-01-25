import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeApi {
  static const String baseUrl = 'https://api.qkwash.com';
  static const Duration timeoutDuration = Duration(seconds: 30);

  static Future<Map<String, String>> _getUserCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    final mobile =
        prefs.getString('user_mobile') ?? prefs.getString('usermobile') ?? '';
    final token =
        prefs.getString('session_token') ??
        prefs.getString('sessionToken') ??
        '';

    debugPrint('🔍 Credential Check:');
    debugPrint('   Final mobile: $mobile');
    debugPrint('   Final token exists: ${token.isNotEmpty}');

    if (mobile.isEmpty) {
      throw Exception('Mobile number not found. Please login again.');
    }

    if (token.isEmpty) {
      throw Exception('Session token not found. Please login again.');
    }

    return {'mobile': mobile, 'token': token};
  }

  static Future<List<Map<String, dynamic>>> getBookingHistory() async {
    try {
      final credentials = await _getUserCredentials();
      final mobile = credentials['mobile']!;
      final token = credentials['token']!;

      debugPrint('========== FETCHING BOOKING HISTORY ==========');

      final requestBody = {"usermobile": mobile, "sessiontoken": token};

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/user/history'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      debugPrint('Response Status: ${response.statusCode}');

      // Use Map to deduplicate at API level
      Map<String, Map<String, dynamic>> uniqueHistoryMap = {};

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<dynamic> rawList = [];
        if (data is List) {
          rawList = data;
        } else if (data is Map &&
            data.containsKey('data') &&
            data['data'] is List) {
          rawList = data['data'] as List;
        }

        debugPrint('📊 Raw API items: ${rawList.length}');

        for (var item in rawList) {
          if (item == null || item is! Map) continue;

          final itemMap = item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item);

          final normalized = _normalizeHistoryItem(itemMap);

          // Create unique key
          final deviceId = (normalized['deviceid'] ?? '').toString();
          final endTime = (normalized['device_booked_user_end_time'] ?? '')
              .toString();

          if (deviceId.isEmpty || endTime.isEmpty) {
            debugPrint('⚠️ Skipping item with missing deviceId or endTime');
            continue;
          }

          final uniqueKey = '${deviceId}_$endTime';

          // Only add if not already in map
          if (!uniqueHistoryMap.containsKey(uniqueKey)) {
            uniqueHistoryMap[uniqueKey] = normalized;
            debugPrint(
              '✅ Added history item: $uniqueKey, Amount: ${normalized['booked_user_amount']}',
            );
          } else {
            debugPrint(
              '⚠️ Duplicate detected in API response: $uniqueKey - SKIPPING',
            );
          }
        }
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No booking history found (404)');
        return [];
      }

      // Check running jobs for completed ones
      debugPrint('🔍 Checking /runningjobs for completed jobs...');
      try {
        final runningJobs = await getRunningJobs();
        final now = DateTime.now();

        for (var job in runningJobs) {
          final endTimeString = (job['device_booked_user_end_time'] ?? '')
              .toString();
          if (endTimeString.isEmpty) continue;

          try {
            final endTime = DateTime.parse(endTimeString).toLocal();
            if (now.isAfter(endTime)) {
              final deviceId = (job['deviceid'] ?? '').toString();
              final uniqueKey = '${deviceId}_$endTimeString';

              // Only add if not already in history
              if (!uniqueHistoryMap.containsKey(uniqueKey)) {
                uniqueHistoryMap[uniqueKey] = _normalizeHistoryItem(job);
                debugPrint(
                  '✅ Added completed job from runningjobs: $uniqueKey',
                );
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing job end time: $e');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Could not fetch running jobs: $e');
      }

      final historyList = uniqueHistoryMap.values.toList();
      debugPrint('📊 Total unique history records: ${historyList.length}');
      debugPrint('===============================================');

      return historyList;
    } catch (e) {
      debugPrint('❌ ERROR in getBookingHistory: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> _normalizeHistoryItem(Map<String, dynamic> item) {
    final normalized = Map<String, dynamic>.from(item);

    debugPrint('🔍 Normalizing item - Searching for amount field...');

    final existingAmount = normalized['booked_user_amount'];
    if (existingAmount != null &&
        existingAmount.toString() != '0' &&
        existingAmount.toString().isNotEmpty) {
      debugPrint('✅ Using existing booked_user_amount: $existingAmount');
      return normalized;
    }

    // Try all possible amount field names
    final possibleAmountFields = [
      'transactionamount',
      'transactionAmount',
      'transaction_amount',
      'booked_user_amount',
      'bookedUserAmount',
      'amount',
      'paymentAmount',
      'payment_amount',
      'totalAmount',
      'total_amount',
      'price',
      'total',
      'cost',
      'totalCost',
      'total_cost',
      'fare',
      'charge',
      'fee',
      'booked_amount',
      'booking_amount',
      'user_amount',
      'paymentid',
      'payment_id',
    ];

    bool foundAmount = false;
    for (var field in possibleAmountFields) {
      final value = normalized[field];
      if (value != null &&
          value.toString() != '0' &&
          value.toString().isNotEmpty &&
          value.toString() != 'null') {
        normalized['booked_user_amount'] = value;
        debugPrint(
          '✅ Found amount in [$field]: $value → Setting booked_user_amount',
        );
        foundAmount = true;
        break;
      }
    }

    if (!foundAmount) {
      // Print ALL fields to help debug
      debugPrint('⚠️ No standard amount field found. ALL FIELDS IN THIS ITEM:');
      item.forEach((key, value) {
        debugPrint('  [$key]: $value (${value.runtimeType})');
      });

      // Set to 0 as fallback
      normalized['booked_user_amount'] = 0;
      debugPrint('⚠️ Defaulting booked_user_amount to 0');
    }

    return normalized;
  }

  /// GET USER PROFILE
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final credentials = await _getUserCredentials();
      final mobile = credentials['mobile']!;
      final token = credentials['token']!;

      final requestBody = {"usermobile": mobile, "sessiontoken": token};

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/settings/userProfile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Successfully loaded user profile');
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to fetch user profile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ ERROR in getUserProfile: $e');
      rethrow;
    }
  }

  /// GET RUNNING JOBS
  static Future<List<dynamic>> getRunningJobs() async {
    try {
      final credentials = await _getUserCredentials();
      final mobile = credentials['mobile']!;
      final token = credentials['token']!;

      final requestBody = {"usermobile": mobile, "sessiontoken": token};

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/user/runningjobs'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          debugPrint('✅ Successfully loaded ${data.length} running jobs');
          return data.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          }).toList();
        } else {
          debugPrint('⚠️ Unexpected response format, returning empty list');
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No running jobs found');
        return [];
      } else {
        throw Exception('Failed to fetch running jobs: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ ERROR in getRunningJobs: $e');
      rethrow;
    }
  }

  /// GET HUB DETAILS (after QR scan)
  static Future<List<dynamic>> getHubDetails({required String hubId}) async {
    try {
      final credentials = await _getUserCredentials();
      final mobile = credentials['mobile']!;
      final token = credentials['token']!;

      final requestBody = {
        "hubId": hubId,
        "usermobile": mobile,
        "sessionToken": token,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/hubs/hubs/details'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          debugPrint("✅ Successfully loaded ${data.length} devices");
          return data;
        } else {
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Hub not found. Please scan a valid QR code.');
      } else {
        throw Exception('Failed to fetch hub details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("❌ Error in getHubDetails: $e");
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

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/users/createOrder'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          if (data.containsKey('orderId') && data['orderId'] != null) {
            return {
              'success': true,
              'orderId': data['orderId'].toString(),
              'amount': data['amount'] ?? amount,
              'currency': data['currency'] ?? 'INR',
            };
          }

          if (data.containsKey('success') && data['success'] == true) {
            if (data.containsKey('orderId') && data['orderId'] != null) {
              return {
                'success': true,
                'orderId': data['orderId'].toString(),
                'amount': data['amount'] ?? amount,
                'currency': data['currency'] ?? 'INR',
              };
            } else if (data.containsKey('data') && data['data'] is Map) {
              final nestedData = data['data'] as Map<String, dynamic>;
              if (nestedData.containsKey('orderId')) {
                return {
                  'success': true,
                  'orderId': nestedData['orderId'].toString(),
                  'amount': nestedData['amount'] ?? amount,
                  'currency': nestedData['currency'] ?? 'INR',
                };
              }
            }
          }

          if (data.containsKey('id') && data['id'] != null) {
            return {
              'success': true,
              'orderId': data['id'].toString(),
              'amount': data['amount'] ?? amount,
              'currency': data['currency'] ?? 'INR',
            };
          }

          throw Exception('Invalid payment order response: orderId not found');
        } else {
          throw Exception('Invalid response format from server');
        }
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Invalid payment details');
      } else {
        throw Exception(
          'Failed to create payment order: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ ERROR in createPaymentOrder: $e');
      rethrow;
    }
  }

  /// BOOK DEVICE - FIXED VERSION
  /// ⚠️ CRITICAL: Always posts devicestatus as "0" for running jobs to work
  static Future<Map<String, dynamic>> bookDevice({
    required String hubId,
    required int deviceId,
    required String deviceCondition,

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
      final storedToken =
          prefs.getString('session_token') ??
          prefs.getString('sessionToken') ??
          sessionToken;
      final storedMobile =
          prefs.getString('user_mobile') ??
          prefs.getString('usermobile') ??
          mobileNumber;

      final token = storedToken.isNotEmpty ? storedToken : sessionToken;
      final mobile = storedMobile.isNotEmpty ? storedMobile : mobileNumber;

      if (token.isEmpty || mobile.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url = Uri.parse('$baseUrl/api/hubs/hubs/book');

      // ✅ CRITICAL FIX: FORCE devicestatus to "0" for running jobs
      // The deviceStatus parameter is IGNORED - we always use "0"
      // This ensures the booking appears in /api/user/runningjobs endpoint
      final body = {
        'hubid': hubId,
        'deviceid': deviceId,
        'devicecondition': deviceCondition,
        'devicestatus': "0", // ⚠️ HARDCODED TO "0" - DO NOT CHANGE
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

      debugPrint('========== BOOKING DEVICE ==========');
      debugPrint('📤 Booking Request Details:');
      debugPrint('   Hub ID: $hubId');
      debugPrint('   Device ID: $deviceId');
      debugPrint('   Device Status: 0 ');
      debugPrint('   Device Condition: $deviceCondition');
      debugPrint('   Mobile: $mobile');
      debugPrint('   Wash Mode: $washMode');
      debugPrint('   Duration: $duration');
      debugPrint('   Amount: ₹$transactionAmount');
      debugPrint('   Payment ID: $paymentId');
      debugPrint('   Start Time: $startTime');
      debugPrint('   End Time: $endTime');
      debugPrint('   Transaction Status: $transactionStatus');
      debugPrint('');
      debugPrint('📋 Full Request Body:');
      debugPrint(jsonEncode(body));
      debugPrint('====================================');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timed out'),
          );

      debugPrint('');
      debugPrint('========== BOOKING RESPONSE ==========');
      debugPrint('📥 Status Code: ${response.statusCode}');
      debugPrint('📥 Response Body:');
      debugPrint(response.body);
      debugPrint('======================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        debugPrint('');
        debugPrint('✅ BOOKING SUCCESSFUL');
        debugPrint('📊 Response Data Fields:');
        if (data is Map) {
          data.forEach((key, value) {
            debugPrint('   [$key]: $value');
          });
        }
        debugPrint('');
        debugPrint('⏱️  Job should appear in running jobs within 10 seconds');
        debugPrint('🔄 HomePage refreshes every 10 seconds');
        debugPrint('🔄 RunningJobsPage refreshes every 10 seconds');
        debugPrint('======================================');

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
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Invalid booking request');
      } else {
        throw Exception('Booking failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('');
      debugPrint('❌ ========== BOOKING ERROR ==========');
      debugPrint('❌ Error Details: $e');
      debugPrint('❌ ====================================');
      rethrow;
    }
  }
}
