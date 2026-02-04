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

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
 
  @override
  bool get wantKeepAlive => true;

  // State variables
  bool _hasRunningJob = false;
  bool _isLoadingJob = true;
  bool _isLoadingHistory = true;

  Map<String, dynamic>? _runningJob;
  List<Map<String, dynamic>> _historyList = []; 

  String _errorMessageJob = '';
  String _errorMessageHistory = '';

  // Timers
  Timer? _progressTimer;
  Timer? _apiRefreshTimer;

  DateTime? _lastJobFetch;
  DateTime? _lastHistoryFetch;
  static const Duration _cacheValidDuration = Duration(seconds: 30);

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _startTimers();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  // INITIALIZATION
  // ============================================================================

  void _initializeData() {
    _fetchRunningJob();
    _fetchHistory();
  }

  void _startTimers() {
    _apiRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchRunningJob(forceRefresh: false);
      }
    });

    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _hasRunningJob) {
        setState(() {});
      }
    });
  }

  void _stopTimers() {
    _progressTimer?.cancel();
    _apiRefreshTimer?.cancel();
  }

  // PROGRESS CALCULATION
  // ============================================================================

  /// Get progress from device status or calculate from time
  double _getProgress(Map<String, dynamic> job) {
    try {
      final String? deviceStatus = job['devicestatus']?.toString();
      if (deviceStatus != null && deviceStatus.isNotEmpty) {
        final int status = int.tryParse(deviceStatus) ?? 0;
        if (status > 0) {
          return (status / 100.0).clamp(0.0, 1.0);
        }
      }

      return _calculateProgressFromTime(
        startTimeString: job['device_booked_user_start_time']?.toString(),
        endTimeString: job['device_booked_user_end_time']?.toString(),
      );
    } catch (e) {
      debugPrint('❌ [HomePage] Error getting progress: $e');
      return 0.0;
    }
  }

  double _calculateProgressFromTime({
    required String? startTimeString,
    required String? endTimeString,
  }) {
    if (endTimeString == null || endTimeString.isEmpty) {
      return 0.0;
    }

    try {
      final DateTime now = DateTime.now();
      DateTime endTime = DateTime.parse(endTimeString);

      if (endTime.isUtc || endTimeString.endsWith('Z')) {
        endTime = endTime.toLocal();
      }

      if (now.isAfter(endTime)) {
        return 1.0;
      }

      if (startTimeString != null && startTimeString.isNotEmpty) {
        DateTime startTime = DateTime.parse(startTimeString);
        if (startTime.isUtc || startTimeString.endsWith('Z')) {
          startTime = startTime.toLocal();
        }

        if (now.isBefore(startTime)) {
          return 0.0;
        }

        final int totalSeconds = endTime.difference(startTime).inSeconds;
        final int elapsedSeconds = now.difference(startTime).inSeconds;

        if (totalSeconds <= 0) {
          return 0.0;
        }

        final double progress = elapsedSeconds / totalSeconds;
        return progress.clamp(0.0, 1.0);
      } else {
        final Duration remainingTime = endTime.difference(now);
        final int remainingMinutes = remainingTime.inMinutes;
        const int assumedTotalMinutes = 15;
        final int elapsedMinutes = assumedTotalMinutes - remainingMinutes;

        if (elapsedMinutes <= 0) {
          return 0.05;
        }

        final double progress = elapsedMinutes / assumedTotalMinutes;
        return progress.clamp(0.05, 1.0);
      }
    } catch (e) {
      debugPrint('[HomePage] Error calculating progress from time: $e');
      return 0.0;
    }
  }

  // ============================================================================
  // DATA FETCHING
  // =======================================  =====================================

  /// Fetch running jobs with optional caching
  Future<void> _fetchRunningJob({bool forceRefresh = true}) async {
    if (!mounted) return;

    // IMPROVEMENT 6: Use cache if available and valid (unless force refresh)
    if (!forceRefresh &&
        _lastJobFetch != null &&
        DateTime.now().difference(_lastJobFetch!) < _cacheValidDuration) {
      debugPrint('[HomePage] Using cached running job data');
      return;
    }

    final bool isInitialLoad = _runningJob == null && !_hasRunningJob;

    if (mounted) {
      setState(() {
        if (isInitialLoad) {
          _isLoadingJob = true;
        }
        _errorMessageJob = '';
      });
    }

    try {
      final List<dynamic> jobs = await HomeApi.getRunningJobs();

      if (!mounted) return;

      // Update cache timestamp
      _lastJobFetch = DateTime.now();

      if (jobs.isEmpty) {
        setState(() {
          _hasRunningJob = false;
          _runningJob = null;
          _isLoadingJob = false;
        });
        return;
      }

      // Filter active jobs
      final List<dynamic> activeJobs = _filterActiveJobs(jobs);

      if (activeJobs.isNotEmpty) {
        setState(() {
          _runningJob = activeJobs[0] as Map<String, dynamic>;
          _hasRunningJob = true;
          _isLoadingJob = false;
        });
      } else {
        setState(() {
          _hasRunningJob = false;
          _runningJob = null;
          _isLoadingJob = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _hasRunningJob = false;
        _runningJob = null;
        _isLoadingJob = false;
        _errorMessageJob = _sanitizeErrorMessage(e.toString());
      });

      debugPrint(' [HomePage] Error fetching running job: $e');
    }
  }

  /// Filter jobs to get only active ones
  List<dynamic> _filterActiveJobs(List<dynamic> jobs) {
    final DateTime now = DateTime.now();

    return jobs.where((job) {
      if (job == null || job is! Map) return false;

      final String? deviceStatus = job['devicestatus']?.toString();
      if (deviceStatus == "100") {
        return false;
      }

      final String? endTimeString =
          job['device_booked_user_end_time']?.toString();

      if (endTimeString == null || endTimeString.isEmpty) {
        return false;
      }

      try {
        final DateTime endTime = DateTime.parse(endTimeString).toLocal();
        return now.isBefore(endTime);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  /// Fetch history with deduplication and amount preservation
  Future<void> _fetchHistory({bool forceRefresh = true}) async {
    if (!mounted) return;

    if (!forceRefresh &&
        _lastHistoryFetch != null &&
        DateTime.now().difference(_lastHistoryFetch!) < _cacheValidDuration) {
      debugPrint('[HomePage] Using cached history data');
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
        _errorMessageHistory = '';
      });
    }

    try {
      // IMPROVEMENT 7: Fetch both API and local history in parallel
      final results = await Future.wait([
        HomeApi.getBookingHistory(),
        _loadLocalBookings(),
      ]);

      if (!mounted) return;

      final apiHistory = results[0] as List<dynamic>;
      final localBookings = results[1] as List<Map<String, dynamic>>;

      // Update cache timestamp
      _lastHistoryFetch = DateTime.now();

      // Merge and deduplicate
      final mergedHistory = _mergeHistoryData(apiHistory, localBookings);

      // Sort by end time (newest first) and take top 2
      mergedHistory.sort(_compareByEndTime);
      final displayHistory = mergedHistory.take(2).toList();

      setState(() {
        _historyList = displayHistory;
        _isLoadingHistory = false;
      });

      debugPrint(
          '[HomePage] Successfully loaded ${_historyList.length} history items');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _historyList = [];
        _isLoadingHistory = false;
        _errorMessageHistory = _sanitizeErrorMessage(e.toString());
      });

      debugPrint(' [HomePage] Error fetching history: $e');
    }
  }

  /// Load local bookings from SharedPreferences
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
            debugPrint(' [HomePage] Error parsing booking $key: $e');
          }
        }
      }

      return localBookings;
    } catch (e) {
      debugPrint(' [HomePage] Error loading local bookings: $e');
      return [];
    }
  }

  /// Merge API history with local bookings, preserving amounts
  List<Map<String, dynamic>> _mergeHistoryData(
    List<dynamic> apiHistory,
    List<Map<String, dynamic>> localBookings,
  ) {
    // Build local bookings map for O(1) lookup
    final Map<String, Map<String, dynamic>> localBookingsMap = {};
    for (var localItem in localBookings) {
      final uniqueKey = _getUniqueBookingKey(
        deviceId: localItem['deviceid']?.toString(),
        endTime: localItem['endtime']?.toString(),
      );
      if (uniqueKey != null) {
        localBookingsMap[uniqueKey] = localItem;
      }
    }

    // Use map to ensure uniqueness
    Map<String, Map<String, dynamic>> uniqueBookings = {};

    for (var apiItem in apiHistory) {
      if (apiItem == null || apiItem is! Map) continue;

      final apiMap = apiItem is Map<String, dynamic>
          ? apiItem
          : Map<String, dynamic>.from(apiItem);

      final uniqueKey = _getUniqueBookingKey(
        deviceId: apiMap['deviceid']?.toString(),
        endTime: apiMap['device_booked_user_end_time']?.toString(),
      );

      if (uniqueKey == null) continue;

      double currentAmount = double.tryParse(
            (apiMap['transactionamount'] ?? apiMap['booked_user_amount'] ?? '0')
                .toString(),
          ) ??
          0.0;

      if (currentAmount == 0 && localBookingsMap.containsKey(uniqueKey)) {
        final localAmount = double.tryParse(
              (localBookingsMap[uniqueKey]!['amount'] ?? '0').toString(),
            ) ??
            0.0;

        if (localAmount > 0) {
          apiMap['booked_user_amount'] = localAmount;
          apiMap['transactionamount'] = localAmount;
          currentAmount = localAmount;
        }
      }

      //  IMPROVEMENT 9: Copy hubid/hubname from local if missing in API
      if ((apiMap['hubid'] == null || apiMap['hubid'].toString().isEmpty) &&
          localBookingsMap.containsKey(uniqueKey)) {
        final localHub = localBookingsMap[uniqueKey];
        if (localHub!['hubid'] != null) {
          apiMap['hubid'] = localHub['hubid'];
        }
        if (localHub['hubname'] != null) {
          apiMap['hubname'] = localHub['hubname'];
        }
      }

      // Add or replace if better data
      if (uniqueBookings.containsKey(uniqueKey)) {
        final existingAmount = double.tryParse(
              (uniqueBookings[uniqueKey]!['booked_user_amount'] ?? '0')
                  .toString(),
            ) ??
            0.0;

        if (currentAmount > 0 && existingAmount == 0) {
          uniqueBookings[uniqueKey] = apiMap;
        }
      } else {
        uniqueBookings[uniqueKey] = apiMap;
      }
    }

    // Add local-only bookings
    for (var entry in localBookingsMap.entries) {
      if (uniqueBookings.containsKey(entry.key)) continue;

      final localItem = entry.value;
      uniqueBookings[entry.key] = {
        'deviceid': localItem['deviceid'],
        'hubname': localItem['hubname'],
        'hubid': localItem['hubid'],
        'machineid': localItem['machineid'],
        'devicetype': localItem['devicetype'] ?? 'Device',
        'booked_user_amount': localItem['amount'],
        'transactionamount': localItem['amount'],
        'device_booked_user_end_time': localItem['endtime'],
        'device_booked_user_start_time': localItem['starttime'],
        '_source': 'local_only',
      };
    }

    return uniqueBookings.values.toList();
  }

  /// Generate unique key for booking (deviceId + normalized endTime)
  String? _getUniqueBookingKey({
    required String? deviceId,
    required String? endTime,
  }) {
    if (deviceId == null ||
        deviceId.isEmpty ||
        endTime == null ||
        endTime.isEmpty) {
      return null;
    }

    final normalizedEndTime = _normalizeTimestamp(endTime);
    return '${deviceId}_$normalizedEndTime';
  }

  /// Normalize timestamp for consistent comparison
  String _normalizeTimestamp(String timestamp) {
    if (timestamp.isEmpty) return '';

    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}Z';
    } catch (e) {
      return timestamp;
    }
  }

  int _compareByEndTime(Map<String, dynamic> a, Map<String, dynamic> b) {
    try {
      final aTimeStr = (a['device_booked_user_end_time'] ?? '').toString();
      final bTimeStr = (b['device_booked_user_end_time'] ?? '').toString();

      if (aTimeStr.isEmpty) return 1;
      if (bTimeStr.isEmpty) return -1;

      final aDate = DateTime.parse(aTimeStr);
      final bDate = DateTime.parse(bTimeStr);

      return bDate.compareTo(aDate);
    } catch (e) {
      return 0;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ==========================================================================

  /// Sanitize error message for user display
  String _sanitizeErrorMessage(String error) {
    String errorText = error;

    if (errorText.startsWith('Exception: ')) {
      errorText = errorText.substring(11);
    }

    errorText = errorText.replaceAll(RegExp(r'https?://[^\s,)]+'), '');
    errorText = errorText.replaceAll(RegExp(r'uri=https?://[^\s,)]+'), '');
    errorText = errorText.replaceAll(RegExp(r'\(OS Error[^)]*\)'), '');

    if (errorText.contains('SocketException') ||
        errorText.contains('Failed host lookup') ||
        errorText.contains('No address associated') ||
        errorText.contains('errno = 7')) {
      return 'Unable to connect. Please check your internet connection.';
    } else if (errorText.contains('not authenticated') ||
        errorText.contains('Session token') ||
        errorText.contains('Session expired') ||
        errorText.contains('Mobile number not found')) {
      return 'Session expired. Please login again.';
    } else if (errorText.contains('401')) {
      return 'Authentication failed. Please login again.';
    } else if (errorText.toLowerCase().contains('timeout')) {
      return 'Connection timeout. Please try again.';
    } else if (errorText.contains('404')) {
      return '';
    } else {
      return 'Unable to load data. Please try again.';
    }
  }

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat('dd/MM/yyyy hh:mm a').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _fetchRunningJob(forceRefresh: true),
      _fetchHistory(forceRefresh: true),
    ]);
  }

  // =============================
  // NAVIGATION
  // ====================================

  /// Navigate to hub details page
  Future<void> _navigateToHub(Map<String, dynamic> booking) async {
    // IMPROVEMENT 10: Prevent multiple simultaneous navigations
    if (_isNavigating) return;

    final hubId = booking['hubid']?.toString();
    final hubName = booking['hubname']?.toString();

    // IMPROVEMENT 11: Better validation
    if (hubId == null || hubId.isEmpty || hubId == 'null') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hub information not available'),
            backgroundColor: Color(0xFFF44336),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _isNavigating = true;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
          ),
        ),
      );
    }

    try {
      final devices = await HomeApi.getHubDetails(hubId: hubId);

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
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load hub details'),
          backgroundColor: const Color(0xFFF44336),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _isNavigating = false;
              _navigateToHub(booking);
            },
          ),
        ),
      );
    } finally {
      _isNavigating = false;
    }
  }

  // ============================================================================
  // UI BUILD METHODS
  // ================================================================

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF2196F3),
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
                child: _buildRunningJobsSection(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFFFFFFF),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text(
        'QK WASH',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2196F3),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF000000),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationPage()),
            );
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.card_giftcard_outlined,
            color: Color(0xFF000000),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rewards coming soon!')),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
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
                    color: Color(0xFFFFFFFF),
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
          color: Color(0xFF000000),
        ),
      ),
    );
  }

  Widget _buildRunningJobsSection() {
    if (_isLoadingJob) {
      return _buildLoadingCard();
    }

    if (_errorMessageJob.isNotEmpty) {
      return _buildErrorCard(
          _errorMessageJob, () => _fetchRunningJob(forceRefresh: true));
    }

    if (_hasRunningJob) {
      return _buildRunningJobCard();
    }

    return _buildEmptyRunningJobCard();
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9E9E9E).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9E9E9E).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE57373)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF757575)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: const Color(0xFFFFFFFF),
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
    final deviceStatus = _runningJob!['devicestatus']?.toString() ?? '0';

    String endTime = '--:--';
    String endTimeString =
        _runningJob!['device_booked_user_end_time']?.toString() ?? '';
    if (endTimeString.isNotEmpty) {
      try {
        final DateTime endTimeDate = DateTime.parse(endTimeString).toLocal();
        endTime = DateFormat('hh:mm a').format(endTimeDate);
      } catch (e) {
        endTime = '--:--';
      }
    }

    double progress = _getProgress(_runningJob!);
    String statusText = 'Running ( $deviceStatus% completed )';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.06),
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
                        color: Color(0xDE000000),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hubName.toLowerCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF757575),
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
                      color: Color(0xDE000000),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    machineId,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF757575),
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
                        color: Color(0xDE000000),
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
                      color: Color(0xDE000000),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    endTime,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF757575),
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
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9E9E9E).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Icon(
                Icons.local_laundry_service_outlined,
                size: 48,
                color: Color(0xFFBDBDBD),
              ),
              SizedBox(height: 16),
              Text(
                'No running jobs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF616161),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Scan QR code to start a wash',
                style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000000),
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
                    child: _buildErrorCard(
                      _errorMessageHistory,
                      () => _fetchHistory(forceRefresh: true),
                    ),
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
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9E9E9E).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.history, size: 48, color: Color(0xFFBDBDBD)),
          SizedBox(height: 16),
          Text(
            'No wash history',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF616161),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your completed washes will appear here',
            style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> booking) {
    final hubName = booking['hubname']?.toString() ?? 'Unknown Hub';
    final deviceType = booking['devicetype']?.toString() ?? 'Device';
    final deviceId = booking['deviceid']?.toString() ?? 'N/A';
    final endTime = booking['device_booked_user_end_time']?.toString() ?? '';

    //  Get amount with fallback
    final amountValue =
        booking['transactionamount'] ?? booking['booked_user_amount'];
    final amount = amountValue?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: GestureDetector(
        onTap: () => _navigateToHub(booking),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9E9E9E).withOpacity(0.1),
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
                            color: Color(0xDE000000),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hubName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF757575),
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
                          color: Color(0xDE000000),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$deviceType #$deviceId',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                        ),
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
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFFFFFF),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'QK WASH',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹$amount',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF424242),
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
