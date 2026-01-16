import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/views/qkwashome.dart';
import 'dart:async';

class WashStartPage extends StatefulWidget {
  final String machineId;
  final String hubName;
  final String washTime; // e.g., "15 Min", "30 Min", "45 Min"
  final String? deviceId; // ✅ NEW: Add deviceId to track the job
  final String? hubId; // ✅ NEW: Add hubId

  const WashStartPage({
    super.key,
    required this.machineId,
    required this.hubName,
    required this.washTime,
    this.deviceId,
    this.hubId,
  });

  @override
  State<WashStartPage> createState() => _WashStartPageState();
}

class _WashStartPageState extends State<WashStartPage> {
  bool isWashing = false;
  int remainingSeconds = 0;
  Timer? _timer;
  Timer? _apiCheckTimer; // ✅ NEW: Timer to check API status

  @override
  void dispose() {
    _timer?.cancel();
    _apiCheckTimer?.cancel(); // ✅ Cancel API check timer
    super.dispose();
  }

  /// ✅ NEW: Check if job is still running on backend
  Future<bool> _checkJobStatus() async {
    try {
      final jobs = await HomeApi.getRunningJobs();
      
      // Check if our device is still in running jobs
      final ourJob = jobs.firstWhere(
        (job) => job['deviceid']?.toString() == widget.deviceId ||
                 job['deviceid']?.toString() == widget.machineId,
        orElse: () => null,
      );

      if (ourJob == null) {
        // Job not found in running jobs - it's completed!
        debugPrint('✅ Job completed - no longer in running jobs');
        return false;
      }

      // Check if end time has passed
      final endTimeString = ourJob['device_booked_user_end_time']?.toString();
      if (endTimeString != null && endTimeString.isNotEmpty) {
        try {
          final endTime = DateTime.parse(endTimeString).toLocal();
          final now = DateTime.now();
          
          if (now.isAfter(endTime)) {
            debugPrint('✅ Job completed - end time passed');
            return false;
          }
          
          // ✅ Update remaining seconds based on backend data
          final remaining = endTime.difference(now);
          if (mounted && remaining.inSeconds > 0) {
            setState(() {
              remainingSeconds = remaining.inSeconds;
            });
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing end time: $e');
        }
      }

      debugPrint('🔄 Job still running');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking job status: $e');
      // On error, assume job is still running
      return true;
    }
  }

  /// Start wash - booking already done, just start timer
  void _startWash() {
    setState(() {
      isWashing = true;
      // Extract minutes from washTime (e.g., "15 Min" -> 15)
      final minutes = int.tryParse(widget.washTime.split(' ')[0]) ?? 15;
      remainingSeconds = minutes * 60;
    });

    // Start countdown timer (update UI every second)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
        }
      });
    });

    // ✅ NEW: Check backend status every 30 seconds
    _apiCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final isStillRunning = await _checkJobStatus();
      
      if (!isStillRunning && mounted) {
        // Job completed on backend
        _timer?.cancel();
        _apiCheckTimer?.cancel();
        setState(() {
          remainingSeconds = 0;
        });
        _showCompletionMessage();
      }
    });

    // ✅ NEW: Also check immediately when wash starts
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted) {
        await _checkJobStatus();
      }
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wash started successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Show completion message and navigate to home
  void _showCompletionMessage() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text(
              'Wash Completed!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Your wash cycle has completed successfully. Please collect your clothes.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _navigateToHome();
            },
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFF4A90E2),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate back to home and refresh running jobs
  void _navigateToHome() {
    if (!mounted) return;

    // ✅ Navigate to home with History tab (index 1) to show completed wash
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const QKWashHome(initialTabIndex: 1),
      ),
      (route) => false,
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    final totalMinutes = int.tryParse(widget.washTime.split(' ')[0]) ?? 15;
    final totalSeconds = totalMinutes * 60;
    if (totalSeconds == 0) return 0;
    return 1 - (remainingSeconds / totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isWashing) {
          // Allow exit during wash - job is already running on backend
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Wash in Progress',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'Your wash is currently running. You can safely exit and check the status from the home page.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'STAY',
                    style: TextStyle(
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'GO TO HOME',
                    style: TextStyle(
                      color: Color(0xFF4A90E2),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (shouldExit == true && mounted) {
            _navigateToHome();
          }
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: isWashing
                ? () async {
                    final shouldExit = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Wash in Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: const Text(
                          'Your wash is currently running. You can safely exit and check the status from the home page.',
                          style: TextStyle(fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              'STAY',
                              style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'GO TO HOME',
                              style: TextStyle(
                                color: Color(0xFF4A90E2),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (shouldExit == true && mounted) {
                      _navigateToHome();
                    }
                  }
                : () => Navigator.pop(context),
          ),
          title: Text(
            widget.hubName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Washing Machine Illustration
                      Image.asset(
                        'assets/images/startimg.png',
                        width: double.infinity,
                        height: 280,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 280,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.local_laundry_service,
                              size: 100,
                              color: Colors.grey[400],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // Show instructions or timer based on state
                      if (!isWashing) ...[
                        const Text(
                          'Load your clothes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Apply washing liquid',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Close the door',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Press start',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ] else ...[
                        // Washing status
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.cleaning_services,
                                    color: Color(0xFF4A90E2),
                                    size: 28,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Washing in Progress',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A90E2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Timer display
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatTime(remainingSeconds),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4A90E2),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              Text(
                                'Time Remaining',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Progress indicator
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: _getProgress(),
                                  backgroundColor: const Color(0xFFE8E8E8),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF4A90E2),
                                      ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange[200]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange[700],
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You can exit safely. Check wash status from home page.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Start Button - Fixed at bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isWashing ? null : _startWash,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      isWashing ? 'WASHING...' : 'START',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}