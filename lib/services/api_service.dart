
class ApiService {
  // baseurl
  static const String baseUrl = 'https://api.qkwash.com';

  // authendpoint
  static const String sendOtp = '/api/login/send-otp';
  static const String addOrUpdateUser = '/api/users/addOrUpdate';

  // user
  static const String userProfile = '/api/settings/userProfile';
  static const String runningJobs = '/api/user/runningjobs';
  static const String bookingHistory = '/api/user/history';

  // hub
  static const String hubDetails = '/api/hubs/hubs/details';
  static const String bookDevice = '/api/hubs/hubs/book';

  //payment
  static const String createOrder = '/api/users/createOrder';

  //timeout confi
  static const Duration timeoutDuration = Duration(seconds: 30);

  // sharedpreferance keys
  static const String keyUserMobile = 'user_mobile';
  static const String keySessionToken = 'session_token';
  static const String keyUserId = 'user_id';
  static const String keyUserName = 'user_name';
  static const String keyUserStatus = 'user_status';

  // refresh
  static const int runningJobsRefreshInterval = 45;
  static const int profileRefreshInterval = 300; // 5 minutes
}