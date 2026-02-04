import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/services/notification_service.dart';
import 'package:internship_duxoff_hub/views/home%20screen/qrscanning/machinelist_page.dart';
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

  final NotificationService _notificationService = NotificationService();

  // Track which jobs have had completion notifications sent
  static const String _prefNotificationSent = 'completion_notification_sent_';

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _cleanupDuplicateLocalBookings();
    _loadHistory();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
      debugPrint(' Notifications initialized in WashHistoryPage');
    } catch (e) {
      debugPrint(' Error initializing notifications: $e');
    }
  }

  /// Check if completion notification was sent for this job
  Future<bool> _wasCompletionNotificationSent(
      String deviceId, String endTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefNotificationSent${deviceId}_$endTime';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      debugPrint('❌ Error checking notification status: $e');
      return false;
    }
  }

  Future<void> _markCompletionNotificationSent(
      String deviceId, String endTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefNotificationSent${deviceId}_$endTime';
      await prefs.setBool(key, true);
      debugPrint('Marked completion notification sent: $key');
    } catch (e) {
      debugPrint(' Error marking notification sent: $e');
    }
  }

  Future<void> _sendCompletionNotificationForNewJobs(
      List<Map<String, dynamic>> localBookings) async {
    try {
      for (var booking in localBookings) {
        final deviceId = (booking['deviceid'] ?? '').toString();
        final endTime = (booking['endtime'] ?? '').toString();

        if (deviceId.isEmpty || endTime.isEmpty) continue;

        if (!await _wasCompletionNotificationSent(deviceId, endTime)) {
          try {
            final timestamp = booking['timestamp']?.toString();
            if (timestamp != null && timestamp.isNotEmpty) {
              final completedAt = DateTime.parse(timestamp);
              final now = DateTime.now();
              final diff = now.difference(completedAt);

              if (diff.inMinutes <= 5) {
                debugPrint('  NEW COMPLETED JOB DETECTED IN HISTORY!');
                debugPrint('   Device: $deviceId');
                debugPrint('   Completed: ${diff.inSeconds}s ago');
                debugPrint('   Sending completion notification...');

                final jobData = {
                  'deviceid': booking['deviceid'],
                  'hubname': booking['hubname'],
                  'hubid': booking['hubid'],
                  'device_booked_user_end_time': booking['endtime'],
                  'device_booked_user_start_time': booking['starttime'],
                  'booked_user_selected_wash_mode': booking['washmode'],
                  'booked_user_selected_duration': booking['washtime'],
                  'booked_user_amount': booking['amount'],
                };

                await _notificationService.showCompletionNotification(jobData);
                await _markCompletionNotificationSent(deviceId, endTime);

                debugPrint(' Completion notification sent for job in history');
              } else {
                debugPrint(
                    ' Job completed ${diff.inMinutes} min ago - skipping notification');
              }
            }
          } catch (e) {
            debugPrint(' Error checking job timestamp: $e');
          }
        }
      }
    } catch (e) {
      debugPrint(' Error sending completion notifications: $e');
    }
  }

  Future<void> _cleanupDuplicateLocalBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      Map<String, String> uniqueBookings = {};
      List<String> keysToRemove = [];

      for (String key in allKeys) {
        if (key.startsWith('booking_')) {
          try {
            final bookingJson = prefs.getString(key);
            if (bookingJson != null) {
              final booking = jsonDecode(bookingJson);
              final deviceId = (booking['deviceid'] ?? '').toString();
              final endTime = (booking['endtime'] ?? '').toString();

              if (deviceId.isNotEmpty && endTime.isNotEmpty) {
                final uniqueKey = '${deviceId}_$endTime';

                if (uniqueBookings.containsKey(uniqueKey)) {
                  keysToRemove.add(key);
                  debugPrint(
                    ' Marking duplicate local booking for removal: $key',
                  );
                } else {
                  uniqueBookings[uniqueKey] = key;
                }
              }
            }
          } catch (e) {
            debugPrint('Error checking $key: $e');
          }
        }
      }

      for (String key in keysToRemove) {
        await prefs.remove(key);
      }

      if (keysToRemove.isNotEmpty) {
        debugPrint(' Removed ${keysToRemove.length} duplicate local bookings');
      }
    } catch (e) {
      debugPrint('Error in cleanup: $e');
    }
  }

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
              booking['_source'] = 'local';
              booking['_key'] = key;
              localBookings.add(booking);
              debugPrint(
                'Loaded local booking: $key with amount: ${booking['amount']}',
              );
            }
          } catch (e) {
            debugPrint('Error parsing booking $key: $e');
          }
        }
      }

      debugPrint('Found ${localBookings.length} local bookings');
      return localBookings;
    } catch (e) {
      debugPrint('Error loading local bookings: $e');
      return [];
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final apiHistory = await HomeApi.getBookingHistory();
      final localBookings = await _loadLocalBookings();

      await _sendCompletionNotificationForNewJobs(localBookings);

      if (!mounted) return;

      debugPrint('========== DEDUPLICATION PROCESS ==========');
      debugPrint('API history count: ${apiHistory.length}');
      debugPrint('Local bookings count: ${localBookings.length}');

      Map<String, Map<String, dynamic>> uniqueBookings = {};

      for (var apiItem in apiHistory) {
        final deviceId = (apiItem['deviceid'] ?? '').toString();
        final endTimeRaw =
            (apiItem['device_booked_user_end_time'] ?? apiItem['endtime'] ?? '')
                .toString();

        if (deviceId.isEmpty || endTimeRaw.isEmpty) {
          debugPrint('Skipping API item with missing deviceId or endTime');
          continue;
        }

        String normalizedEndTime = endTimeRaw;
        try {
          final dt = DateTime.parse(endTimeRaw);
          normalizedEndTime =
              '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}Z';
        } catch (e) {
          debugPrint(' Could not parse timestamp: $endTimeRaw');
        }

        final uniqueKey = '${deviceId}_$normalizedEndTime';

        double apiAmount = 0.0;

        if (apiItem.containsKey('transactionamount') &&
            apiItem['transactionamount'] != null) {
          apiAmount =
              double.tryParse(apiItem['transactionamount'].toString()) ?? 0.0;
          debugPrint('Found transactionamount for $uniqueKey: ₹$apiAmount');
        }

        if (apiAmount == 0.0 &&
            apiItem.containsKey('booked_user_amount') &&
            apiItem['booked_user_amount'] != null) {
          apiAmount =
              double.tryParse(apiItem['booked_user_amount'].toString()) ?? 0.0;
          debugPrint('Using booked_user_amount for $uniqueKey: ₹$apiAmount');
        }

        if (uniqueBookings.containsKey(uniqueKey)) {
          final existingItem = uniqueBookings[uniqueKey]!;
          final existingAmount = double.tryParse(
                (existingItem['transactionamount'] ??
                        existingItem['booked_user_amount'] ??
                        '0')
                    .toString(),
              ) ??
              0.0;

          if (apiAmount > 0 && existingAmount == 0) {
            uniqueBookings[uniqueKey] = apiItem;
            debugPrint(
              'REPLACED duplicate with non-zero amount: $uniqueKey (₹$apiAmount replaces ₹$existingAmount)',
            );
          } else {
            debugPrint(
              'Duplicate found, keeping existing: $uniqueKey (existing: ₹$existingAmount, new: ₹$apiAmount)',
            );
          }
          continue;
        }

        // Find matching local booking to get amount if API amount is 0
        if (apiAmount == 0) {
          Map<String, dynamic>? matchingLocal;
          for (var localItem in localBookings) {
            final localDeviceId = (localItem['deviceid'] ?? '').toString();
            final localEndTimeRaw = (localItem['endtime'] ?? '').toString();

            String normalizedLocalEndTime = localEndTimeRaw;
            try {
              final dt = DateTime.parse(localEndTimeRaw);
              normalizedLocalEndTime =
                  '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}Z';
            } catch (e) {}

            if (localDeviceId == deviceId &&
                normalizedLocalEndTime == normalizedEndTime) {
              matchingLocal = localItem;
              break;
            }
          }

          if (matchingLocal != null) {
            final localAmount =
                double.tryParse((matchingLocal['amount'] ?? '0').toString()) ??
                    0.0;
            if (localAmount > 0) {
              apiItem['transactionamount'] = localAmount;
              apiItem['booked_user_amount'] = localAmount;
              debugPrint('Using local amount ₹$localAmount for $uniqueKey');
            }

            if ((apiItem['hubid'] == null ||
                    apiItem['hubid'].toString().isEmpty) &&
                matchingLocal['hubid'] != null) {
              apiItem['hubid'] = matchingLocal['hubid'];
              debugPrint(' Copied hubid from local: ${matchingLocal['hubid']}');
            }
            if ((apiItem['hubname'] == null ||
                    apiItem['hubname'].toString().isEmpty) &&
                matchingLocal['hubname'] != null) {
              apiItem['hubname'] = matchingLocal['hubname'];
              debugPrint(
                  ' Copied hubname from local: ${matchingLocal['hubname']}');
            }
          }
        }

        uniqueBookings[uniqueKey] = apiItem;
        final displayAmount =
            apiItem['transactionamount'] ?? apiItem['booked_user_amount'] ?? 0;
        debugPrint(
          'Added from API: $uniqueKey (₹$displayAmount)',
        );
      }

      for (var localItem in localBookings) {
        final deviceId = (localItem['deviceid'] ?? '').toString();
        final endTimeRaw = (localItem['endtime'] ?? '').toString();

        if (deviceId.isEmpty || endTimeRaw.isEmpty) {
          debugPrint(' Skipping local item with missing deviceId or endTime');
          continue;
        }

        String normalizedEndTime = endTimeRaw;
        try {
          final dt = DateTime.parse(endTimeRaw);
          normalizedEndTime =
              '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}Z';
        } catch (e) {
          debugPrint(' Could not parse timestamp: $endTimeRaw');
        }

        final uniqueKey = '${deviceId}_$normalizedEndTime';

        if (uniqueBookings.containsKey(uniqueKey)) {
          debugPrint(' Local booking already in API: $uniqueKey - SKIPPING');
          continue;
        }

        final normalizedLocal = {
          'deviceid': localItem['deviceid'],
          'hubname': localItem['hubname'],
          'hubid': localItem['hubid'],
          'machineid': localItem['machineid'],
          'transactionamount': localItem['amount'],
          'booked_user_amount': localItem['amount'],
          'device_booked_user_end_time': localItem['endtime'],
          'device_booked_user_start_time': localItem['starttime'],
          'booked_user_selected_wash_mode': localItem['washmode'],
          'booked_user_selected_duration': localItem['washtime'],
          'booked_user_selected_detergent_preference': localItem['detergent'],
          'paymentid': localItem['paymentid'],
          '_source': 'local_only',
        };

        uniqueBookings[uniqueKey] = normalizedLocal;
        debugPrint('Added local-only: $uniqueKey');
      }

      debugPrint('Total unique bookings: ${uniqueBookings.length}');

      List<Map<String, dynamic>> mergedHistory = uniqueBookings.values.toList();

      // Sort by end time (newest first)
      mergedHistory.sort((a, b) {
        try {
          final aTimeStr =
              (a['device_booked_user_end_time'] ?? a['endtime'] ?? '')
                  .toString();
          final bTimeStr =
              (b['device_booked_user_end_time'] ?? b['endtime'] ?? '')
                  .toString();

          if (aTimeStr.isEmpty) return 1;
          if (bTimeStr.isEmpty) return -1;

          final aDate = DateTime.parse(aTimeStr);
          final bDate = DateTime.parse(bTimeStr);
          return bDate.compareTo(aDate);
        } catch (e) {
          debugPrint('Error sorting: $e');
          return 0;
        }
      });

      debugPrint('========== FINAL RESULTS ==========');
      for (int i = 0;
          i < (mergedHistory.length > 3 ? 3 : mergedHistory.length);
          i++) {
        final item = mergedHistory[i];
        final amt =
            item['transactionamount'] ?? item['booked_user_amount'] ?? 0;
        debugPrint(
          ' [$i] Device: ${item['deviceid']}, Amount: ₹$amt, Time: ${item['device_booked_user_end_time'] ?? item['endtime']}',
        );
        debugPrint(
          '     HubId: ${item['hubid']}, HubName: ${item['hubname']}',
        );
      }
      debugPrint('=====================================');

      setState(() {
        _historyList = mergedHistory;
        _filteredHistoryList = mergedHistory;
        _isLoading = false;
      });

      debugPrint(
        ' Successfully loaded ${_historyList.length} unique history items',
      );
    } catch (e) {
      if (!mounted) return;

      String errorText = e.toString();
      if (errorText.startsWith('Exception: ')) {
        errorText = errorText.substring(11);
      }
      errorText = errorText.replaceAll(RegExp(r'https?://[^\s,)]+'), '');
      errorText = errorText.replaceAll(RegExp(r'uri=https?://[^\s,)]+'), '');
      errorText = errorText.replaceAll(RegExp(r'\(OS Error[^)]*\)'), '');

      setState(() {
        _isLoading = false;
        if (errorText.contains('ClientException') ||
            errorText.contains('SocketException') ||
            errorText.contains('Failed host lookup') ||
            errorText.contains('No address associated') ||
            errorText.contains('errno = 7')) {
          _errorMessage =
              'Unable to connect. Please check your internet connection.';
        } else if (errorText.contains('Mobile number not found') ||
            errorText.contains('Session token not found') ||
            errorText.contains('Session expired') ||
            errorText.contains('not authenticated')) {
          _errorMessage = 'Session expired. Please login again.';
        } else if (errorText.contains('Authentication failed') ||
            errorText.contains('401')) {
          _errorMessage = 'Authentication failed. Please login again.';
        } else if (errorText.toLowerCase().contains('timeout')) {
          _errorMessage = 'Connection timeout. Please try again.';
        } else if (errorText.contains('404')) {
          _errorMessage = '';
          _historyList = [];
          _filteredHistoryList = [];
        } else {
          _errorMessage = 'Unable to load history. Please try again.';
        }
      });

      debugPrint(' Error loading history: $e');
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
          matchesFilter = matchesFilter &&
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

      final amount =
          booking['transactionamount'] ?? booking['booked_user_amount'];
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
      debugPrint('Error formatting date: $e');
      return dateTimeString;
    }
  }

  Future<void> _navigateToHub(Map<String, dynamic> booking) async {
    final hubId = booking['hubid']?.toString();
    final hubName = booking['hubname']?.toString();

    debugPrint('========== NAVIGATING TO HUB ==========');
    debugPrint('Hub ID: $hubId');
    debugPrint('Hub Name: $hubName');
    debugPrint('Full booking data: $booking');

    if (hubId == null || hubId.isEmpty || hubId == 'null') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hub information not available'),
          backgroundColor: Color(0xFFF44336),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF4A90E2)),
        ),
      ),
    );

    try {
      debugPrint('Fetching hub details for hubId: $hubId');
      final devices = await HomeApi.getHubDetails(hubId: hubId);
      debugPrint('Successfully fetched ${devices.length} devices');

      if (!mounted) return;
      Navigator.pop(context);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MachineListPage(
            hubId: hubId,
            hubName: hubName ?? 'Unknown Hub',
            devices: devices,
          ),
        ),
      );

      debugPrint('Navigation successful');
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load hub: ${e.toString()}'),
          backgroundColor: const Color(0xFFF44336),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Retry',
            textColor: const Color(0xFFFFFFFF),
            onPressed: () => _navigateToHub(booking),
          ),
        ),
      );
    }
    debugPrint('=======================================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xDE000000),
            fontSize: 24,
          ),
        ),
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xDE000000)),
            onPressed: () {},
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
          valueColor: AlwaysStoppedAnimation(Color(0xFF4A90E2)),
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
    final hubId = booking['hubid']?.toString() ?? '';
    final deviceId = booking['deviceid']?.toString() ?? 'N/A';
    final endTime = booking['device_booked_user_end_time']?.toString() ??
        booking['endtime']?.toString() ??
        '';

    final amountValue =
        booking['transactionamount'] ?? booking['booked_user_amount'];
    double parsedAmount = 0.0;
    if (amountValue != null) {
      parsedAmount = double.tryParse(amountValue.toString()) ?? 0.0;
    }
    final amount = parsedAmount.toStringAsFixed(2);

    debugPrint(
        'History Card - Hub ID: $hubId, Hub Name: $hubName, Amount: ₹$amount');

    return GestureDetector(
      onTap: () {
        if (hubId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hub information not available'),
              backgroundColor: Color(0xFFF44336),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _navigateToHub(booking);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.04),
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
                          color: Color(0xDE000000),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hubName.toLowerCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF616161),
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
                          color: Color(0xDE000000),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '#$deviceId',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF616161),
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
                      color: Color(0xFFFFFFFF),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        endTime.isNotEmpty ? _formatDateTime(endTime) : 'N/A',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (hubId.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 14,
                              color: Color(0xFF1976D2),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Tap to view hub',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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
                        color: Color(0xDE000000),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFE57373)),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF616161),
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
                foregroundColor: const Color(0xFFFFFFFF),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Color(0xFFE0E0E0)),
          SizedBox(height: 16),
          Text(
            'No wash history yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF757575),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your completed bookings will appear here',
            style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }
}
