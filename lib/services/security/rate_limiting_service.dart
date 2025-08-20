// Rate Limiting Service for TALOWA
// Implements rate limiting to prevent spam and abuse
// Requirements: 6.6, 10.2

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import 'audit_logging_service.dart';

class RateLimitingService {
  static final RateLimitingService _instance = RateLimitingService._internal();
  factory RateLimitingService() => _instance;
  RateLimitingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLoggingService _auditService = AuditLoggingService();
  
  final String _rateLimitsCollection = 'rate_limits';
  final String _violationsCollection = 'rate_limit_violations';
  
  // In-memory cache for rate limit tracking
  final Map<String, RateLimitTracker> _trackers = {};
  
  // Rate limit configurations
  static const Map<String, RateLimitConfig> _rateLimitConfigs = {
    'send_message': RateLimitConfig(
      maxRequests: 60,
      windowMinutes: 1,
      burstLimit: 10,
      penaltyMinutes: 5,
    ),
    'send_group_message': RateLimitConfig(
      maxRequests: 30,
      windowMinutes: 1,
      burstLimit: 5,
      penaltyMinutes: 10,
    ),
    'create_group': RateLimitConfig(
      maxRequests: 5,
      windowMinutes: 60,
      burstLimit: 2,
      penaltyMinutes: 60,
    ),
    'upload_file': RateLimitConfig(
      maxRequests: 20,
      windowMinutes: 5,
      burstLimit: 3,
      penaltyMinutes: 15,
    ),
    'voice_call': RateLimitConfig(
      maxRequests: 10,
      windowMinutes: 5,
      burstLimit: 2,
      penaltyMinutes: 30,
    ),
    'anonymous_report': RateLimitConfig(
      maxRequests: 3,
      windowMinutes: 60,
      burstLimit: 1,
      penaltyMinutes: 120,
    ),
    'emergency_broadcast': RateLimitConfig(
      maxRequests: 2,
      windowMinutes: 60,
      burstLimit: 1,
      penaltyMinutes: 180,
    ),
    'login_attempt': RateLimitConfig(
      maxRequests: 5,
      windowMinutes: 60,
      burstLimit: 3,
      penaltyMinutes: 60,
    ),
    'registration_attempt': RateLimitConfig(
      maxRequests: 3,
      windowMinutes: 60,
      burstLimit: 1,
      penaltyMinutes: 120,
    ),
  };

