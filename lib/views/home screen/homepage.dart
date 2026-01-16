import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/views/home%20screen/notification_page.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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

    // ✅ Refresh API data every 45 seconds
    _apiRefreshTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (mounted) {
        _fetchRunningJob();
      }
    });

    // ✅ Update progress bar every 10 seconds
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _hasRunningJob) {
        setState(() {}); // Rebuild to update progress
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _apiRefreshTimer?.cancel();
    super.dispose();
  }

  /// Calculate progress based on start time, end time, and current time
  double _calculateProgress({
    required String? startTimeString,
    required String? endTimeString,
  }) {
    // 1️⃣ Validate input
    if (startTimeString == null ||
        endTimeString == null ||
        startTimeString.isEmpty ||
        endTimeString.isEmpty) {
      return 0.0;
    }

    try {
      // 2️⃣ Parse times
      final DateTime startTime = DateTime.parse(startTimeString).toLocal();
      final DateTime endTime = DateTime.parse(endTimeString).toLocal();
      final DateTime now = DateTime.now();

      // 3️⃣ If job not started yet
      if (now.isBefore(startTime)) {
        return 0.0;
      }

      // 4️⃣ If job finished
      if (now.isAfter(endTime)) {
        return 1.0;
      }

      // 5️⃣ Calculate progress
      final int totalSeconds = endTime.difference(startTime).inSeconds;
      final int elapsedSeconds = now.difference(startTime).inSeconds;

      if (totalSeconds <= 0) {
        return 0.0;
      }

      double progress = elapsedSeconds / totalSeconds;

      // 6️⃣ Clamp value between 0 and 1
      return progress.clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('⚠️ Error calculating progress: $e');
      return 0.0;
    }
  }

  /// Fetch running job from API
  Future<void> _fetchRunningJob() async {
    if (!mounted) return;

    // Don't show loading spinner on background refresh
    final bool isInitialLoad = _runningJob == null && !_hasRunningJob;

    setState(() {
      if (isInitialLoad) {
        _isLoadingJob = true;
      }
      _errorMessageJob = '';
    });

    try {
      // 1️⃣ Call API
      final List<dynamic> jobs = await HomeApi.getRunningJobs();

      if (!mounted) return;

      // 2️⃣ If API returns empty list
      if (jobs.isEmpty) {
        setState(() {
          _hasRunningJob = false;
          _runningJob = null;
          _isLoadingJob = false;
        });
        debugPrint('ℹ️ No running jobs found');
        return;
      }

      // 3️⃣ Filter ONLY running jobs (end time is in future)
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
          return now.isBefore(endTime); // still running
        } catch (e) {
          debugPrint('⚠️ Invalid end time format: $endTimeString');
          return false;
        }
      }).toList();

      // 4️⃣ Update UI with first active job
      if (activeJobs.isNotEmpty) {
        setState(() {
          _runningJob = activeJobs[0] as Map<String, dynamic>;
          _hasRunningJob = true;
          _isLoadingJob = false;
        });

        debugPrint('✅ Running job loaded: ${activeJobs.length} active');
      } else {
        setState(() {
          _hasRunningJob = false;
          _runningJob = null;
          _isLoadingJob = false;
        });
        debugPrint('ℹ️ No active running jobs');
      }
    } catch (e) {
      if (!mounted) return;

      String errorText = e.toString().replaceFirst('Exception: ', '');

      setState(() {
        _hasRunningJob = false;
        _runningJob = null;
        _isLoadingJob = false;

        if (errorText.contains('not authenticated') ||
            errorText.contains('Session token') ||
            errorText.contains('Session expired')) {
          _errorMessageJob = 'Session expired. Please login again.';
        } else if (errorText.contains('401')) {
          _errorMessageJob = 'Authentication failed. Please login again.';
        } else if (errorText.contains('internet') ||
            errorText.contains('network')) {
          _errorMessageJob = 'No internet connection.';
        } else if (errorText.contains('timed out')) {
          _errorMessageJob = 'Request timed out. Try again.';
        } else {
          _errorMessageJob = 'Failed to load running jobs.';
        }
      });

      debugPrint('❌ Error fetching running job: $e');
    }
  }

  /// Fetch history from API
  Future<void> _fetchHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _errorMessageHistory = '';
    });

    try {
      final history = await HomeApi.getBookingHistory();

      if (!mounted) return;

      setState(() {
        // Get only the latest 3 items for homepage
        _historyList = history.take(3).toList();
        _isLoadingHistory = false;
      });

      debugPrint('✅ Loaded ${_historyList.length} history items for homepage');
    } catch (e) {
      if (!mounted) return;

      // Extract clean error message
      String errorText = e.toString();
      if (errorText.startsWith('Exception: ')) {
        errorText = errorText.substring(11);
      }

      setState(() {
        _historyList = [];
        _isLoadingHistory = false;

        // Handle 404 (no history) as empty, not error
        if (errorText.contains('404')) {
          _errorMessageHistory = '';
        } else if (errorText.contains('not authenticated') ||
            errorText.contains('Mobile number not found') ||
            errorText.contains('Session token not found')) {
          _errorMessageHistory = 'Session expired. Please login again.';
        } else if (errorText.contains('Authentication failed') ||
            errorText.contains('401')) {
          _errorMessageHistory = 'Authentication failed. Please login again.';
        } else if (errorText.contains('No internet connection') ||
            errorText.contains('network')) {
          _errorMessageHistory = 'Network error. Check your connection.';
        } else if (errorText.contains('timed out')) {
          _errorMessageHistory = 'Request timed out. Please try again.';
        } else {
          _errorMessageHistory = errorText.isNotEmpty
              ? errorText
              : 'Failed to load history';
        }
      });
      debugPrint('❌ Error fetching history: $e');
    }
  }

  /// Refresh all data
  Future<void> _onRefresh() async {
    await Future.wait([_fetchRunningJob(), _fetchHistory()]);
  }

  /// Format date and time
  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat('dd/MM/yyyy hh:mm a').format(dateTime);
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

              // Banner Image
              _buildBannerSection(),

              const SizedBox(height: 24),

              // Running Jobs Section
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

              // History Section
              _buildHistorySection(),

              const SizedBox(height: 100), // Extra space for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  /// Build banner section
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

  /// Build section header
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

  /// Build loading card placeholder
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

  /// Build error card
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

  /// Build running job card - matches exact design
  Widget _buildRunningJobCard() {
    if (_runningJob == null) return const SizedBox.shrink();

    // Parse job data
    final hubName = _runningJob!['hubname']?.toString() ?? 'Unknown Hub';
    final deviceType = _runningJob!['devicetype']?.toString() ?? 'Device';
    final deviceId = _runningJob!['deviceid']?.toString() ?? 'N/A';
    final machineId = '#$deviceId';

    // Extract time from datetime string
    String endTime = '--:--';
    String endTimeString =
        _runningJob!['device_booked_user_end_time']?.toString() ?? '';
    if (endTimeString.isNotEmpty) {
      try {
        final DateTime endTimeDate = DateTime.parse(endTimeString).toLocal();
        endTime = DateFormat('HH:mm').format(endTimeDate);
      } catch (e) {
        endTime = '--:--';
        debugPrint('⚠️ Error parsing end time: $e');
      }
    }

    // Calculate actual progress based on time
    double progress = _calculateProgress(
      startTimeString: _runningJob!['device_booked_user_start_time'],
      endTimeString: _runningJob!['device_booked_user_end_time'],
    );

    // Status text with percentage
    String statusText = 'Running (${(progress * 100).toInt()}% completed)';

    return GestureDetector(
      onTap: () {
        // Optional: Navigate to detailed view
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Hub Name and Machine Name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Hub Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hub Name',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hubName.toLowerCase(),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Right: Machine Name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Machine Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      machineId,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bottom row: Status and End time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: End time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'End time',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endTime,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE8E8E8),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4A90E2),
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty running job card
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
      child: Column(
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
    );
  }

  /// Build history section
  Widget _buildHistorySection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Tap "History" in bottom navigation to view all',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Show loading, error, empty state, or history items
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

  /// Build empty history card
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

  /// Build history item with real data
  Widget _buildHistoryItem(Map<String, dynamic> booking) {
    final hubName = booking['hubname']?.toString() ?? 'Unknown Hub';
    final deviceType = booking['devicetype']?.toString() ?? 'Device';
    final deviceId = booking['deviceid']?.toString() ?? 'N/A';
    final endTime = booking['device_booked_user_end_time']?.toString() ?? '';

    // Handle amount - could be int or string
    final amountValue = booking['booked_user_amount'];
    final amount = amountValue?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
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
                // Hub Name
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
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Machine
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

                // Status Badge
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
    );
  }
}
