import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/views/home%20screen/settings%20page/wash_history.dart';

import 'package:internship_duxoff_hub/views/qkwashome.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RunningJobsPage extends StatefulWidget {
  const RunningJobsPage({super.key});

  @override
  State<RunningJobsPage> createState() => _RunningJobsPageState();
}

class _RunningJobsPageState extends State<RunningJobsPage> {
  bool _hasRunningJobs = false;
  bool _isLoading = true;
  String _errorMessage = '';

  List<dynamic> _runningJobsList = [];
  List<dynamic> _recentlyCompletedJobs = [];
  Timer? _progressTimer;
  Timer? _apiRefreshTimer;
  Timer? _completionCheckTimer;

  // Track which jobs have been saved to prevent duplicates
  Set<String> _savedJobKeys = {};

  @override
  void initState() {
    super.initState();
    _fetchRunningJob();

    _apiRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchRunningJob();
      }
    });

    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _hasRunningJobs) {
        setState(() {});
      }
    });

    _completionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _checkAndMoveCompletedJobs();
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _apiRefreshTimer?.cancel();
    _completionCheckTimer?.cancel();
    super.dispose();
  }

  // Save completed job to local storage for history
  Future<void> _saveCompletedJobToHistory(Map<String, dynamic> job) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final deviceId = (job['deviceid'] ?? '').toString();
      final endTime = (job['device_booked_user_end_time'] ?? '').toString();

      if (deviceId.isEmpty || endTime.isEmpty) {
        debugPrint('⚠️ Cannot save job - missing deviceId or endTime');
        return;
      }

      // Create unique identifier for this job
      final jobIdentifier = '${deviceId}_$endTime';

      // Check if already saved
      if (_savedJobKeys.contains(jobIdentifier)) {
        debugPrint('⏭️ Job already saved to history: $jobIdentifier');
        return;
      }

      // ✅ VERIFICATION: Double-check the job is actually completed before saving
      final deviceStatus = (job['devicestatus'] ?? '').toString();
      bool isReallyCompleted = false;

      // Check 1: Status is 100
      if (deviceStatus == "100") {
        isReallyCompleted = true;
      } else {
        // Check 2: End time has passed
        try {
          final endDateTime = DateTime.parse(endTime).toLocal();
          if (DateTime.now().isAfter(endDateTime)) {
            isReallyCompleted = true;
          }
        } catch (e) {
          debugPrint('⚠️ Error verifying completion time: $e');
        }
      }

      if (!isReallyCompleted) {
        debugPrint(
            '⚠️ Job not actually completed yet, skipping save: $jobIdentifier');
        return;
      }

      // Create unique key for this booking
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final bookingKey = 'booking_${deviceId}_$timestamp';

      // Prepare booking data
      final bookingData = {
        'deviceid': job['deviceid'],
        'hubname': job['hubname'],
        'hubid': job['hubid'],
        'machineid': '#${job['deviceid']}',
        'amount': job['booked_user_amount'] ?? job['transactionamount'] ?? 0,
        'endtime': job['device_booked_user_end_time'],
        'starttime': job['device_booked_user_start_time'],
        'washmode': job['booked_user_selected_wash_mode'] ?? 'Quick',
        'washtime': job['booked_user_selected_duration'] ?? '15 Min',
        'detergent':
            job['booked_user_selected_detergent_preference'] ?? 'O3 Treat',
        'paymentid': job['paymentid'] ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'completed': true, // ✅ Mark as completed
      };

      await prefs.setString(bookingKey, jsonEncode(bookingData));

      // Mark as saved
      _savedJobKeys.add(jobIdentifier);

      debugPrint('✅ Saved completed job to history: $bookingKey');
      debugPrint('   Device ID: $deviceId');
      debugPrint('   Amount: ${bookingData['amount']}');
      debugPrint('   End Time: $endTime');
      debugPrint('   Status at save: $deviceStatus');
    } catch (e) {
      debugPrint('❌ Error saving completed job to history: $e');
    }
  }

  void _checkAndMoveCompletedJobs() {
    if (_runningJobsList.isEmpty) return;

    final DateTime now = DateTime.now();
    final List<dynamic> stillRunning = [];
    final List<dynamic> justCompleted = [];

    for (var job in _runningJobsList) {
      bool isCompleted = false;

      // ✅ PRIMARY CHECK: Device status = "100" means completed
      final String? deviceStatus = job['devicestatus']?.toString();
      if (deviceStatus == "100") {
        isCompleted = true;
        debugPrint(
          '✅ Job completed (devicestatus=100): Device ${job['deviceid']}',
        );
      } else {
        // ✅ SECONDARY CHECK: End time has passed
        final String? endTimeString =
            job['device_booked_user_end_time']?.toString();

        if (endTimeString != null && endTimeString.isNotEmpty) {
          try {
            DateTime endTime = DateTime.parse(endTimeString);
            if (endTime.isUtc || endTimeString.endsWith('Z')) {
              endTime = endTime.toLocal();
            }

            // Only mark as completed if current time is AFTER end time
            if (now.isAfter(endTime)) {
              isCompleted = true;
              debugPrint(
                '✅ Job completed (time passed): Device ${job['deviceid']} at ${DateFormat('HH:mm').format(endTime)}',
              );
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing end time: $e');
          }
        }
      }

      // Sort into completed or still running
      if (isCompleted) {
        justCompleted.add(job);
      } else {
        stillRunning.add(job);
      }
    }

    // Process completed jobs
    if (justCompleted.isNotEmpty && mounted) {
      setState(() {
        _runningJobsList = stillRunning;

        for (var job in justCompleted) {
          // Check if already in recently completed
          final alreadyInCompleted = _recentlyCompletedJobs.any(
            (existing) =>
                existing['deviceid'] == job['deviceid'] &&
                existing['device_booked_user_end_time'] ==
                    job['device_booked_user_end_time'],
          );

          if (!alreadyInCompleted) {
            _recentlyCompletedJobs.insert(0, job);

            // ✅ CRITICAL FIX: ONLY save to history AFTER job is truly completed
            // This prevents incomplete jobs from appearing in history
            debugPrint(
                '💾 Saving completed job to history: Device ${job['deviceid']}');
            _saveCompletedJobToHistory(job);
          }
        }

        _hasRunningJobs = stillRunning.isNotEmpty;
      });

      debugPrint('🎉 Moved ${justCompleted.length} jobs to completed');

      // Auto-remove from "Recently Completed" after 5 minutes
      Future.delayed(const Duration(minutes: 5), () {
        if (mounted) {
          setState(() {
            for (var job in justCompleted) {
              _recentlyCompletedJobs.removeWhere(
                (item) =>
                    item['deviceid'] == job['deviceid'] &&
                    item['device_booked_user_end_time'] ==
                        job['device_booked_user_end_time'],
              );
            }
          });
          debugPrint(
            '🗑️ Auto-removed completed jobs from recently completed section',
          );
        }
      });
    }
  }

  Future<void> _fetchRunningJob() async {
    if (!mounted) return;

    final bool isInitialLoad = _runningJobsList.isEmpty && !_hasRunningJobs;

    setState(() {
      if (isInitialLoad) {
        _isLoading = true;
      }
      _errorMessage = '';
    });

    try {
      final List<dynamic> jobs = await HomeApi.getRunningJobs();

      if (!mounted) return;

      if (jobs.isEmpty) {
        setState(() {
          _hasRunningJobs = false;
          _runningJobsList = [];
          _isLoading = false;
        });
        debugPrint('ℹ️ No running jobs found');
        return;
      }

      final DateTime now = DateTime.now();
      final List<dynamic> activeJobs = [];

      for (var job in jobs) {
        if (job == null || job is! Map) continue;

        final deviceId = job['deviceid']?.toString() ?? 'N/A';
        final deviceStatus = job['devicestatus']?.toString() ?? '';
        final endTimeString = job['device_booked_user_end_time']?.toString();

        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('🔍 RAW JOB DATA for Device $deviceId:');
        debugPrint(
          '   devicestatus from API: "${deviceStatus.isEmpty ? 'MISSING/NULL' : deviceStatus}"',
        );
        debugPrint('   End time: $endTimeString');

        // ✅ CHECK 1: Skip if devicestatus is "100" (completed)
        if (deviceStatus == "100") {
          debugPrint('   ⏭️ SKIPPED: Job completed (devicestatus=100)');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          continue;
        }

        // ✅ CHECK 2: Skip if end time has already passed
        bool isStillRunning = false;

        if (endTimeString != null && endTimeString.isNotEmpty) {
          try {
            DateTime endTime = DateTime.parse(endTimeString);
            if (endTime.isUtc || endTimeString.endsWith('Z')) {
              endTime = endTime.toLocal();
            }

            if (now.isBefore(endTime)) {
              isStillRunning = true;
              debugPrint(
                '   ✅ ACTIVE: End time is in future (${DateFormat('HH:mm').format(endTime)})',
              );
            } else {
              debugPrint(
                '   ⏭️ SKIPPED: End time passed (${DateFormat('HH:mm').format(endTime)})',
              );
            }
          } catch (e) {
            debugPrint('   ⚠️ Error parsing end time: $e');
            // If we can't parse end time but devicestatus isn't 100, assume it's running
            if (deviceStatus != "100") {
              isStillRunning = true;
              debugPrint(
                '   ⚠️ Assuming active (end time parse failed but not completed)',
              );
            }
          }
        } else {
          // No end time but devicestatus isn't 100 - assume newly booked and running
          if (deviceStatus != "100") {
            isStillRunning = true;
            debugPrint(
              '   ⚠️ No end time but devicestatus != 100, assuming active',
            );
          }
        }

        // ✅ ADD TO ACTIVE JOBS ONLY IF STILL RUNNING
        if (isStillRunning) {
          activeJobs.add(job);
          debugPrint('   ✅✅ ADDED TO ACTIVE JOBS LIST ✅✅');
        }

        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      setState(() {
        _runningJobsList = activeJobs;
        _hasRunningJobs = activeJobs.isNotEmpty;
        _isLoading = false;
      });

      debugPrint('');
      debugPrint('📊 ========== SUMMARY ==========');
      debugPrint('📊 Total jobs from API: ${jobs.length}');
      debugPrint('📊 Active jobs after filtering: ${activeJobs.length}');
      debugPrint('📊 ================================');
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
        _hasRunningJobs = false;
        _runningJobsList = [];
        _isLoading = false;

        // Provide user-friendly error messages
        if (errorText.contains('ClientException') ||
            errorText.contains('SocketException') ||
            errorText.contains('Failed host lookup') ||
            errorText.contains('No address associated') ||
            errorText.contains('errno = 7')) {
          _errorMessage =
              'Unable to connect. Please check your internet connection.';
        } else if (errorText.contains('not authenticated') ||
            errorText.contains('Session token') ||
            errorText.contains('Session expired')) {
          _errorMessage = 'Session expired. Please login again.';
        } else if (errorText.contains('401')) {
          _errorMessage = 'Authentication failed. Please login again.';
        } else if (errorText.toLowerCase().contains('timeout')) {
          _errorMessage = 'Connection timeout. Please try again.';
        } else {
          _errorMessage = 'Unable to load running jobs. Please try again.';
        }
      });

      // Log full error for debugging (won't be shown to users)
      debugPrint('❌ Error fetching running job: $e');
    }
  }

  Future<void> _onRefresh() async {
    await _fetchRunningJob();
  }

  // Get progress from device status or calculate from time
  double _getProgress(Map<String, dynamic> job) {
    // First priority: use devicestatus from API
    final String? deviceStatus = job['devicestatus']?.toString();

    if (deviceStatus != null &&
        deviceStatus.isNotEmpty &&
        deviceStatus != 'null') {
      try {
        final int status = int.parse(deviceStatus);
        final double progress = status / 100.0;
        return progress.clamp(0.0, 1.0);
      } catch (e) {
        debugPrint('⚠️ Invalid devicestatus format: $deviceStatus');
      }
    }

    // ✅ Fallback: If devicestatus is missing/empty (newly booked job)
    // Show minimal progress to indicate job is starting
    debugPrint(
      '⚠️ devicestatus missing for device ${job['deviceid']}, using time calculation',
    );

    return _calculateProgressFromTime(
      startTimeString: job['device_booked_user_start_time']?.toString(),
      endTimeString: job['device_booked_user_end_time']?.toString(),
    );
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

        if (totalSeconds <= 0) return 0.0;

        double progress = elapsedSeconds / totalSeconds;
        return progress.clamp(0.0, 1.0);
      } else {
        final Duration remainingTime = endTime.difference(now);
        final int remainingMinutes = remainingTime.inMinutes;

        const int assumedTotalMinutes = 15;
        final int elapsedMinutes = assumedTotalMinutes - remainingMinutes;

        if (elapsedMinutes <= 0) return 0.05;

        double progress = elapsedMinutes / assumedTotalMinutes;
        return progress.clamp(0.05, 1.0);
      }
    } catch (e) {
      return 0.0;
    }
  }

  // Navigate to History Page
  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WashHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalJobs = _runningJobsList.length + _recentlyCompletedJobs.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF000000)),
          onPressed: () {
            _progressTimer?.cancel();
            _apiRefreshTimer?.cancel();
            _completionCheckTimer?.cancel();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const QKWashHome()),
            );
          },
        ),
        title: const Text(
          'Running Jobs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF000000),
          ),
        ),
        bottom: totalJobs > 0 && !_isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 56, bottom: 8),
                  child: Text(
                    '${_runningJobsList.length} active • ${_recentlyCompletedJobs.length} recently completed',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF757575),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              _buildLoadingCard()
            else if (_errorMessage.isNotEmpty)
              _buildErrorCard()
            else if (_runningJobsList.isEmpty && _recentlyCompletedJobs.isEmpty)
              _buildEmptyCard()
            else ...[
              // Active Jobs Section
              if (_runningJobsList.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Active Jobs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF424242),
                    ),
                  ),
                ),
                ..._runningJobsList.map(
                  (job) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRunningJobCard(job, isActive: true),
                  ),
                ),
              ],

              // Recently Completed Section
              if (_recentlyCompletedJobs.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(
                    top: _runningJobsList.isNotEmpty ? 16 : 0,
                    bottom: 12,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Recently Completed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Last 5 min',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF388E3C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ..._recentlyCompletedJobs.map(
                  (job) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRunningJobCard(job, isActive: false),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
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
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF44336).withOpacity(0.2)),
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
            _errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF616161),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchRunningJob,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: const Color(0xFFFFFFFF),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningJobCard(
    Map<String, dynamic> job, {
    required bool isActive,
  }) {
    final hubName = job['hubname']?.toString() ?? 'Unknown Hub';
    final deviceId = job['deviceid']?.toString() ?? 'N/A';
    final machineId = '#$deviceId';
    final deviceStatus = job['devicestatus']?.toString() ?? '';

    final startTimeString = job['device_booked_user_start_time']?.toString();
    final endTimeString = job['device_booked_user_end_time']?.toString();

    String endTime = '--:--';
    if (endTimeString != null && endTimeString.isNotEmpty) {
      try {
        final DateTime endTimeDate = DateTime.parse(endTimeString).toLocal();
        endTime = DateFormat('hh:mm a').format(endTimeDate);
      } catch (e) {
        endTime = '--:--';
      }
    }

    double progress = _getProgress(job);

    return GestureDetector(
      onTap: !isActive ? _navigateToHistory : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? null
              : Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row - Hub and Machine Info
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
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF757575),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hubName.toLowerCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xDE000000),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Machine Name',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      machineId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xDE000000),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bottom Row - Status and End Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF757575),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isActive) ...[
                        Text(
                          deviceStatus.isNotEmpty
                              ? 'Running ($deviceStatus% completed)'
                              : 'Running (starting...)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFFE8E8E8),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF4A90E2),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ] else ...[
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF43A047),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'End time',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endTime,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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

  Widget _buildEmptyCard() {
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
          Icon(
            Icons.local_laundry_service_outlined,
            size: 64,
            color: Color(0xFFE0E0E0),
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
    );
  }
}
