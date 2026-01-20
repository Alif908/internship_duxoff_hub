import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WashHistoryPage extends StatefulWidget {
  const WashHistoryPage({super.key});

  @override
  State<WashHistoryPage> createState() => _WashHistoryPageState();
}

class _WashHistoryPageState extends State<WashHistoryPage> {
  List<Map<String, dynamic>> _historyList = [];
  List<Map<String, dynamic>> _filteredHistoryList = [];

  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// ✅ NEW: Load local bookings from SharedPreferences
  Future<List<Map<String, dynamic>>> _loadLocalBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      List<Map<String, dynamic>> localBookings = [];

      for (String key in allKeys) {
        if (key.startsWith('booking_')) {
          try {
            final bookingJson = prefs.getString(key);
            if (bookingJson != null && bookingJson.isNotEmpty) {
              final booking = jsonDecode(bookingJson) as Map<String, dynamic>;

              // Add source indicator
              booking['_source'] = 'local';
              booking['_key'] = key;

              localBookings.add(booking);
              debugPrint(
                '📦 Loaded local booking: $key with amount: ${booking['amount']}',
              );
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing booking $key: $e');
          }
        }
      }

      debugPrint('✅ Found ${localBookings.length} local bookings');
      return localBookings;
    } catch (e) {
      debugPrint('❌ Error loading local bookings: $e');
      return [];
    }
  }

  /// ✅ ENHANCED: Merge API data with local storage
  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load both API and local data
      final apiHistory = await HomeApi.getBookingHistory();
      final localBookings = await _loadLocalBookings();

      if (!mounted) return;

      // Create a merged list
      List<Map<String, dynamic>> mergedHistory = [];

      // Start with API data
      for (var apiItem in apiHistory) {
        final deviceId = apiItem['deviceid']?.toString();
        final endTime = apiItem['device_booked_user_end_time']?.toString();

        // Try to find matching local booking
        Map<String, dynamic>? matchingLocal;
        for (var localItem in localBookings) {
          if (localItem['deviceid']?.toString() == deviceId &&
              localItem['endtime']?.toString() == endTime) {
            matchingLocal = localItem;
            break;
          }
        }

        // If we found a match and API amount is 0, use local amount
        if (matchingLocal != null) {
          final apiAmount =
              double.tryParse(
                apiItem['booked_user_amount']?.toString() ?? '0',
              ) ??
              0.0;
          final localAmount =
              double.tryParse(matchingLocal['amount']?.toString() ?? '0') ??
              0.0;

          if (apiAmount == 0 && localAmount > 0) {
            apiItem['booked_user_amount'] = localAmount;
            apiItem['_amount_source'] = 'local';
            debugPrint(
              '✅ Using local amount for device $deviceId: ₹$localAmount',
            );
          }
        }

        mergedHistory.add(apiItem);
      }

      // Add local bookings that aren't in API response
      for (var localItem in localBookings) {
        final deviceId = localItem['deviceid']?.toString();
        final endTime = localItem['endtime']?.toString();

        bool existsInApi = mergedHistory.any(
          (apiItem) =>
              apiItem['deviceid']?.toString() == deviceId &&
              apiItem['device_booked_user_end_time']?.toString() == endTime,
        );

        if (!existsInApi) {
          // Convert local format to API format
          final normalizedLocal = {
            'deviceid': localItem['deviceid'],
            'hubname': localItem['hubname'],
            'hubid': localItem['hubid'],
            'machineid': localItem['machineid'],
            'booked_user_amount': localItem['amount'],
            'device_booked_user_end_time': localItem['endtime'],
            'device_booked_user_start_time': localItem['starttime'],
            'booked_user_selected_wash_mode': localItem['washmode'],
            'booked_user_selected_duration': localItem['washtime'],
            'booked_user_selected_detergent_preference': localItem['detergent'],
            'paymentid': localItem['paymentid'],
            '_source': 'local_only',
          };

          mergedHistory.add(normalizedLocal);
          debugPrint('✅ Added local-only booking for device $deviceId');
        }
      }

      // Sort by date (most recent first)
      mergedHistory.sort((a, b) {
        try {
          final aTimeStr =
              a['device_booked_user_end_time']?.toString() ??
              a['endtime']?.toString();
          final bTimeStr =
              b['device_booked_user_end_time']?.toString() ??
              b['endtime']?.toString();

          if (aTimeStr == null || aTimeStr.isEmpty) return 1;
          if (bTimeStr == null || bTimeStr.isEmpty) return -1;

          final dateA = DateTime.parse(aTimeStr);
          final dateB = DateTime.parse(bTimeStr);

          return dateB.compareTo(dateA);
        } catch (e) {
          debugPrint('⚠️ Error sorting dates: $e');
          return 0;
        }
      });

      setState(() {
        _historyList = mergedHistory;
        _filteredHistoryList = mergedHistory;
        _isLoading = false;
      });

      debugPrint('✅ Total history records: ${_historyList.length}');

      // Log amounts for verification
      for (
        var i = 0;
        i < (_historyList.length > 5 ? 5 : _historyList.length);
        i++
      ) {
        debugPrint(
          '  Record $i: ₹${_historyList[i]['booked_user_amount']} (source: ${_historyList[i]['_amount_source'] ?? 'api'})',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        String errorText = e.toString();
        if (errorText.startsWith('Exception: ')) {
          errorText = errorText.substring(11);
        }

        if (errorText.contains('Mobile number not found') ||
            errorText.contains('Session token not found') ||
            errorText.contains('Session expired') ||
            errorText.contains('not authenticated')) {
          _errorMessage = 'Session expired. Please login again.';
        } else if (errorText.contains('Authentication failed') ||
            errorText.contains('401')) {
          _errorMessage = 'Authentication failed. Please login again.';
        } else if (errorText.contains('No internet connection') ||
            errorText.contains('network')) {
          _errorMessage = 'Network error. Check your connection.';
        } else if (errorText.contains('timed out')) {
          _errorMessage = 'Request timed out. Please try again.';
        } else if (errorText.contains('404')) {
          _errorMessage = '';
          _historyList = [];
          _filteredHistoryList = [];
        } else {
          _errorMessage = errorText.isNotEmpty
              ? errorText
              : 'Failed to load history. Please try again.';
        }
      });

      debugPrint('❌ Error loading history: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredHistoryList = _historyList.where((booking) {
        final deviceType =
            booking['devicetype']?.toString().toLowerCase() ?? '';
        bool matchesFilter = true;

        if (_selectedFilter == 'Washer') {
          matchesFilter = deviceType.contains('washer');
        } else if (_selectedFilter == 'Dryer') {
          matchesFilter = deviceType.contains('dryer');
        }

        if (_searchQuery.isNotEmpty) {
          final hubName = booking['hubname']?.toString().toLowerCase() ?? '';
          final deviceId = booking['deviceid']?.toString() ?? '';
          final query = _searchQuery.toLowerCase();

          matchesFilter =
              matchesFilter &&
              (hubName.contains(query) || deviceId.contains(query));
        }

        return matchesFilter;
      }).toList();
    });
  }

  Map<String, dynamic> _calculateStats() {
    int totalWashes = 0;
    int totalDryers = 0;
    double totalAmount = 0;

    for (var booking in _historyList) {
      final deviceType = booking['devicetype']?.toString().toLowerCase() ?? '';
      if (deviceType.contains('washer')) {
        totalWashes++;
      } else if (deviceType.contains('dryer')) {
        totalDryers++;
      }

      final amount = booking['booked_user_amount'];
      if (amount != null) {
        totalAmount += double.tryParse(amount.toString()) ?? 0;
      }
    }

    return {
      'totalWashes': totalWashes,
      'totalDryers': totalDryers,
      'totalAmount': totalAmount,
    };
  }

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat('dd/MM/yyyy hh:mma').format(dateTime).toLowerCase();
    } catch (e) {
      debugPrint('⚠️ Error formatting date: $e');
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.grey[50],
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black87),
            onPressed: () {
              // Show filter bottom sheet
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (_historyList.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFF4A90E2),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredHistoryList.length,
        itemBuilder: (context, index) {
          final booking = _filteredHistoryList[index];
          return _buildHistoryCard(booking);
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> booking) {
    final hubName = booking['hubname']?.toString() ?? 'Unknown Hub';
    final deviceId = booking['deviceid']?.toString() ?? 'N/A';
    final endTime =
        booking['device_booked_user_end_time']?.toString() ??
        booking['endtime']?.toString() ??
        '';

    // Parse and format amount
    final amountValue = booking['booked_user_amount'];
    String amount = '0.00';
    if (amountValue != null) {
      final parsedAmount = double.tryParse(amountValue.toString()) ?? 0.0;
      amount = parsedAmount.toStringAsFixed(2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hub Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hubName.toLowerCase(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Machine',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '#$deviceId',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                endTime.isNotEmpty ? _formatDateTime(endTime) : 'N/A',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'QK WASH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A90E2),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹$amount',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No wash history yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed bookings will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