  /// Check if action is allowed under rate limits
  Future<RateLimitResult> checkRateLimit({
    required String action,
    String? userId,
    String? ipAddress,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      final effectiveUserId = userId ?? currentUser?.uid ?? 'anonymous';
      
      final config = _rateLimitConfigs[action];
      if (config == null) {
        // No rate limit configured for this action
        return RateLimitResult(
          allowed: true,
          remainingRequests: 999,
          resetTime: DateTime.now().add(const Duration(minutes: 1)),
          action: action,
        );
      }

      // Check for existing penalty
      final penalty = await _checkActivePenalty(effectiveUserId, action);
      if (penalty != null) {
        await _logViolation(
          userId: effectiveUserId,
          action: action,
          violationType: ViolationType.penaltyActive,
          metadata: metadata,
        );
        
        return RateLimitResult(
          allowed: false,
          remainingRequests: 0,
          resetTime: penalty.expiresAt,
          action: action,
          penaltyActive: true,
          penaltyReason: penalty.reason,
        );
      }

      // Get or create rate limit tracker
      final trackerId = '${effectiveUserId}_$action';
      final tracker = _trackers[trackerId] ?? await _loadTracker(effectiveUserId, action, config);
      _trackers[trackerId] = tracker;

      // Check current window
      final now = DateTime.now();
      final windowStart = now.subtract(Duration(minutes: config.windowMinutes));
      
      // Clean old requests
      tracker.requests.removeWhere((timestamp) => timestamp.isBefore(windowStart));
      
      // Check burst limit (requests in last minute)
      final burstWindowStart = now.subtract(const Duration(minutes: 1));
      final recentRequests = tracker.requests.where((timestamp) => 
          timestamp.isAfter(burstWindowStart)).length;
      
      if (recentRequests >= config.burstLimit) {
        await _applyPenalty(
          userId: effectiveUserId,
          action: action,
          reason: 'Burst limit exceeded',
          penaltyMinutes: config.penaltyMinutes,
        );
        
        await _logViolation(
          userId: effectiveUserId,
          action: action,
          violationType: ViolationType.burstLimitExceeded,
          metadata: {
            'recentRequests': recentRequests,
            'burstLimit': config.burstLimit,
            ...?metadata,
          },
        );
        
        return RateLimitResult(
          allowed: false,
          remainingRequests: 0,
          resetTime: now.add(Duration(minutes: config.penaltyMinutes)),
          action: action,
          penaltyActive: true,
          penaltyReason: 'Burst limit exceeded',
        );
      }
      
      // Check window limit
      if (tracker.requests.length >= config.maxRequests) {
        await _applyPenalty(
          userId: effectiveUserId,
          action: action,
          reason: 'Rate limit exceeded',
          penaltyMinutes: config.penaltyMinutes,
        );
        
        await _logViolation(
          userId: effectiveUserId,
          action: action,
          violationType: ViolationType.rateLimitExceeded,
          metadata: {
            'requestsInWindow': tracker.requests.length,
            'maxRequests': config.maxRequests,
            ...?metadata,
          },
        );
        
        return RateLimitResult(
          allowed: false,
          remainingRequests: 0,
          resetTime: tracker.requests.first.add(Duration(minutes: config.windowMinutes)),
          action: action,
          penaltyActive: true,
          penaltyReason: 'Rate limit exceeded',
        );
      }
      
      // Action is allowed - record the request
      tracker.requests.add(now);
      await _saveTracker(effectiveUserId, action, tracker);
      
      final remainingRequests = config.maxRequests - tracker.requests.length;
      final resetTime = tracker.requests.first.add(Duration(minutes: config.windowMinutes));
      
      return RateLimitResult(
        allowed: true,
        remainingRequests: remainingRequests,
        resetTime: resetTime,
        action: action,
      );
    } catch (e) {
      debugPrint('Error checking rate limit: $e');
      // On error, allow the action but log the issue
      await _auditService.logSecurityEvent(
        eventType: 'rate_limit_check_error',
        userId: userId ?? 'unknown',
        details: {
          'action': action,
          'error': e.toString(),
        },
        sensitivityLevel: SensitivityLevel.medium,
      );
      
      return RateLimitResult(
        allowed: true,
        remainingRequests: 999,
        resetTime: DateTime.now().add(const Duration(minutes: 1)),
        action: action,
      );
    }
  }

  /// Record successful action (for tracking purposes)
  Future<void> recordAction({
    required String action,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      final effectiveUserId = userId ?? currentUser?.uid ?? 'anonymous';
      
      // Update action statistics
      await _firestore.collection('action_statistics').doc('${effectiveUserId}_$action').set({
        'userId': effectiveUserId,
        'action': action,
        'count': FieldValue.increment(1),
        'lastAction': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      }, SetOptions(merge: true));
      
    } catch (e) {
      debugPrint('Error recording action: $e');
    }
  }

  /// Get rate limit status for user
  Future<Map<String, RateLimitStatus>> getRateLimitStatus({String? userId}) async {
    try {
      final currentUser = AuthService.currentUser;
      final effectiveUserId = userId ?? currentUser?.uid ?? 'anonymous';
      
      final status = <String, RateLimitStatus>{};
      
      for (final entry in _rateLimitConfigs.entries) {
        final action = entry.key;
        final config = entry.value;
        
        // Check for active penalty
        final penalty = await _checkActivePenalty(effectiveUserId, action);
        if (penalty != null) {
          status[action] = RateLimitStatus(
            action: action,
            remainingRequests: 0,
            resetTime: penalty.expiresAt,
            penaltyActive: true,
            penaltyReason: penalty.reason,
          );
          continue;
        }
        
        // Get current tracker
        final trackerId = '${effectiveUserId}_$action';
        final tracker = _trackers[trackerId] ?? await _loadTracker(effectiveUserId, action, config);
        
        // Clean old requests
        final now = DateTime.now();
        final windowStart = now.subtract(Duration(minutes: config.windowMinutes));
        tracker.requests.removeWhere((timestamp) => timestamp.isBefore(windowStart));
        
        final remainingRequests = config.maxRequests - tracker.requests.length;
        final resetTime = tracker.requests.isNotEmpty 
            ? tracker.requests.first.add(Duration(minutes: config.windowMinutes))
            : now.add(Duration(minutes: config.windowMinutes));
        
        status[action] = RateLimitStatus(
          action: action,
          remainingRequests: remainingRequests,
          resetTime: resetTime,
          penaltyActive: false,
        );
      }
      
      return status;
    } catch (e) {
      debugPrint('Error getting rate limit status: $e');
      return {};
    }
  }

