import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const int _progress50Id = 2000;
  static const int _progress85Id = 3000;
  static const int _completionId = 4000;

  // Keys to track sent notifications
  static const String _pref50Sent = 'notification_50_sent_';
  static const String _pref85Sent = 'notification_85_sent_';
  static const String _prefCompletionSent = 'notification_completion_sent_';

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions for Android 13+
      await _requestPermissions();

      _isInitialized = true;
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      final IOSFlutterLocalNotificationsPlugin? iosPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // You can navigate to specific pages based on payload
    // For example, navigate to running jobs or history page
  }

  /// Create a unique job identifier
  String _getJobIdentifier(Map<String, dynamic> job) {
    final deviceId = (job['deviceid'] ?? '').toString();
    final endTime = (job['device_booked_user_end_time'] ?? '').toString();
    return '${deviceId}_$endTime';
  }

  /// Check if notification was already sent
  Future<bool> _wasNotificationSent(String prefKey, String jobId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$prefKey$jobId') ?? false;
    } catch (e) {
      debugPrint('❌ Error checking notification status: $e');
      return false;
    }
  }

  /// Mark notification as sent
  Future<void> _markNotificationSent(String prefKey, String jobId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$prefKey$jobId', true);
      debugPrint('✅ Marked notification as sent: $prefKey$jobId');
    } catch (e) {
      debugPrint('❌ Error marking notification as sent: $e');
    }
  }

  /// Clear notification flags for a job (when job is removed)
  Future<void> clearNotificationFlags(String jobId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_pref50Sent$jobId');
      await prefs.remove('$_pref85Sent$jobId');
      await prefs.remove('$_prefCompletionSent$jobId');
      debugPrint('🗑️ Cleared notification flags for job: $jobId');
    } catch (e) {
      debugPrint('❌ Error clearing notification flags: $e');
    }
  }

  /// Calculate progress percentage
  int _calculateProgress(Map<String, dynamic> job) {
    try {
      // First check if devicestatus is available
      final deviceStatus = job['devicestatus']?.toString();
      if (deviceStatus != null && deviceStatus.isNotEmpty) {
        final status = int.tryParse(deviceStatus);
        if (status != null) {
          return status;
        }
      }

      // Fallback: Calculate based on time
      final startTimeString = job['device_booked_user_start_time']?.toString();
      final endTimeString = job['device_booked_user_end_time']?.toString();

      if (startTimeString == null ||
          startTimeString.isEmpty ||
          endTimeString == null ||
          endTimeString.isEmpty) {
        return 0;
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

      // If hasn't started yet
      if (now.isBefore(startTime)) {
        return 0;
      }

      // If already completed
      if (now.isAfter(endTime)) {
        return 100;
      }

      // Calculate progress
      final totalDuration = endTime.difference(startTime).inSeconds;
      final elapsedDuration = now.difference(startTime).inSeconds;

      if (totalDuration <= 0) {
        return 0;
      }

      final progress = ((elapsedDuration / totalDuration) * 100).round();
      return progress.clamp(0, 100);
    } catch (e) {
      debugPrint('❌ Error calculating progress: $e');
      return 0;
    }
  }

  /// Show 50% progress notification
  Future<void> _show50PercentNotification(Map<String, dynamic> job) async {
    try {
      final hubName = job['hubname']?.toString() ?? 'Your hub';
      final deviceId = job['deviceid']?.toString() ?? 'Unknown';
      final washMode =
          job['booked_user_selected_wash_mode']?.toString() ?? 'Wash';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'wash_progress',
        'Wash Progress',
        channelDescription: 'Notifications for wash cycle progress',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _progress50Id + deviceId.hashCode,
        ' Wash Halfway Done!',
        'Machine #$deviceId at $hubName is 50% complete. Your $washMode cycle is progressing well!',
        details,
        payload: 'progress_50_$deviceId',
      );

      debugPrint(' Sent 50% notification for device $deviceId');
    } catch (e) {
      debugPrint(' Error showing 50% notification: $e');
    }
  }

  /// Show 85% progress notification
  Future<void> _show85PercentNotification(Map<String, dynamic> job) async {
    try {
      final hubName = job['hubname']?.toString() ?? 'Your hub';
      final deviceId = job['deviceid']?.toString() ?? 'Unknown';
      final washMode =
          job['booked_user_selected_wash_mode']?.toString() ?? 'Wash';

      // Calculate estimated time remaining
      String timeRemaining = 'soon';
      try {
        final endTimeString = job['device_booked_user_end_time']?.toString();
        if (endTimeString != null && endTimeString.isNotEmpty) {
          final endTime = DateTime.parse(endTimeString).toLocal();
          final now = DateTime.now();
          final diff = endTime.difference(now);

          if (diff.inMinutes > 0) {
            timeRemaining = 'in about ${diff.inMinutes} min';
          }
        }
      } catch (e) {
        debugPrint(' Error calculating time remaining: $e');
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'wash_progress',
        'Wash Progress',
        channelDescription: 'Notifications for wash cycle progress',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _progress85Id + deviceId.hashCode,
        ' Almost Done!',
        'Machine #$deviceId at $hubName is 85% complete. Your $washMode cycle will finish $timeRemaining.',
        details,
        payload: 'progress_85_$deviceId',
      );

      debugPrint(' Sent 85% notification for device $deviceId');
    } catch (e) {
      debugPrint(' Error showing 85% notification: $e');
    }
  }

  Future<void> showCompletionNotification(Map<String, dynamic> job) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final jobId = _getJobIdentifier(job);

      // Check if completion notification already sent
      if (await _wasNotificationSent(_prefCompletionSent, jobId)) {
        debugPrint(' Completion notification already sent for $jobId');
        return;
      }

      final hubName = job['hubname']?.toString() ?? 'Your hub';
      final deviceId = job['deviceid']?.toString() ?? 'Unknown';
      final washMode =
          job['booked_user_selected_wash_mode']?.toString() ?? 'Wash';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'wash_completion',
        'Wash Completion',
        channelDescription: 'Notifications when wash cycle is complete',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _completionId + deviceId.hashCode,
        'Wash Complete!',
        'Machine #$deviceId at $hubName has completed your $washMode cycle. Please collect your laundry!',
        details,
        payload: 'completion_$deviceId',
      );

      // Mark as sent
      await _markNotificationSent(_prefCompletionSent, jobId);

      debugPrint('Sent completion notification for device $deviceId');
    } catch (e) {
      debugPrint('Error showing completion notification: $e');
    }
  }

  Future<void> checkProgressNotificationsOnly(Map<String, dynamic> job) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final jobId = _getJobIdentifier(job);
      final progress = _calculateProgress(job);

      debugPrint(' Job $jobId progress: $progress% (progress check only)');

      //  50% notification
      if (progress >= 50) {
        if (!await _wasNotificationSent(_pref50Sent, jobId)) {
          await _show50PercentNotification(job);
          await _markNotificationSent(_pref50Sent, jobId);
        }
      }

      //  85% notification
      if (progress >= 85) {
        if (!await _wasNotificationSent(_pref85Sent, jobId)) {
          await _show85PercentNotification(job);
          await _markNotificationSent(_pref85Sent, jobId);
        }
      }
    } catch (e) {
      debugPrint(' Error checking progress notifications: $e');
    }
  }

  Future<void> checkAndSendProgressNotifications(
      Map<String, dynamic> job) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final jobId = _getJobIdentifier(job);
      final progress = _calculateProgress(job);

      debugPrint(' Job $jobId progress: $progress%');

      // Check for 50% notification
      if (progress >= 50) {
        if (!await _wasNotificationSent(_pref50Sent, jobId)) {
          await _show50PercentNotification(job);
          await _markNotificationSent(_pref50Sent, jobId);
        }
      }

      // Check for 85% notification
      if (progress >= 85) {
        if (!await _wasNotificationSent(_pref85Sent, jobId)) {
          await _show85PercentNotification(job);
          await _markNotificationSent(_pref85Sent, jobId);
        }
      }

      // NOTE: This method does NOT check for completion
      // Completion should be triggered from _saveCompletedJobToHistory
    } catch (e) {
      debugPrint(' Error checking progress notifications: $e');
    }
  }

  /// Monitor multiple jobs
  Future<void> monitorJobs(List<Map<String, dynamic>> jobs) async {
    for (var job in jobs) {
      await checkProgressNotificationsOnly(job);
    }
  }

  /// Cancel progress notifications for a specific device (50% and 85% only)
  Future<void> cancelProgressNotifications(String deviceId) async {
    try {
      // Only cancel progress notifications, NOT completion
      await _notifications.cancel(_progress50Id + deviceId.hashCode);
      await _notifications.cancel(_progress85Id + deviceId.hashCode);
      debugPrint(' Cancelled progress notifications for device $deviceId');
    } catch (e) {
      debugPrint(' Error cancelling progress notifications: $e');
    }
  }

  /// Use this only when explicitly removing/cancelling a job
  Future<void> cancelAllDeviceNotifications(String deviceId) async {
    try {
      await _notifications.cancel(_progress50Id + deviceId.hashCode);
      await _notifications.cancel(_progress85Id + deviceId.hashCode);
      await _notifications.cancel(_completionId + deviceId.hashCode);
      debugPrint(' Cancelled ALL notifications for device $deviceId');
    } catch (e) {
      debugPrint(' Error cancelling all notifications: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      debugPrint(' Cancelled all notifications');
    } catch (e) {
      debugPrint(' Error cancelling all notifications: $e');
    }
  }
}
