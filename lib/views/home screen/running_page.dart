import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/services/notification_service.dart';
import 'package:internship_duxoff_hub/views/qkwashome.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RunningJobsPage extends StatefulWidget {
  final String? hubId;
  final String? hubName;

  const RunningJobsPage({
    super.key,
    this.hubId,
    this.hubName,
  });

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
  Timer? _notificationCheckTimer;

  // Track which jobs have been saved to prevent duplicates
  Set<String> _savedJobKeys = {};

  //  NEW: Track which jobs have had completion notification sent
  Set<String> _completionNotificationSent = {};

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
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

    _notificationCheckTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _runningJobsList.isNotEmpty) {
        _checkProgressNotifications();
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _apiRefreshTimer?.cancel();
    _completionCheckTimer?.cancel();
    _notificationCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
      debugPrint(' Notifications initialized in RunningJobsPage');
    } catch (e) {
      debugPrint(' Error initializing notifications: $e');
    }
  }

  Future<void> _checkProgressNotifications() async {
    try {
      for (var job in _runningJobsList) {
        await _notificationService.checkProgressNotificationsOnly(job);
      }
    } catch (e) {
      debugPrint('❌ Error checking progress notifications: $e');
    }
  }

  //  FIXED: Send completion notification FIRST, then save to history
  Future<void> _handleJobCompletion(Map<String, dynamic> job) async {
    final deviceId = (job['deviceid'] ?? '').toString();
    final endTime = (job['device_booked_user_end_time'] ?? '').toString();

    if (deviceId.isEmpty || endTime.isEmpty) {
      return;
    }

    final jobIdentifier = '${deviceId}_$endTime';

    //  STEP 1: Send completion notification (if not already sent)
    if (!_completionNotificationSent.contains(jobIdentifier)) {
      try {
        debugPrint('🔔 Sending completion notification for device $deviceId');
        await _notificationService.showCompletionNotification(job);
        _completionNotificationSent.add(jobIdentifier);
        debugPrint('✅ Completion notification sent for device $deviceId');
      } catch (e) {
        debugPrint('❌ Error sending completion notification: $e');
      }
    }

    // ✅ STEP 2: Save to history (if not already saved)
    await _saveCompletedJobToHistory(job);
  }

  Future<void> _saveCompletedJobToHistory(Map<String, dynamic> job) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final deviceId = (job['deviceid'] ?? '').toString();
      final endTime = (job['device_booked_user_end_time'] ?? '').toString();

      if (deviceId.isEmpty || endTime.isEmpty) {
        debugPrint('⚠️ Cannot save job - missing deviceId or endTime');
        return;
      }

      final jobIdentifier = '${deviceId}_$endTime';

      // Check if already saved
      if (_savedJobKeys.contains(jobIdentifier)) {
        debugPrint('⏭️ Job already saved to history: $jobIdentifier');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final bookingKey = 'booking_${deviceId}_$timestamp';

      // Get hubid and hubname with multiple fallbacks
      String finalHubId = '';
      String finalHubName = 'Unknown Hub';

      if (job['hubid']?.toString().trim().isNotEmpty ?? false) {
        finalHubId = job['hubid'].toString();
        debugPrint('✅ Using hubId from job data: $finalHubId');
      }

      if (job['hubname']?.toString().trim().isNotEmpty ?? false) {
        finalHubName = job['hubname'].toString();
        debugPrint('✅ Using hubName from job data: $finalHubName');
      }

      if (finalHubId.isEmpty && (widget.hubId?.isNotEmpty ?? false)) {
        finalHubId = widget.hubId!;
        debugPrint('✅ Using hubId from widget: $finalHubId');
      }

      if (finalHubName == 'Unknown Hub' &&
          (widget.hubName?.isNotEmpty ?? false)) {
        finalHubName = widget.hubName!;
        debugPrint('✅ Using hubName from widget: $finalHubName');
      }

      if (finalHubId.isEmpty) {
        final storedHubId = prefs.getString('last_used_hub_id') ?? '';
        final storedDeviceId = prefs.getString('last_used_device_id') ?? '';

        if (storedHubId.isNotEmpty && storedDeviceId == deviceId) {
          finalHubId = storedHubId;
          debugPrint('✅ Using hubId from storage: $finalHubId');
        }
      }

      if (finalHubName == 'Unknown Hub') {
        final storedHubName = prefs.getString('last_used_hub_name') ?? '';
        final storedDeviceId = prefs.getString('last_used_device_id') ?? '';

        if (storedHubName.isNotEmpty && storedDeviceId == deviceId) {
          finalHubName = storedHubName;
          debugPrint(' Using hubName from storage: $finalHubName');
        }
      }

      if (finalHubId.isEmpty) {
        debugPrint(' WARNING: No hubId found for device $deviceId');
        debugPrint(
            '   This booking will not be able to navigate to hub from history');
      }

      final bookingData = {
        'deviceid': deviceId,
        'hubname': finalHubName,
        'hubid': finalHubId,
        'machineid': '#$deviceId',
        'amount': job['booked_user_amount'] ?? job['transactionamount'] ?? 0,
        'endtime': job['device_booked_user_end_time'],
        'starttime': job['device_booked_user_start_time'],
        'washmode': job['booked_user_selected_wash_mode'] ?? 'Quick',
        'washtime': job['booked_user_selected_duration'] ?? '15 Min',
        'detergent':
            job['booked_user_selected_detergent_preference'] ?? 'O3 Treat',
        'paymentid': job['paymentid'] ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'completed': true,
      };

      await prefs.setString(bookingKey, jsonEncode(bookingData));
      _savedJobKeys.add(jobIdentifier);

      debugPrint('═══════════════════════════════════');
      debugPrint(' Saved completed job to history: $bookingKey');
      debugPrint('   Device ID: ${bookingData['deviceid']}');
      debugPrint('   Hub ID: "${bookingData['hubid']}"');
      debugPrint('   Hub Name: "${bookingData['hubname']}"');
      debugPrint('   Amount: ₹${bookingData['amount']}');
      debugPrint('═══════════════════════════════════');
    } catch (e) {
      debugPrint(' Error saving completed job to history: $e');
    }
  }

  void _checkAndMoveCompletedJobs() {
    if (_runningJobsList.isEmpty) return;

    final DateTime now = DateTime.now();
    final List<dynamic> stillRunning = [];
    final List<dynamic> justCompleted = [];

    for (var job in _runningJobsList) {
      bool isCompleted = false;

      final String? deviceStatus = job['devicestatus']?.toString();
      if (deviceStatus == "100") {
        isCompleted = true;
        debugPrint(
          ' Job completed (devicestatus=100): Device ${job['deviceid']}',
        );
      } else {
        final String? endTimeString =
            job['device_booked_user_end_time']?.toString();

        if (endTimeString != null && endTimeString.isNotEmpty) {
          try {
            DateTime endTime = DateTime.parse(endTimeString);
            if (endTime.isUtc || endTimeString.endsWith('Z')) {
              endTime = endTime.toLocal();
            }

            if (now.isAfter(endTime)) {
              isCompleted = true;
              debugPrint(
                ' Job completed (time passed): Device ${job['deviceid']} at ${DateFormat('HH:mm').format(endTime)}',
              );
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing end time: $e');
          }
        }
      }

      if (isCompleted) {
        justCompleted.add(job);
      } else {
        stillRunning.add(job);
      }
    }

    if (justCompleted.isNotEmpty && mounted) {
      setState(() {
        _runningJobsList = stillRunning;

        for (var job in justCompleted) {
          final alreadyInCompleted = _recentlyCompletedJobs.any(
            (existing) =>
                existing['deviceid'] == job['deviceid'] &&
                existing['device_booked_user_end_time'] ==
                    job['device_booked_user_end_time'],
          );

          if (!alreadyInCompleted) {
            _recentlyCompletedJobs.insert(0, job);

            debugPrint(
                '🎉 Job completed! Sending notification and saving: Device ${job['deviceid']}');

            //  CRITICAL FIX: Call the new handler that sends notification FIRST
            _handleJobCompletion(job);

            // Cancel progress notifications
            final deviceId = job['deviceid']?.toString() ?? '';
            if (deviceId.isNotEmpty) {
              _notificationService.cancelProgressNotifications(deviceId);
            }
          }
        }

        _hasRunningJobs = stillRunning.isNotEmpty;
      });

      debugPrint('🎉 Moved ${justCompleted.length} jobs to completed');

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
          debugPrint(' Removed completed jobs from recently completed list');
        }
      });
    }
  }

  Future<void> _fetchRunningJob() async {
    try {
      final jobs = await HomeApi.getRunningJobs();

      if (!mounted) return;

      if (jobs.isEmpty) {
        setState(() {
          _hasRunningJobs = false;
          _runningJobsList = [];
          _isLoading = false;
          _errorMessage = '';
        });
        return;
      }

      final activeJobs = jobs.where((job) {
        final deviceStatus = job['devicestatus']?.toString();
        if (deviceStatus == "100") {
          return false;
        }

        final endTimeString = job['device_booked_user_end_time']?.toString();
        if (endTimeString != null && endTimeString.isNotEmpty) {
          try {
            final endTime = DateTime.parse(endTimeString).toLocal();
            if (DateTime.now().isAfter(endTime)) {
              return false;
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing end time: $e');
          }
        }

        return true;
      }).toList();

      setState(() {
        _hasRunningJobs = activeJobs.isNotEmpty;
        _runningJobsList = activeJobs;
        _isLoading = false;
        _errorMessage = '';
      });

      _checkProgressNotifications();

      debugPrint(' Fetched running jobs: ${activeJobs.length} active');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _hasRunningJobs = false;
        _runningJobsList = [];
        _isLoading = false;
        _errorMessage = e.toString();
      });

      debugPrint(' Error fetching running jobs: $e');
    }
  }

  double _getProgress(Map<String, dynamic> job) {
    try {
      final deviceStatus = job['devicestatus']?.toString();
      if (deviceStatus != null && deviceStatus.isNotEmpty) {
        final status = int.tryParse(deviceStatus);
        if (status != null) {
          return (status / 100).clamp(0.0, 1.0);
        }
      }

      final startTimeString = job['device_booked_user_start_time']?.toString();
      final endTimeString = job['device_booked_user_end_time']?.toString();

      if (startTimeString == null ||
          startTimeString.isEmpty ||
          endTimeString == null ||
          endTimeString.isEmpty) {
        return 0.0;
      }

      DateTime startTime = DateTime.parse(startTimeString);
      DateTime endTime = DateTime.parse(endTimeString);

      if (startTime.isUtc || startTimeString.endsWith('Z')) {
        startTime = startTime.toLocal();
      }
      if (endTime.isUtc || endTimeString.endsWith('Z')) {
        endTime = endTime.toLocal();
      }

      final now = DateTime.now();

      if (now.isBefore(startTime)) {
        return 0.0;
      }

      if (now.isAfter(endTime)) {
        return 1.0;
      }

      final totalDuration = endTime.difference(startTime).inSeconds;
      final elapsedDuration = now.difference(startTime).inSeconds;

      if (totalDuration <= 0) {
        return 0.0;
      }

      final progress = elapsedDuration / totalDuration;
      return progress.clamp(0.0, 1.0);
    } catch (e) {
      debugPrint(' Error calculating progress: $e');
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const QKWashHome()),
            );
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF212121)),
        ),
        title: const Text(
          'Running Jobs',
          style: TextStyle(
            color: Color(0xFF212121),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4A90E2),
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Color(0xFFE57373),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading jobs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchRunningJob,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchRunningJob,
                  color: const Color(0xFF4A90E2),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_runningJobsList.isNotEmpty) ...[
                        ..._runningJobsList.map((job) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildJobCard(job, isActive: true),
                            )),
                      ],
                      if (_recentlyCompletedJobs.isNotEmpty) ...[
                        if (_runningJobsList.isNotEmpty)
                          const SizedBox(height: 16),
                        const Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 20, color: Color(0xFF4CAF50)),
                            SizedBox(width: 8),
                            Text(
                              'Recently Completed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF424242),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._recentlyCompletedJobs.map((job) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildJobCard(job, isActive: false),
                            )),
                      ],
                      if (_runningJobsList.isEmpty &&
                          _recentlyCompletedJobs.isEmpty)
                        _buildEmptyCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, {required bool isActive}) {
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

    return Container(
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
