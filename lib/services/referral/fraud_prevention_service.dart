import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Exception thrown when fraud prevention operations fail
class FraudPreventionException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const FraudPreventionException(this.message, [this.code = 'FRAUD_PREVENTION_FAILED', this.context]);
  
  @override
  String toString() => 'FraudPreventionException: $message';
}

/// Device fingerprint data
class DeviceFingerprint {
  final String deviceId;
  final String platform;
  final String model;
  final String osVersion;
  final String appVersion;
  final String fingerprint;
  final DateTime createdAt;
  
  const DeviceFingerprint({
    required this.deviceId,
    required this.platform,
    required this.model,
    required this.osVersion,
    required this.appVersion,
    required this.fingerprint,
    required this.createdAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'platform': platform,
      'model': model,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'fingerprint': fingerprint,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  factory DeviceFingerprint.fromMap(Map<String, dynamic> map) {
    return DeviceFingerprint(
      deviceId: map['deviceId'] ?? '',
      platform: map['platform'] ?? '',
      model: map['model'] ?? '',
      osVersion: map['osVersion'] ?? '',
      appVersion: map['appVersion'] ?? '',
      fingerprint: map['fingerprint'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Service for fraud prevention and security
class FraudPreventionService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Fraud detection thresholds
  static const int MAX_ACCOUNTS_PER_DEVICE = 3;
  static const int MAX_REFERRALS_PER_DAY = 10;
  static const int MAX_REFERRALS_PER_HOUR = 3;
  static const Duration SUSPICIOUS_ACTIVITY_WINDOW = Duration(hours: 24);
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Generate device fingerprint
  static Future<DeviceFingerprint> generateDeviceFingerprint() async {
    try {
      String deviceId = '';
      String platform = '';
      String model = '';
      String osVersion = '';
      
      if (kIsWeb) {
        platform = 'web';
        model = 'browser';
        osVersion = 'unknown';
        deviceId = _generateWebFingerprint();
      } else {
        try {
          if (Platform.isAndroid) {
            final androidInfo = await _deviceInfo.androidInfo;
            platform = 'android';
            model = androidInfo.model;
            osVersion = androidInfo.version.release;
            deviceId = androidInfo.id;
          } else if (Platform.isIOS) {
            final iosInfo = await _deviceInfo.iosInfo;
            platform = 'ios';
            model = iosInfo.model;
            osVersion = iosInfo.systemVersion;
            deviceId = iosInfo.identifierForVendor ?? 'unknown';
          } else {
            // Fallback for test environment or unsupported platforms
            platform = 'test';
            model = 'test_device';
            osVersion = '1.0';
            deviceId = 'test_device_${DateTime.now().millisecondsSinceEpoch}';
          }
        } catch (e) {
          // Fallback for test environment
          platform = 'test';
          model = 'test_device';
          osVersion = '1.0';
          deviceId = 'test_device_${DateTime.now().millisecondsSinceEpoch}';
        }
      }
      
      const appVersion = '1.0.0'; // Should be from package_info_plus
      
      // Generate unique fingerprint
      final fingerprintData = '$deviceId-$platform-$model-$osVersion-$appVersion';
      final bytes = utf8.encode(fingerprintData);
      final digest = sha256.convert(bytes);
      final fingerprint = digest.toString();
      
      return DeviceFingerprint(
        deviceId: deviceId,
        platform: platform,
        model: model,
        osVersion: osVersion,
        appVersion: appVersion,
        fingerprint: fingerprint,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw FraudPreventionException(
        'Failed to generate device fingerprint: $e',
        'FINGERPRINT_GENERATION_FAILED'
      );
    }
  }
  
  /// Generate web-specific fingerprint
  static String _generateWebFingerprint() {
    // In a real implementation, this would collect browser fingerprint data
    // For now, generate a random identifier
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'web_$timestamp';
  }
  
  /// Register device fingerprint for user
  static Future<void> registerDeviceFingerprint(String userId, DeviceFingerprint fingerprint) async {
    try {
      await _firestore.collection('deviceFingerprints').add({
        'userId': userId,
        'deviceId': fingerprint.deviceId,
        'platform': fingerprint.platform,
        'model': fingerprint.model,
        'osVersion': fingerprint.osVersion,
        'appVersion': fingerprint.appVersion,
        'fingerprint': fingerprint.fingerprint,
        'registeredAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (e) {
      throw FraudPreventionException(
        'Failed to register device fingerprint: $e',
        'FINGERPRINT_REGISTRATION_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Check for multiple accounts on same device
  static Future<Map<String, dynamic>> checkMultipleAccounts(String userId, DeviceFingerprint fingerprint) async {
    try {
      final query = await _firestore
          .collection('deviceFingerprints')
          .where('fingerprint', isEqualTo: fingerprint.fingerprint)
          .where('isActive', isEqualTo: true)
          .get();
      
      final existingUsers = <String>[];
      for (final doc in query.docs) {
        final data = doc.data();
        final existingUserId = data['userId'] as String;
        if (existingUserId != userId) {
          existingUsers.add(existingUserId);
        }
      }
      
      final isSuspicious = existingUsers.length >= MAX_ACCOUNTS_PER_DEVICE;
      
      if (isSuspicious) {
        await _logSuspiciousActivity(userId, 'multiple_accounts', {
          'fingerprint': fingerprint.fingerprint,
          'existingUsers': existingUsers,
          'deviceInfo': fingerprint.toMap(),
        });
      }
      
      return {
        'isSuspicious': isSuspicious,
        'existingUsers': existingUsers,
        'accountCount': existingUsers.length + 1,
        'threshold': MAX_ACCOUNTS_PER_DEVICE,
      };
    } catch (e) {
      throw FraudPreventionException(
        'Failed to check multiple accounts: $e',
        'MULTIPLE_ACCOUNTS_CHECK_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Check referral rate limits
  static Future<Map<String, dynamic>> checkReferralRateLimits(String userId) async {
    try {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final hourStart = DateTime(now.year, now.month, now.day, now.hour);
      
      // Check daily referrals
      final dailyQuery = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .where('registeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .get();
      
      final dailyCount = dailyQuery.docs.length;
      
      // Check hourly referrals
      final hourlyQuery = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .where('registeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(hourStart))
          .get();
      
      final hourlyCount = hourlyQuery.docs.length;
      
      final isDailyLimitExceeded = dailyCount >= MAX_REFERRALS_PER_DAY;
      final isHourlyLimitExceeded = hourlyCount >= MAX_REFERRALS_PER_HOUR;
      
      if (isDailyLimitExceeded || isHourlyLimitExceeded) {
        await _logSuspiciousActivity(userId, 'rate_limit_exceeded', {
          'dailyCount': dailyCount,
          'hourlyCount': hourlyCount,
          'dailyLimit': MAX_REFERRALS_PER_DAY,
          'hourlyLimit': MAX_REFERRALS_PER_HOUR,
        });
      }
      
      return {
        'isDailyLimitExceeded': isDailyLimitExceeded,
        'isHourlyLimitExceeded': isHourlyLimitExceeded,
        'dailyCount': dailyCount,
        'hourlyCount': hourlyCount,
        'dailyLimit': MAX_REFERRALS_PER_DAY,
        'hourlyLimit': MAX_REFERRALS_PER_HOUR,
      };
    } catch (e) {
      throw FraudPreventionException(
        'Failed to check referral rate limits: $e',
        'RATE_LIMIT_CHECK_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Detect suspicious referral patterns
  static Future<Map<String, dynamic>> detectSuspiciousPatterns(String userId) async {
    try {
      final suspiciousPatterns = <String>[];
      final details = <String, dynamic>{};
      
      // Check for rapid sequential registrations
      final recentReferrals = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .orderBy('registeredAt', descending: true)
          .limit(10)
          .get();
      
      if (recentReferrals.docs.length >= 3) {
        final timestamps = recentReferrals.docs
            .map((doc) => (doc.data()['registeredAt'] as Timestamp).toDate())
            .toList();
        
        // Check if registrations are too close together
        for (int i = 0; i < timestamps.length - 1; i++) {
          final timeDiff = timestamps[i].difference(timestamps[i + 1]);
          if (timeDiff.inMinutes < 5) {
            suspiciousPatterns.add('rapid_sequential_registrations');
            details['rapidRegistrations'] = true;
            break;
          }
        }
      }
      
      // Check for similar email patterns
      final allReferrals = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .get();
      
      final emails = allReferrals.docs
          .map((doc) => doc.data()['email'] as String?)
          .where((email) => email != null)
          .toList();
      
      if (_hasSimilarEmailPatterns(emails.cast<String>())) {
        suspiciousPatterns.add('similar_email_patterns');
        details['similarEmails'] = true;
      }
      
      // Check for same IP address registrations
      // This would require IP tracking implementation
      
      if (suspiciousPatterns.isNotEmpty) {
        await _logSuspiciousActivity(userId, 'suspicious_patterns', {
          'patterns': suspiciousPatterns,
          'details': details,
        });
      }
      
      return {
        'isSuspicious': suspiciousPatterns.isNotEmpty,
        'patterns': suspiciousPatterns,
        'details': details,
      };
    } catch (e) {
      throw FraudPreventionException(
        'Failed to detect suspicious patterns: $e',
        'PATTERN_DETECTION_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Check for similar email patterns
  static bool _hasSimilarEmailPatterns(List<String> emails) {
    if (emails.length < 3) return false;
    
    // Check for sequential numbers in email addresses
    final sequentialPattern = RegExp(r'(\w+)(\d+)@');
    final baseEmails = <String, List<int>>{};
    
    for (final email in emails) {
      final match = sequentialPattern.firstMatch(email);
      if (match != null) {
        final base = match.group(1)!;
        final number = int.tryParse(match.group(2)!) ?? 0;
        
        baseEmails[base] = (baseEmails[base] ?? [])..add(number);
      }
    }
    
    // Check if any base has sequential numbers
    for (final numbers in baseEmails.values) {
      if (numbers.length >= 3) {
        numbers.sort();
        bool isSequential = true;
        for (int i = 1; i < numbers.length; i++) {
          if (numbers[i] != numbers[i - 1] + 1) {
            isSequential = false;
            break;
          }
        }
        if (isSequential) return true;
      }
    }
    
    return false;
  }
  
  /// Comprehensive fraud check
  static Future<Map<String, dynamic>> performFraudCheck(String userId) async {
    try {
      final fingerprint = await generateDeviceFingerprint();
      
      // Register device fingerprint
      await registerDeviceFingerprint(userId, fingerprint);
      
      // Perform all checks
      final multipleAccountsCheck = await checkMultipleAccounts(userId, fingerprint);
      final rateLimitCheck = await checkReferralRateLimits(userId);
      final patternCheck = await detectSuspiciousPatterns(userId);
      
      final isFraudulent = multipleAccountsCheck['isSuspicious'] ||
                          rateLimitCheck['isDailyLimitExceeded'] ||
                          rateLimitCheck['isHourlyLimitExceeded'] ||
                          patternCheck['isSuspicious'];
      
      final riskScore = _calculateRiskScore(multipleAccountsCheck, rateLimitCheck, patternCheck);
      
      return {
        'isFraudulent': isFraudulent,
        'riskScore': riskScore,
        'deviceFingerprint': fingerprint.toMap(),
        'checks': {
          'multipleAccounts': multipleAccountsCheck,
          'rateLimits': rateLimitCheck,
          'patterns': patternCheck,
        },
        'checkedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw FraudPreventionException(
        'Failed to perform fraud check: $e',
        'FRAUD_CHECK_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Calculate risk score (0-100)
  static int _calculateRiskScore(
    Map<String, dynamic> multipleAccountsCheck,
    Map<String, dynamic> rateLimitCheck,
    Map<String, dynamic> patternCheck,
  ) {
    int score = 0;
    
    // Multiple accounts risk
    if (multipleAccountsCheck['isSuspicious']) {
      score += 40;
    } else if (multipleAccountsCheck['accountCount'] > 1) {
      score += 15;
    }
    
    // Rate limit risk
    if (rateLimitCheck['isDailyLimitExceeded']) {
      score += 30;
    } else if (rateLimitCheck['isHourlyLimitExceeded']) {
      score += 20;
    }
    
    // Pattern risk
    if (patternCheck['isSuspicious']) {
      final patterns = patternCheck['patterns'] as List;
      score += patterns.length * 15;
    }
    
    return score.clamp(0, 100);
  }
  
  /// Log suspicious activity
  static Future<void> _logSuspiciousActivity(
    String userId,
    String activityType,
    Map<String, dynamic> details,
  ) async {
    try {
      await _firestore.collection('suspiciousActivities').add({
        'userId': userId,
        'activityType': activityType,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'resolved': false,
      });
    } catch (e) {
      // Don't fail the main operation for logging errors
      print('Warning: Failed to log suspicious activity: $e');
    }
  }
  
  /// Get user's fraud history
  static Future<List<Map<String, dynamic>>> getUserFraudHistory(String userId) async {
    try {
      final query = await _firestore
          .collection('suspiciousActivities')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw FraudPreventionException(
        'Failed to get user fraud history: $e',
        'FRAUD_HISTORY_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Block user for fraudulent activity
  static Future<void> blockUser(String userId, String reason, {String? adminUserId}) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBlocked': true,
        'blockReason': reason,
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': adminUserId ?? 'system',
      });
      
      // Log the blocking action
      await _firestore.collection('userBlocks').add({
        'userId': userId,
        'reason': reason,
        'blockedBy': adminUserId ?? 'system',
        'blockedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FraudPreventionException(
        'Failed to block user: $e',
        'USER_BLOCKING_FAILED',
        {'userId': userId, 'reason': reason}
      );
    }
  }
  
  /// Unblock user
  static Future<void> unblockUser(String userId, {String? adminUserId}) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBlocked': false,
        'blockReason': FieldValue.delete(),
        'unblockedAt': FieldValue.serverTimestamp(),
        'unblockedBy': adminUserId ?? 'system',
      });
    } catch (e) {
      throw FraudPreventionException(
        'Failed to unblock user: $e',
        'USER_UNBLOCKING_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Get fraud statistics
  static Future<Map<String, dynamic>> getFraudStatistics() async {
    try {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      
      // Get today's suspicious activities
      final todayQuery = await _firestore
          .collection('suspiciousActivities')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .get();
      
      // Get blocked users
      final blockedQuery = await _firestore
          .collection('users')
          .where('isBlocked', isEqualTo: true)
          .get();
      
      // Group activities by type
      final activitiesByType = <String, int>{};
      for (final doc in todayQuery.docs) {
        final activityType = doc.data()['activityType'] as String;
        activitiesByType[activityType] = (activitiesByType[activityType] ?? 0) + 1;
      }
      
      return {
        'todaySuspiciousActivities': todayQuery.docs.length,
        'totalBlockedUsers': blockedQuery.docs.length,
        'activitiesByType': activitiesByType,
        'calculatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw FraudPreventionException(
        'Failed to get fraud statistics: $e',
        'FRAUD_STATS_FAILED'
      );
    }
  }
}