  /// Apply manual penalty (for admin use)
  Future<void> applyManualPenalty({
    required String userId,
    required String action,
    required String reason,
    required int penaltyMinutes,
    String? adminId,
  }) async {
    try {
      await _applyPenalty(
        userId: userId,
        action: action,
        reason: reason,
        penaltyMinutes: penaltyMinutes,
        isManual: true,
        adminId: adminId,
      );
      
      await _auditService.logSecurityEvent(
        eventType: 'manual_penalty_applied',
        userId: adminId ?? 'system',
        details: {
          'targetUserId': userId,
          'action': action,
          'reason': reason,
          'penaltyMinutes': penaltyMinutes,
        },
        sensitivityLevel: SensitivityLevel.high,
      );
      
    } catch (e) {
      debugPrint('Error applying manual penalty: $e');
      rethrow;
    }
  }

  /// Remove penalty (for admin use)
  Future<void> removePenalty({
    required String userId,
    required String action,
    String? adminId,
  }) async {
    try {
      await _firestore
          .collection('penalties')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: action)
          .where('isActive', isEqualTo: true)
          .get()
          .then((snapshot) async {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, {
            'isActive': false,
            'removedAt': FieldValue.serverTimestamp(),
            'removedBy': adminId,
          });
        }
        await batch.commit();
      });
      
      await _auditService.logSecurityEvent(
        eventType: 'penalty_removed',
        userId: adminId ?? 'system',
        details: {
          'targetUserId': userId,
          'action': action,
        },
        sensitivityLevel: SensitivityLevel.medium,
      );
      
    } catch (e) {
      debugPrint('Error removing penalty: $e');
      rethrow;
    }
  }

  /// Get rate limit violations for monitoring
  Future<List<RateLimitViolation>> getViolations({
    String? userId,
    String? action,
    DateTime? since,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection(_violationsCollection);
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      if (action != null) {
        query = query.where('action', isEqualTo: action);
      }
      
      if (since != null) {
        query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
      }
      
      query = query.orderBy('timestamp', descending: true).limit(limit);
      
      final snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return RateLimitViolation(
          id: doc.id,
          userId: data['userId'],
          action: data['action'],
          violationType: ViolationTypeExtension.fromString(data['violationType']),
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting violations: $e');
      return [];
    }
  }

  /// Clean up expired data
  Future<void> cleanupExpiredData() async {
    try {
      final now = Timestamp.now();
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)));
      
      // Clean up old rate limit trackers
      final oldTrackers = await _firestore
          .collection(_rateLimitsCollection)
          .where('lastUpdated', isLessThan: cutoff)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in oldTrackers.docs) {
        batch.delete(doc.reference);
      }
      
      // Clean up old violations
      final oldViolations = await _firestore
          .collection(_violationsCollection)
          .where('timestamp', isLessThan: cutoff)
          .get();
      
      for (final doc in oldViolations.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // Clean up in-memory cache
      _trackers.clear();
      
      debugPrint('Cleaned up ${oldTrackers.docs.length} old trackers and ${oldViolations.docs.length} old violations');
    } catch (e) {
      debugPrint('Error cleaning up expired data: $e');
    }
  }

  // Private helper methods

  Future<RateLimitTracker> _loadTracker(String userId, String action, RateLimitConfig config) async {
    try {
      final doc = await _firestore
          .collection(_rateLimitsCollection)
          .doc('${userId}_$action')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final requests = (data['requests'] as List<dynamic>)
            .map((timestamp) => (timestamp as Timestamp).toDate())
            .toList();
        
        return RateLimitTracker(
          userId: userId,
          action: action,
          requests: requests,
          lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
        );
      } else {
        return RateLimitTracker(
          userId: userId,
          action: action,
          requests: [],
          lastUpdated: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error loading tracker: $e');
      return RateLimitTracker(
        userId: userId,
        action: action,
        requests: [],
        lastUpdated: DateTime.now(),
      );
    }
  }

  Future<void> _saveTracker(String userId, String action, RateLimitTracker tracker) async {
    try {
      await _firestore
          .collection(_rateLimitsCollection)
          .doc('${userId}_$action')
          .set({
        'userId': userId,
        'action': action,
        'requests': tracker.requests.map((dt) => Timestamp.fromDate(dt)).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving tracker: $e');
    }
  }

  Future<RateLimitPenalty?> _checkActivePenalty(String userId, String action) async {
    try {
      final snapshot = await _firestore
          .collection('penalties')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: action)
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return RateLimitPenalty(
          id: snapshot.docs.first.id,
          userId: data['userId'],
          action: data['action'],
          reason: data['reason'],
          expiresAt: (data['expiresAt'] as Timestamp).toDate(),
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          isManual: data['isManual'] ?? false,
        );
      }
      
      return null;
    } catch (e) {
      debugPrint('Error checking penalty: $e');
      return null;
    }
  }

  Future<void> _applyPenalty({
    required String userId,
    required String action,
    required String reason,
    required int penaltyMinutes,
    bool isManual = false,
    String? adminId,
  }) async {
    try {
      final expiresAt = DateTime.now().add(Duration(minutes: penaltyMinutes));
      
      await _firestore.collection('penalties').add({
        'userId': userId,
        'action': action,
        'reason': reason,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isManual': isManual,
        'adminId': adminId,
        'penaltyMinutes': penaltyMinutes,
      });
      
      // Clear tracker to reset rate limit
      final trackerId = '${userId}_$action';
      _trackers.remove(trackerId);
      
    } catch (e) {
      debugPrint('Error applying penalty: $e');
      rethrow;
    }
  }

  Future<void> _logViolation({
    required String userId,
    required String action,
    required ViolationType violationType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection(_violationsCollection).add({
        'userId': userId,
        'action': action,
        'violationType': violationType.value,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      });
    } catch (e) {
      debugPrint('Error logging violation: $e');
    }
  }
}

