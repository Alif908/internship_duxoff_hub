import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/views/home%20screen/notification_page.dart';
import 'package:internship_duxoff_hub/views/home%20screen/qrscanning/machinelist_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _hasRunningJob = false;
  bool _isLoadingJob = true;
  bool _isLoadingHistory = true;

  Map<String, dynamic>? _runningJob;
  List<dynamic> _historyList = [];

  String _errorMessageJob = '';
  String _errorMessageHistory = '';

  Timer? _progressTimer;
  Timer? _apiRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchRunningJob();
    _fetchHistory();

    _apiRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
  if (mounted) {
    _fetchRunningJob();
  }
});


    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _hasRunningJob) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _apiRefreshTimer?.cancel();
    super.dispose();
  }

  double _calculateProgress({
    required String? startTimeString,
    required String? endTimeString,
  }) {
    if (endTimeString == null || endTimeString.isEmpty) {
      debugPrint('Progress: No end time provided');
      return 0.0;
    }

    try {
      final DateTime now = DateTime.now();
      DateTime endTime = DateTime.parse(endTimeString);

      if (endTime.isUtc || endTimeString.endsWith('Z')) {
        endTime = endTime.toLocal();
      }

      debugPrint('⏰ [HomePage] Current Time: $now');
      debugPrint('⏰ [HomePage] End Time: $endTime');

      if (now.isAfter(endTime)) {
        debugPrint('[HomePage] Job Completed: 100%');
        return 1.0;
      }

      if (startTimeString != null && startTimeString.isNotEmpty) {
        DateTime startTime = DateTime.parse(startTimeString);

        if (startTime.isUtc || startTimeString.endsWith('Z')) {
          startTime = startTime.toLocal();
        }

        debugPrint('[HomePage] Start Time: $startTime');

        if (now.isBefore(startTime)) {
          debugPrint('[HomePage] Job not started yet: 0%');
          return 0.0;
        }

        final int totalSeconds = endTime.difference(startTime).inSeconds;
        final int elapsedSeconds = now.difference(startTime).inSeconds;

        debugPrint(
          '[HomePage] Total Duration: ${totalSeconds}s (${(totalSeconds / 60).toStringAsFixed(1)} min)',
        );
        debugPrint(
          '[HomePage] Elapsed: ${elapsedSeconds}s (${(elapsedSeconds / 60).toStringAsFixed(1)} min)',
        );

        if (totalSeconds <= 0) {
          debugPrint('[HomePage] Invalid duration');
          return 0.0;
        }

        double progress = elapsedSeconds / totalSeconds;
        int progressPercent = (progress * 100).toInt();

        debugPrint('🔄 [HomePage] Progress: $progressPercent% completed');

        return progress.clamp(0.0, 1.0);
      } else {
        debugPrint('[HomePage] No start time - using estimation');

        final Duration remainingTime = endTime.difference(now);
        final int remainingMinutes = remainingTime.inMinutes;

        debugPrint('[HomePage] Remaining: ${remainingMinutes} minutes');

        const int assumedTotalMinutes = 15;
        final int elapsedMinutes = assumedTotalMinutes - remainingMinutes;

        debugPrint(
          '[HomePage] Estimated Elapsed: $elapsedMinutes minutes (assumed total: $assumedTotalMinutes min)',
        );

        if (elapsedMinutes <= 0) {
          debugPrint('[HomePage] Progress: 5% completed (minimum)');
          return 0.05;
        }

        double progress = elapsedMinutes / assumedTotalMinutes;
        int progressPercent = (progress * 100).toInt();

        debugPrint(
          '[HomePage] Progress: $progressPercent% completed (estimated)',
        );

        return progress.clamp(0.05, 1.0);
      }
    } catch (e) {
      debugPrint('[HomePage] Error calculating progress: $e');
      debugPrint('[HomePage] Start Time String: $startTimeString');
      debugPrint('[HomePage] End Time String: $endTimeString');
      return 0.0;
    }
  }

  Future<void> _fetchRunningJob() async {
    if (!mounted) return;

    final bool isInitialLoad = _runningJob == null && !_hasRunningJob;

    setState(() {
      if (isInitialLoad) {
        _isLoadingJob = true;
      }
      _errorMessageJob = '';
    });

    try {
      final List<dynamic> jobs = await HomeApi.getRunningJobs();

      if (!mounted) return;

      if (jobs.isEmpty) {
        setState(() {
          _hasRunningJob = false;
          _runningJob = null;
          _isLoadingJob = false;
        });
        debugPrint('ℹ️ [HomePage] No running jobs found');
        return;
      }

      final DateTime now = DateTime.now();

      final List<dynamic> activeJobs = jobs.where((job) {
        if (job == null || job is! Map) return false;

        final String? endTimeString = job['device_booked_user_end_time']
            ?.toString();

        if (endTimeString == null || endTimeString.isEmpty) {
          return false;
        }

        try {
          final DateTime endTime = DateTime.parse(endTimeString).toLocal();
          return now.isBefore(endTime);
        } catch (e) {
          debugPrint('⚠️ [HomePage] Invalid end time format: $endTimeString');
          return false;
        }
      }).toList();

      if (activeJobs.isNotEmpty) {
        setState(() {
          _runningJob = activeJobs[0] as Map<String, dynamic>;
          _hasRunningJob = true;
          _isLoadingJob = false;
        });

        debugPrint(
          '[HomePage] Running job loaded: ${activeJobs.length} active',
        );
      } else {
        setState(() {
          _hasRunningJob = false;
          _runningJob = null;
          _isLoadingJob = false;
        });
        debugPrint('ℹ️ [HomePage] No active running jobs');
      }
    } catch (e) {
      if (!mounted) return;

      // Sanitize error message - remove URLs and sensitive info
      String errorText = e.toString();

      // Remove Exception prefix
      if (errorText.startsWith('Exception: ')) {
        errorText = errorText.substring(11);
      }

      // Remove any URLs from error messages
      errorText = errorText.replaceAll(RegExp(r'https?://[^\s,)]+'), '[API]');
      errorText = errorText.replaceAll(RegExp(r'uri=https?://[^\s,)]+'), '');

      setState(() {
        _hasRunningJob = false;
        _runningJob = null;
        _isLoadingJob = false;

        // Provide user-friendly error messages without exposing infrastructure
        if (errorText.contains('SocketException') ||
            errorText.contains('Failed host lookup') ||
            errorText.contains('No address associated')) {
          _errorMessageJob =
              'Unable to connect. Please check your internet connection.';
        } else if (errorText.contains('not authenticated') ||
            errorText.contains('Session token') ||
            errorText.contains('Session expired')) {
          _errorMessageJob = 'Session expired. Please login again.';
        } else if (errorText.contains('401')) {
          _errorMessageJob = 'Authentication failed. Please login again.';
        } else if (errorText.toLowerCase().contains('timeout')) {
          _errorMessageJob = 'Connection timeout. Please try again.';
        } else if (errorText.contains('FormatException') ||
            errorText.contains('parse')) {
          _errorMessageJob = 'Unable to load data. Please try again.';
        } else {
          _errorMessageJob = 'Unable to load running jobs. Please try again.';
        }
      });

      // Log full error for debugging (this won't be shown to users)
      debugPrint('❌ [HomePage] Error fetching running job: $e');
    }
  }

  // IMPROVED: Load local bookings with deduplication
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
            }
          } catch (e) {
            debugPrint('⚠️ [HomePage] Error parsing booking $key: $e');
          }
        }
      }

      debugPrint('📱 [HomePage] Loaded ${localBookings.length} local bookings');
      return localBookings;
    } catch (e) {
      debugPrint('❌ [HomePage] Error loading local bookings: $e');
      return [];
    }
  }

  // IMPROVED: Normalize timestamp for consistent comparison
  String _normalizeTimestamp(String timestamp) {
    if (timestamp.isEmpty) return '';

    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}Z';
    } catch (e) {
      debugPrint('⚠️ [HomePage] Could not normalize timestamp: $timestamp');
      return timestamp;
    }
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoadingHistory = true;
      _errorMessageHistory = '';
    });

    try {
      // Fetch both API and local history
      final apiHistory = await HomeApi.getBookingHistory();
      final localBookings = await _loadLocalBookings();

      if (!mounted) return;

      debugPrint('========== HISTORY MERGE PROCESS ==========');
      debugPrint('📊 API history: ${apiHistory.length} items');
      debugPrint('📱 Local bookings: ${localBookings.length} items');

      // Use map to ensure uniqueness by deviceId + endTime
      Map<String, Map<String, dynamic>> uniqueBookings = {};

      // Process API history first (API takes priority)
      for (var apiItem in apiHistory) {
        final deviceId = (apiItem['deviceid'] ?? '').toString();
        final endTimeRaw = (apiItem['device_booked_user_end_time'] ?? '')
            .toString();

        if (deviceId.isEmpty || endTimeRaw.isEmpty) continue;

        final normalizedEndTime = _normalizeTimestamp(endTimeRaw);
        final uniqueKey = '${deviceId}_$normalizedEndTime';

        // Get amount, prefer non-zero values
        final currentAmount =
            double.tryParse(
              (apiItem['booked_user_amount'] ?? '0').toString(),
            ) ??
            0.0;

        if (uniqueBookings.containsKey(uniqueKey)) {
          final existingAmount =
              double.tryParse(
                (uniqueBookings[uniqueKey]!['booked_user_amount'] ?? '0')
                    .toString(),
              ) ??
              0.0;

          // Replace if current has non-zero amount and existing is zero
          if (currentAmount > 0 && existingAmount == 0) {
            uniqueBookings[uniqueKey] = apiItem;
            debugPrint('✅ Replaced with non-zero amount: $uniqueKey');
          }
          continue;
        }

        // If API amount is 0, try to find matching local booking
        if (currentAmount == 0) {
          for (var localItem in localBookings) {
            final localDeviceId = (localItem['deviceid'] ?? '').toString();
            final localEndTime = _normalizeTimestamp(
              (localItem['endtime'] ?? '').toString(),
            );

            if (localDeviceId == deviceId &&
                localEndTime == normalizedEndTime) {
              final localAmount =
                  double.tryParse((localItem['amount'] ?? '0').toString()) ??
                  0.0;

              if (localAmount > 0) {
                apiItem['booked_user_amount'] = localAmount;
                debugPrint(
                  '💰 Using local amount ₹$localAmount for $uniqueKey',
                );
              }
              break;
            }
          }
        }

        uniqueBookings[uniqueKey] = apiItem;
      }

      // Add local-only bookings (not in API)
      for (var localItem in localBookings) {
        final deviceId = (localItem['deviceid'] ?? '').toString();
        final endTimeRaw = (localItem['endtime'] ?? '').toString();

        if (deviceId.isEmpty || endTimeRaw.isEmpty) continue;

        final normalizedEndTime = _normalizeTimestamp(endTimeRaw);
        final uniqueKey = '${deviceId}_$normalizedEndTime';

        if (uniqueBookings.containsKey(uniqueKey)) continue;

        // Normalize local booking to match API format
        uniqueBookings[uniqueKey] = {
          'deviceid': localItem['deviceid'],
          'hubname': localItem['hubname'],
          'hubid': localItem['hubid'],
          'machineid': localItem['machineid'],
          'devicetype': localItem['devicetype'] ?? 'Device',
          'booked_user_amount': localItem['amount'],
          'device_booked_user_end_time': localItem['endtime'],
          'device_booked_user_start_time': localItem['starttime'],
          '_source': 'local_only',
        };

        debugPrint('📱 Added local-only: $uniqueKey');
      }

      // Convert to list and sort by end time (newest first)
      List<Map<String, dynamic>> mergedHistory = uniqueBookings.values.toList();

      mergedHistory.sort((a, b) {
        try {
          final aTimeStr = (a['device_booked_user_end_time'] ?? '').toString();
          final bTimeStr = (b['device_booked_user_end_time'] ?? '').toString();

          if (aTimeStr.isEmpty) return 1;
          if (bTimeStr.isEmpty) return -1;

          final aDate = DateTime.parse(aTimeStr);
          final bDate = DateTime.parse(bTimeStr);

          return bDate.compareTo(aDate);
        } catch (e) {
          debugPrint('⚠️ [HomePage] Error sorting: $e');
          return 0;
        }
      });

      debugPrint('✅ Total unique bookings: ${mergedHistory.length}');
      debugPrint('📋 Taking top 2 for display');
      debugPrint('========================================');

      setState(() {
        _historyList = mergedHistory.take(2).toList();
        _isLoadingHistory = false;
      });

      debugPrint(
        '✅ [HomePage] Successfully loaded ${_historyList.length} history items',
      );
    } catch (e) {
      if (!mounted) return;

      // Sanitize error message - remove URLs and technical details
      String errorText = e.toString();

      // Remove Exception prefix
      if (errorText.startsWith('Exception: ')) {
        errorText = errorText.substring(11);
      }

      // Remove URLs, URIs, and other sensitive info
      errorText = errorText.replaceAll(RegExp(r'https?://[^\s,)]+'), '');
      errorText = errorText.replaceAll(RegExp(r'uri=https?://[^\s,)]+'), '');
      errorText = errorText.replaceAll(RegExp(r'\(OS Error[^)]*\)'), '');

      setState(() {
        _historyList = [];
        _isLoadingHistory = false;

        // Provide user-friendly error messages
        if (errorText.contains('ClientException') ||
            errorText.contains('SocketException') ||
            errorText.contains('Failed host lookup') ||
            errorText.contains('No address associated') ||
            errorText.contains('errno = 7')) {
          _errorMessageHistory =
              'Unable to connect. Please check your internet connection.';
        } else if (errorText.contains('404')) {
          _errorMessageHistory = '';
        } else if (errorText.contains('not authenticated') ||
            errorText.contains('Mobile number not found') ||
            errorText.contains('Session token not found')) {
          _errorMessageHistory = 'Session expired. Please login again.';
        } else if (errorText.contains('Authentication failed') ||
            errorText.contains('401')) {
          _errorMessageHistory = 'Authentication failed. Please login again.';
        } else if (errorText.toLowerCase().contains('timeout')) {
          _errorMessageHistory = 'Connection timeout. Please try again.';
        } else {
          _errorMessageHistory = 'Unable to load history. Please try again.';
        }
      });

      // Log full error for debugging (won't be shown to users)
      debugPrint('❌ [HomePage] Error fetching history: $e');
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([_fetchRunningJob(), _fetchHistory()]);
  }

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat('dd/MM/yyyy hh:mm a').format(dateTime);
    } catch (e) {
      debugPrint('⚠️ [HomePage] Error formatting date: $e');
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'QK WASH',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard_outlined, color: Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rewards coming soon!')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildBannerSection(),
              const SizedBox(height: 24),
              _buildSectionHeader('Running Jobs'),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _isLoadingJob
                    ? _buildLoadingCard()
                    : _errorMessageJob.isNotEmpty
                    ? _buildErrorCard(_errorMessageJob, _fetchRunningJob)
                    : _hasRunningJob
                    ? _buildRunningJobCard()
                    : _buildEmptyRunningJobCard(),
              ),
              const SizedBox(height: 24),
              _buildHistorySection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/homepage.png',
          width: double.infinity,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[400]!, Colors.blue[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'QK WASH',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningJobCard() {
    if (_runningJob == null) return const SizedBox.shrink();

    final hubName = _runningJob!['hubname']?.toString() ?? 'Unknown Hub';
    final deviceId = _runningJob!['deviceid']?.toString() ?? 'N/A';
    final machineId = '#$deviceId';

    String endTime = '--:--';
    String endTimeString =
        _runningJob!['device_booked_user_end_time']?.toString() ?? '';
    if (endTimeString.isNotEmpty) {
      try {
        final DateTime endTimeDate = DateTime.parse(endTimeString).toLocal();
        endTime = DateFormat('HH:mm').format(endTimeDate);
      } catch (e) {
        endTime = '--:--';
        debugPrint('⚠️ [HomePage] Error parsing end time: $e');
      }
    }

    double progress = _calculateProgress(
      startTimeString: _runningJob!['device_booked_user_start_time'],
      endTimeString: _runningJob!['device_booked_user_end_time'],
    );

    String statusText = 'Running ( ${(progress * 100).toInt()}% completed )';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hub Name',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hubName.toLowerCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Machine Name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    machineId,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFE0E0E0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2196F3),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'End time',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    endTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
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

  Widget _buildEmptyRunningJobCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Icon(
                Icons.local_laundry_service_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No running jobs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan QR code to start a wash',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _isLoadingHistory
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildLoadingCard(),
              )
            : _errorMessageHistory.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildErrorCard(_errorMessageHistory, _fetchHistory),
              )
            : _historyList.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildEmptyHistoryCard(),
              )
            : Column(
                children: _historyList.map((booking) {
                  return _buildHistoryItem(booking);
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildEmptyHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No wash history',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed washes will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToHub(Map<String, dynamic> booking) async {
    final hubId = booking['hubid']?.toString();
    final hubName = booking['hubname']?.toString();

    if (hubId == null || hubId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hub information not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
        ),
      ),
    );

    try {
      // Fetch hub details
      final devices = await HomeApi.getHubDetails(hubId: hubId);

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Navigate to machine list
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MachineListPage(
            hubId: hubId,
            hubName: hubName ?? 'Unknown Hub',
            devices: devices,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load hub details: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildHistoryItem(Map<String, dynamic> booking) {
    final hubName = booking['hubname']?.toString() ?? 'Unknown Hub';
    final deviceType = booking['devicetype']?.toString() ?? 'Device';
    final deviceId = booking['deviceid']?.toString() ?? 'N/A';
    final endTime = booking['device_booked_user_end_time']?.toString() ?? '';

    final amountValue = booking['booked_user_amount'];
    final amount = amountValue?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: GestureDetector(
        onTap: () => _navigateToHub(booking),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hub Name',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hubName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Machine',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$deviceType #$deviceId',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    endTime.isNotEmpty ? _formatDateTime(endTime) : 'N/A',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  Row(
                    children: [
                      const Text(
                        'QK WASH',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹$amount',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
