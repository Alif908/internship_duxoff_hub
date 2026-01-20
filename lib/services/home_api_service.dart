import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

      debugPrint('========== DEBUG BOOKING HISTORY API ==========');

      final requestBody = {"usermobile": mobile, "sessiontoken": token};

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/user/history'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeoutDuration);

      debugPrint('Response Status: ${response.statusCode}');

      debugPrint('========== RAW API RESPONSE START ==========');
      debugPrint(response.body);
      debugPrint('========== RAW API RESPONSE END ==========');

      List<Map<String, dynamic>> historyList = [];

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          debugPrint(' Response is a List with ${data.length} items');

          // Print FIRST 2 items in COMPLETE detail
          for (int i = 0; i < (data.length > 2 ? 2 : data.length); i++) {
            debugPrint('========== ITEM $i COMPLETE RAW DATA ==========');
            final item = data[i];
            if (item is Map) {
              debugPrint(jsonEncode(item));
              debugPrint('------- Field by field breakdown: -------');
              item.forEach((key, value) {
                debugPrint('  [$key]: $value (${value.runtimeType})');
              });
            }
            debugPrint('=============================================');
          }

          historyList = data.map((item) {
            if (item is Map<String, dynamic>) {
              return _normalizeHistoryItem(item);
            } else if (item is Map) {
              return _normalizeHistoryItem(Map<String, dynamic>.from(item));
            }
            return <String, dynamic>{};
          }).toList();
        } else if (data is Map &&
            data.containsKey('data') &&
            data['data'] is List) {
          debugPrint(' Response is wrapped in data object');
          final List dataList = data['data'] as List;

          for (
            int i = 0;
            i < (dataList.length > 2 ? 2 : dataList.length);
            i++
          ) {
            debugPrint('========== ITEM $i COMPLETE RAW DATA ==========');
            final item = dataList[i];
            if (item is Map) {
              debugPrint(jsonEncode(item));
              debugPrint('------- Field by field breakdown: -------');
              item.forEach((key, value) {
                debugPrint('  [$key]: $value (${value.runtimeType})');
              });
            }
            debugPrint('=============================================');
          }

          historyList = dataList.map((item) {
            if (item is Map<String, dynamic>) {
              return _normalizeHistoryItem(item);
            } else if (item is Map) {
              return _normalizeHistoryItem(Map<String, dynamic>.from(item));
            }
            return <String, dynamic>{};
          }).toList();
        }
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No booking history found (404)');
      }

      debugPrint('🔍 Checking /runningjobs for completed jobs...');
      try {
        final runningJobs = await getRunningJobs();
        final now = DateTime.now();
        int completedFromRunning = 0;

        for (var job in runningJobs) {
          final endTimeString = job['device_booked_user_end_time']?.toString();
          if (endTimeString != null && endTimeString.isNotEmpty) {
            try {
              final endTime = DateTime.parse(endTimeString).toLocal();
              if (now.isAfter(endTime)) {
                final exists = historyList.any(
                  (h) =>
                      h['deviceid']?.toString() ==
                          job['deviceid']?.toString() &&
                      h['device_booked_user_end_time']?.toString() ==
                          endTimeString,
                );
                if (!exists) {
                  debugPrint('📋 Adding completed job from runningjobs:');
                  debugPrint('========== RUNNING JOB COMPLETE DATA ==========');
                  debugPrint(jsonEncode(job));
                  job.forEach((key, value) {
                    debugPrint('  [$key]: $value');
                  });
                  debugPrint('=============================================');

                  historyList.add(_normalizeHistoryItem(job));
                  completedFromRunning++;
                }
              }
            } catch (e) {
              debugPrint(' Error parsing job end time: $e');
            }
          }
        }

        if (completedFromRunning > 0) {
          debugPrint(
            ' Added $completedFromRunning completed jobs from /runningjobs',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Could not fetch running jobs: $e');
      }

      debugPrint('========== FINAL NORMALIZED AMOUNTS ==========');
      for (
        int i = 0;
        i < (historyList.length > 5 ? 5 : historyList.length);
        i++
      ) {
        debugPrint(
          '   Item $i amount: ${historyList[i]['booked_user_amount']}',
        );
      }
      debugPrint('=============================================');

      debugPrint('📊 Total history records: ${historyList.length}');
      debugPrint('===============================================');

      return historyList;
    } catch (e) {
      debugPrint(' ERROR in getBookingHistory: $e');
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
      debugPrint(' Using existing booked_user_amount: $existingAmount');
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
          debugPrint('✅ Successfully loaded ${data.length} devices');
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
      debugPrint('❌ ERROR in getHubDetails: $e');
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

  /// BOOK DEVICE
  /// ENHANCED BOOK DEVICE - Added response logging
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

      debugPrint('========== BOOKING DEVICE ==========');
      debugPrint('📤 Sending booking request:');
      debugPrint('   Amount: $transactionAmount');
      debugPrint('   Payment ID: $paymentId');
      debugPrint('   Mobile: $mobile');
      debugPrint('   Device ID: $deviceId');
      debugPrint('   Full body: ${jsonEncode(body)}');

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

      debugPrint('📥 Booking response status: ${response.statusCode}');
      debugPrint('📥 Booking response body:');
      debugPrint(response.body);
      debugPrint('====================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // ✅ Log what the booking API returns
        debugPrint('✅ Booking successful. Response data:');
        if (data is Map) {
          data.forEach((key, value) {
            debugPrint('  [$key]: $value');
          });
        }

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
      debugPrint('❌ Booking error: $e');
      rethrow;
    }
  }

  /// ALTERNATE SOLUTION: Store booking locally if API doesn't return amount
  /// Add this to your bookDevice success block in PaymentDetailsPage:
  ///
  /// After successful booking, save locally:
  /// ```dart
  /// final prefs = await SharedPreferences.getInstance();
  /// final bookingKey = 'booking_${deviceId}_${DateTime.now().millisecondsSinceEpoch}';
  /// await prefs.setString(bookingKey, jsonEncode({
  ///   'deviceid': widget.deviceId,
  ///   'hubname': widget.hubName,
  ///   'amount': _currentAmount,
  ///   'endTime': endTime,
  ///   'timestamp': DateTime.now().toIso8601String(),
  /// }));
  /// ```
  ///
  /// Then in WashHistoryPage, merge local data with API data
}
