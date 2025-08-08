class AppConfig {
  // Root admin configuration - Set by organization
  static const String rootAdminPhone = '+91XXXXXXXXXX'; // To be configured

  // Payment configuration
  static const double membershipFee = 100.0;
  static const String currency = '₹';

  // App configuration
  static const String appName = 'Talowa';
  static const String appTagline = 'Empowering Assigned Land Owners';

  // AI Assistant backend configuration
  // Set to your deployed Cloud Function URL (asia-south1 region by default)
  static const String aiBackendBaseUrl = 'https://asia-south1-talowa.cloudfunctions.net';
  static const bool aiBackendEnabled = false; // Flip to true after backend deploy
  static const int aiTimeoutMs = 8000; // 8 seconds safety timeout

  // Referral configuration
  static const String referralBaseUrl = 'https://talowa.app/register';

  // Validation patterns
  static const String phonePattern = r'^\d{10}$';
  static const String otpPattern = r'^\d{6}$';
  static const String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';

  // Check if phone number is root admin
  static bool isRootAdmin(String? phoneNumber) {
    return phoneNumber == rootAdminPhone;
  }

  // Generate referral link
  static String generateReferralLink(String referralCode) {
    return '$referralBaseUrl?ref=$referralCode';
  }
}