// Data models for rate limiting

class RateLimitConfig {
  final int maxRequests;
  final int windowMinutes;
  final int burstLimit;
  final int penaltyMinutes;

  const RateLimitConfig({
    required this.maxRequests,
    required this.windowMinutes,
    required this.burstLimit,
    required this.penaltyMinutes,
  });
}

class RateLimitTracker {
  final String userId;
  final String action;
  final List<DateTime> requests;
  final DateTime lastUpdated;

  RateLimitTracker({
    required this.userId,
    required this.action,
    required this.requests,
    required this.lastUpdated,
  });
}

class RateLimitResult {
  final bool allowed;
  final int remainingRequests;
  final DateTime resetTime;
  final String action;
  final bool penaltyActive;
  final String? penaltyReason;

  RateLimitResult({
    required this.allowed,
    required this.remainingRequests,
    required this.resetTime,
    required this.action,
    this.penaltyActive = false,
    this.penaltyReason,
  });
}

class RateLimitStatus {
  final String action;
  final int remainingRequests;
  final DateTime resetTime;
  final bool penaltyActive;
  final String? penaltyReason;

  RateLimitStatus({
    required this.action,
    required this.remainingRequests,
    required this.resetTime,
    required this.penaltyActive,
    this.penaltyReason,
  });
}

class RateLimitPenalty {
  final String id;
  final String userId;
  final String action;
  final String reason;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool isManual;

  RateLimitPenalty({
    required this.id,
    required this.userId,
    required this.action,
    required this.reason,
    required this.expiresAt,
    required this.createdAt,
    required this.isManual,
  });
}

class RateLimitViolation {
  final String id;
  final String userId;
  final String action;
  final ViolationType violationType;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  RateLimitViolation({
    required this.id,
    required this.userId,
    required this.action,
    required this.violationType,
    required this.timestamp,
    required this.metadata,
  });
}

enum ViolationType {
  rateLimitExceeded,
  burstLimitExceeded,
  penaltyActive,
}

extension ViolationTypeExtension on ViolationType {
  String get value {
    switch (this) {
      case ViolationType.rateLimitExceeded:
        return 'rate_limit_exceeded';
      case ViolationType.burstLimitExceeded:
        return 'burst_limit_exceeded';
      case ViolationType.penaltyActive:
        return 'penalty_active';
    }
  }

  static ViolationType fromString(String value) {
    switch (value) {
      case 'burst_limit_exceeded':
        return ViolationType.burstLimitExceeded;
      case 'penalty_active':
        return ViolationType.penaltyActive;
      default:
        return ViolationType.rateLimitExceeded;
    }
  }
}