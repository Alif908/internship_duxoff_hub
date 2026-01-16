/// API Service Configuration for QK Wash
/// Centralized API endpoints and constants
class ApiService {
  // Base URL
  static const String baseUrl = 'https://api.qkwash.com';

  // Authentication Endpoints
  static const String sendOtp = '/api/login/send-otp';
  static const String addOrUpdateUser = '/api/users/addOrUpdate';

  // User Endpoints
  static const String userProfile = '/api/settings/userProfile';
  static const String runningJobs = '/api/user/runningjobs';
  static const String bookingHistory = '/api/user/history';

  // Hub Endpoints
  static const String hubDetails = '/api/hubs/hubs/details';
  static const String bookDevice = '/api/hubs/hubs/book';

  // Payment Endpoints
  static const String createOrder = '/api/users/createOrder';

  // Timeout Configuration
  static const Duration timeoutDuration = Duration(seconds: 30);

  // SharedPreferences Keys
  static const String keyUserMobile = 'user_mobile';
  static const String keySessionToken = 'session_token';
  static const String keyUserId = 'user_id';
  static const String keyUserName = 'user_name';
  static const String keyUserStatus = 'user_status';

  // Refresh Intervals (in seconds)
  static const int runningJobsRefreshInterval = 45;
  static const int profileRefreshInterval = 300; // 5 minutes
}