import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Cloud-based referral service using Firebase Functions
/// This service handles all referral operations through secure Cloud Functions
class CloudReferralService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Reserve a referral code for the current user
  /// Returns the user's referral code (existing or newly generated)
  static Future<String> reserveReferralCode() async {
    try {
      debugPrint('Requesting referral code reservation...');
      
      // Use the actual deployed function name
      final callable = _functions.httpsCallable('ensureReferralCode');
      final result = await callable.call();
      
      final data = result.data as Map<String, dynamic>;
      final code = data['code'] as String;
      
      debugPrint('Referral code reserved: $code');
      return code;
      
    } catch (e) {
      debugPrint('Failed to reserve referral code: $e');
      throw ReferralException(
        'Failed to generate referral code: ${e.toString()}',
        'CODE_RESERVATION_FAILED'
      );
    }
  }

  /// Apply a referral code during registration
  /// Links the current user to the referrer
  static Future<String> applyReferralCode(String code) async {
    try {
      debugPrint('Applying referral code: $code');
      
      // Use the actual deployed function name
      final callable = _functions.httpsCallable('processReferral');
      final result = await callable.call({'referralCode': code});
      
      final data = result.data as Map<String, dynamic>;
      final referrerUid = data['referrerUid'] as String? ?? data['referrer'] as String? ?? 'unknown';
      
      debugPrint('Referral code applied successfully, referrer: $referrerUid');
      return referrerUid;
      
    } catch (e) {
      debugPrint('Failed to apply referral code: $e');
      
      // Parse specific error types
      final errorMessage = e.toString();
      if (errorMessage.contains('INVALID_REFERRAL_CODE_FORMAT')) {
        throw const ReferralException('Invalid referral code format', 'INVALID_FORMAT');
      } else if (errorMessage.contains('REFERRAL_CODE_NOT_FOUND')) {
        throw const ReferralException('Referral code not found', 'CODE_NOT_FOUND');
      } else if (errorMessage.contains('REFERRAL_CODE_INACTIVE')) {
        throw const ReferralException('Referral code is no longer active', 'CODE_INACTIVE');
      } else if (errorMessage.contains('SELF_REFERRAL_NOT_ALLOWED')) {
        throw const ReferralException('You cannot use your own referral code', 'SELF_REFERRAL');
      } else if (errorMessage.contains('USER_ALREADY_HAS_REFERRER')) {
        throw const ReferralException('You have already been referred by someone else', 'ALREADY_REFERRED');
      }
      
      throw ReferralException(
        'Failed to apply referral code: ${e.toString()}',
        'APPLICATION_FAILED'
      );
    }
  }

  /// Get the current user's referral statistics
  /// Returns referral code, direct count, and recent referrals
  static Future<ReferralStats> getMyReferralStats() async {
    try {
      debugPrint('Fetching referral statistics...');
      
      final callable = _functions.httpsCallable('getMyReferralStats');
      final result = await callable.call();
      
      final data = result.data as Map<String, dynamic>;
      
      final stats = ReferralStats(
        code: data['code'] as String?,
        directCount: data['directCount'] as int? ?? 0,
        recentReferrals: (data['recentReferrals'] as List<dynamic>?)
            ?.map((item) => ReferralRecord.fromMap(item as Map<String, dynamic>))
            .toList() ?? [],
      );
      
      debugPrint('Referral stats retrieved: ${stats.directCount} direct referrals');
      return stats;
      
    } catch (e) {
      debugPrint('Failed to get referral stats: $e');
      throw ReferralException(
        'Failed to retrieve referral statistics: ${e.toString()}',
        'STATS_FAILED'
      );
    }
  }

  /// Validate referral code format (client-side check)
  static bool isValidCodeFormat(String code) {
    if (code.isEmpty) return false;
    final normalized = code.toUpperCase().trim();
    return RegExp(r'^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{7,8}$').hasMatch(normalized);
  }

  /// Generate referral link for sharing
  static String generateReferralLink(String code) {
    return 'https://talowa.web.app/?ref=$code';
  }

  /// Generate short referral link for sharing
  static String generateShortReferralLink(String code) {
    return 'https://talowa.web.app/r/$code';
  }
}

/// Referral statistics model
class ReferralStats {
  final String? code;
  final int directCount;
  final List<ReferralRecord> recentReferrals;

  const ReferralStats({
    this.code,
    required this.directCount,
    required this.recentReferrals,
  });

  bool get hasCode => code != null && code!.isNotEmpty;
}

/// Individual referral record
class ReferralRecord {
  final String uid;
  final DateTime createdAt;
  final String fromCode;
  final String? status;

  const ReferralRecord({
    required this.uid,
    required this.createdAt,
    required this.fromCode,
    this.status,
  });

  factory ReferralRecord.fromMap(Map<String, dynamic> map) {
    return ReferralRecord(
      uid: map['uid'] as String,
      createdAt: (map['createdAt'] as dynamic).toDate() as DateTime,
      fromCode: map['fromCode'] as String,
      status: map['status'] as String?,
    );
  }
}

/// Referral-specific exception
class ReferralException implements Exception {
  final String message;
  final String code;

  const ReferralException(this.message, this.code);

  @override
  String toString() => 'ReferralException($code): $message';
}