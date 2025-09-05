// Community Guidelines Service for TALOWA
// Implements Task 19: Build user safety features - Community Guidelines

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CommunityGuidelinesService {
  static final CommunityGuidelinesService _instance = CommunityGuidelinesService._internal();
  factory CommunityGuidelinesService() => _instance;
  CommunityGuidelinesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get community guidelines
  Future<List<CommunityGuideline>> getCommunityGuidelines() async {
    try {
      final snapshot = await _firestore
          .collection('community_guidelines')
          .orderBy('priority', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CommunityGuideline.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting community guidelines: $e');
      return _getDefaultGuidelines();
    }
  }

  /// Check content against community guidelines
  Future<GuidelineViolationResult> checkContentCompliance({
    required String content,
    required String contentType,
    String? authorId,
  }) async {
    try {
      final violations = <GuidelineViolation>[];
      final guidelines = await getCommunityGuidelines();

      for (final guideline in guidelines) {
        final violation = await _checkGuidelineViolation(
          content: content,
          contentType: contentType,
          guideline: guideline,
          authorId: authorId,
        );
        
        if (violation != null) {
          violations.add(violation);
        }
      }

      final severity = _calculateOverallSeverity(violations);
      
      return GuidelineViolationResult(
        isCompliant: violations.isEmpty,
        violations: violations,
        overallSeverity: severity,
        recommendedAction: _getRecommendedAction(severity, violations),
        requiresReview: severity == ViolationSeverity.severe || 
                       severity == ViolationSeverity.critical,
      );
    } catch (e) {
      debugPrint('Error checking content compliance: $e');
      return GuidelineViolationResult(
        isCompliant: false,
        violations: [],
        overallSeverity: ViolationSeverity.unknown,
        recommendedAction: GuidelineAction.manualReview,
        requiresReview: true,
      );
    }
  }

  /// Report a guideline violation
  Future<String> reportGuidelineViolation({
    required String contentId,
    required String reporterId,
    required String guidelineId,
    required String violationType,
    String? description,
    List<String>? evidenceUrls,
  }) async {
    try {
      final reportRef = await _firestore.collection('guideline_violations').add({
        'contentId': contentId,
        'reporterId': reporterId,
        'guidelineId': guidelineId,
        'violationType': violationType,
        'description': description,
        'evidenceUrls': evidenceUrls ?? [],
        'status': 'pending',
        'severity': 'medium',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
        'resolution': null,
      });

      // Update guideline violation statistics
      await _updateViolationStats(guidelineId, violationType);

      return reportRef.id;
    } catch (e) {
      debugPrint('Error reporting guideline violation: $e');
      rethrow;
    }
  }

  /// Get user's guideline violation history
  Future<List<UserViolation>> getUserViolationHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_violations')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return UserViolation.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting user violation history: $e');
      return [];
    }
  }

  /// Apply guideline enforcement action
  Future<void> enforceGuidelineAction({
    required String userId,
    required String contentId,
    required GuidelineAction action,
    required String reason,
    String? moderatorId,
    Duration? duration,
  }) async {
    try {
      // Record the enforcement action
      await _firestore.collection('guideline_enforcements').add({
        'userId': userId,
        'contentId': contentId,
        'action': action.toString(),
        'reason': reason,
        'moderatorId': moderatorId ?? 'system',
        'duration': duration?.inMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': duration != null 
            ? Timestamp.fromDate(DateTime.now().add(duration))
            : null,
        'isActive': true,
      });

      // Apply the action
      switch (action) {
        case GuidelineAction.warning:
          await _issueWarning(userId, reason);
          break;
        case GuidelineAction.contentRemoval:
          await _removeContent(contentId, reason);
          break;
        case GuidelineAction.temporaryRestriction:
          await _applyTemporaryRestriction(userId, duration ?? const Duration(days: 1), reason);
          break;
        case GuidelineAction.accountSuspension:
          await _suspendAccount(userId, duration ?? const Duration(days: 7), reason);
          break;
        case GuidelineAction.permanentBan:
          await _permanentBan(userId, reason);
          break;
        case GuidelineAction.manualReview:
          await _flagForManualReview(contentId, userId, reason);
          break;
        case GuidelineAction.noAction:
          // No action needed
          break;
      }

      // Update user violation record
      await _updateUserViolationRecord(userId, action, reason);
    } catch (e) {
      debugPrint('Error enforcing guideline action: $e');
      rethrow;
    }
  }

  /// Get guideline enforcement statistics
  Future<GuidelineStats> getGuidelineStats() async {
    try {
      // Get total violations
      final violationsSnapshot = await _firestore
          .collection('guideline_violations')
          .get();

      // Get pending reviews
      final pendingSnapshot = await _firestore
          .collection('guideline_violations')
          .where('status', isEqualTo: 'pending')
          .get();

      // Get enforcement actions
      final enforcementsSnapshot = await _firestore
          .collection('guideline_enforcements')
          .get();

      // Get active restrictions
      final activeRestrictionsSnapshot = await _firestore
          .collection('guideline_enforcements')
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();

      return GuidelineStats(
        totalViolations: violationsSnapshot.docs.length,
        pendingReviews: pendingSnapshot.docs.length,
        totalEnforcements: enforcementsSnapshot.docs.length,
        activeRestrictions: activeRestrictionsSnapshot.docs.length,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting guideline stats: $e');
      return GuidelineStats(
        totalViolations: 0,
        pendingReviews: 0,
        totalEnforcements: 0,
        activeRestrictions: 0,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Check if user has active restrictions
  Future<List<ActiveRestriction>> getUserActiveRestrictions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('guideline_enforcements')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ActiveRestriction.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting user active restrictions: $e');
      return [];
    }
  }

  // Private helper methods

  List<CommunityGuideline> _getDefaultGuidelines() {
    return [
      CommunityGuideline(
        id: 'respect',
        title: 'Respect Others',
        description: 'Treat all community members with respect and dignity',
        category: GuidelineCategory.behavior,
        priority: 10,
        keywords: ['respect', 'dignity', 'harassment', 'bullying'],
        violationTypes: ['harassment', 'bullying', 'personal_attacks'],
        severity: ViolationSeverity.moderate,
      ),
      CommunityGuideline(
        id: 'no_hate_speech',
        title: 'No Hate Speech',
        description: 'Do not post content that attacks people based on identity',
        category: GuidelineCategory.content,
        priority: 9,
        keywords: ['hate', 'discrimination', 'slur', 'racist'],
        violationTypes: ['hate_speech', 'discrimination'],
        severity: ViolationSeverity.severe,
      ),
      CommunityGuideline(
        id: 'no_violence',
        title: 'No Violence or Threats',
        description: 'Do not threaten or promote violence against anyone',
        category: GuidelineCategory.safety,
        priority: 10,
        keywords: ['kill', 'hurt', 'violence', 'threat', 'harm'],
        violationTypes: ['threats', 'violence', 'self_harm'],
        severity: ViolationSeverity.critical,
      ),
      CommunityGuideline(
        id: 'authentic_identity',
        title: 'Authentic Identity',
        description: 'Use your real identity and do not impersonate others',
        category: GuidelineCategory.identity,
        priority: 7,
        keywords: ['fake', 'impersonate', 'identity', 'authentic'],
        violationTypes: ['impersonation', 'fake_identity'],
        severity: ViolationSeverity.moderate,
      ),
      CommunityGuideline(
        id: 'no_spam',
        title: 'No Spam or Scams',
        description: 'Do not post repetitive content or attempt to scam others',
        category: GuidelineCategory.content,
        priority: 6,
        keywords: ['spam', 'scam', 'repetitive', 'promotional'],
        violationTypes: ['spam', 'scam', 'excessive_posting'],
        severity: ViolationSeverity.minor,
      ),
    ];
  }

  Future<GuidelineViolation?> _checkGuidelineViolation({
    required String content,
    required String contentType,
    required CommunityGuideline guideline,
    String? authorId,
  }) async {
    final lowerContent = content.toLowerCase();
    
    // Check for keyword violations
    for (final keyword in guideline.keywords) {
      if (lowerContent.contains(keyword.toLowerCase())) {
        return GuidelineViolation(
          guidelineId: guideline.id,
          guidelineTitle: guideline.title,
          violationType: guideline.violationTypes.first,
          severity: guideline.severity,
          detectedKeywords: [keyword],
          confidence: 0.8,
          description: 'Content contains prohibited keyword: $keyword',
        );
      }
    }

    // Additional context-specific checks
    if (guideline.id == 'no_violence') {
      final violenceScore = _calculateViolenceScore(content);
      if (violenceScore > 0.7) {
        return GuidelineViolation(
          guidelineId: guideline.id,
          guidelineTitle: guideline.title,
          violationType: 'violence',
          severity: ViolationSeverity.critical,
          detectedKeywords: [],
          confidence: violenceScore,
          description: 'Content contains violent language or threats',
        );
      }
    }

    return null;
  }

  double _calculateViolenceScore(String content) {
    final violenceKeywords = [
      'kill', 'murder', 'hurt', 'harm', 'attack', 'destroy', 'beat',
      'fight', 'punch', 'kick', 'shoot', 'stab', 'cut', 'burn'
    ];
    
    final lowerContent = content.toLowerCase();
    int matches = 0;
    
    for (final keyword in violenceKeywords) {
      if (lowerContent.contains(keyword)) {
        matches++;
      }
    }
    
    return matches / violenceKeywords.length;
  }

  ViolationSeverity _calculateOverallSeverity(List<GuidelineViolation> violations) {
    if (violations.isEmpty) return ViolationSeverity.none;
    
    var maxSeverity = ViolationSeverity.minor;
    for (final violation in violations) {
      if (violation.severity.index > maxSeverity.index) {
        maxSeverity = violation.severity;
      }
    }
    
    return maxSeverity;
  }

  GuidelineAction _getRecommendedAction(
    ViolationSeverity severity,
    List<GuidelineViolation> violations,
  ) {
    switch (severity) {
      case ViolationSeverity.none:
        return GuidelineAction.noAction;
      case ViolationSeverity.minor:
        return GuidelineAction.warning;
      case ViolationSeverity.moderate:
        return GuidelineAction.contentRemoval;
      case ViolationSeverity.severe:
        return GuidelineAction.temporaryRestriction;
      case ViolationSeverity.critical:
        return GuidelineAction.accountSuspension;
      case ViolationSeverity.unknown:
        return GuidelineAction.manualReview;
    }
  }

  Future<void> _updateViolationStats(String guidelineId, String violationType) async {
    try {
      await _firestore.collection('guideline_stats').doc(guidelineId).set({
        'guidelineId': guidelineId,
        'totalViolations': FieldValue.increment(1),
        'violationTypes.$violationType': FieldValue.increment(1),
        'lastViolation': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating violation stats: $e');
    }
  }

  Future<void> _issueWarning(String userId, String reason) async {
    await _firestore.collection('user_warnings').add({
      'userId': userId,
      'reason': reason,
      'issuedAt': FieldValue.serverTimestamp(),
      'acknowledged': false,
    });
  }

  Future<void> _removeContent(String contentId, String reason) async {
    await _firestore.collection('posts').doc(contentId).update({
      'isRemoved': true,
      'removalReason': reason,
      'removedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _applyTemporaryRestriction(String userId, Duration duration, String reason) async {
    await _firestore.collection('user_restrictions').add({
      'userId': userId,
      'type': 'temporary_restriction',
      'reason': reason,
      'startedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(duration)),
      'isActive': true,
    });
  }

  Future<void> _suspendAccount(String userId, Duration duration, String reason) async {
    await _firestore.collection('users').doc(userId).update({
      'isSuspended': true,
      'suspensionReason': reason,
      'suspendedAt': FieldValue.serverTimestamp(),
      'suspensionExpiresAt': Timestamp.fromDate(DateTime.now().add(duration)),
    });
  }

  Future<void> _permanentBan(String userId, String reason) async {
    await _firestore.collection('users').doc(userId).update({
      'isBanned': true,
      'banReason': reason,
      'bannedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _flagForManualReview(String contentId, String userId, String reason) async {
    await _firestore.collection('manual_reviews').add({
      'contentId': contentId,
      'userId': userId,
      'reason': reason,
      'status': 'pending',
      'flaggedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateUserViolationRecord(String userId, GuidelineAction action, String reason) async {
    await _firestore.collection('user_violations').add({
      'userId': userId,
      'action': action.toString(),
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

// Data models for community guidelines

enum GuidelineCategory {
  behavior,
  content,
  safety,
  identity,
  privacy,
}

enum ViolationSeverity {
  none,
  minor,
  moderate,
  severe,
  critical,
  unknown,
}

enum GuidelineAction {
  noAction,
  warning,
  contentRemoval,
  temporaryRestriction,
  accountSuspension,
  permanentBan,
  manualReview,
}

class CommunityGuideline {
  final String id;
  final String title;
  final String description;
  final GuidelineCategory category;
  final int priority;
  final List<String> keywords;
  final List<String> violationTypes;
  final ViolationSeverity severity;

  CommunityGuideline({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.keywords,
    required this.violationTypes,
    required this.severity,
  });

  factory CommunityGuideline.fromMap(Map<String, dynamic> map) {
    return CommunityGuideline(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: GuidelineCategory.values.firstWhere(
        (e) => e.toString() == 'GuidelineCategory.${map['category']}',
        orElse: () => GuidelineCategory.behavior,
      ),
      priority: map['priority'] ?? 0,
      keywords: List<String>.from(map['keywords'] ?? []),
      violationTypes: List<String>.from(map['violationTypes'] ?? []),
      severity: ViolationSeverity.values.firstWhere(
        (e) => e.toString() == 'ViolationSeverity.${map['severity']}',
        orElse: () => ViolationSeverity.minor,
      ),
    );
  }
}

class GuidelineViolation {
  final String guidelineId;
  final String guidelineTitle;
  final String violationType;
  final ViolationSeverity severity;
  final List<String> detectedKeywords;
  final double confidence;
  final String description;

  GuidelineViolation({
    required this.guidelineId,
    required this.guidelineTitle,
    required this.violationType,
    required this.severity,
    required this.detectedKeywords,
    required this.confidence,
    required this.description,
  });
}

class GuidelineViolationResult {
  final bool isCompliant;
  final List<GuidelineViolation> violations;
  final ViolationSeverity overallSeverity;
  final GuidelineAction recommendedAction;
  final bool requiresReview;

  GuidelineViolationResult({
    required this.isCompliant,
    required this.violations,
    required this.overallSeverity,
    required this.recommendedAction,
    required this.requiresReview,
  });
}

class UserViolation {
  final String userId;
  final String action;
  final String reason;
  final DateTime createdAt;

  UserViolation({
    required this.userId,
    required this.action,
    required this.reason,
    required this.createdAt,
  });

  factory UserViolation.fromMap(Map<String, dynamic> map) {
    return UserViolation(
      userId: map['userId'] ?? '',
      action: map['action'] ?? '',
      reason: map['reason'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class ActiveRestriction {
  final String userId;
  final String action;
  final String reason;
  final DateTime createdAt;
  final DateTime? expiresAt;

  ActiveRestriction({
    required this.userId,
    required this.action,
    required this.reason,
    required this.createdAt,
    this.expiresAt,
  });

  factory ActiveRestriction.fromMap(Map<String, dynamic> map) {
    return ActiveRestriction(
      userId: map['userId'] ?? '',
      action: map['action'] ?? '',
      reason: map['reason'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: map['expiresAt'] != null 
          ? (map['expiresAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class GuidelineStats {
  final int totalViolations;
  final int pendingReviews;
  final int totalEnforcements;
  final int activeRestrictions;
  final DateTime lastUpdated;

  GuidelineStats({
    required this.totalViolations,
    required this.pendingReviews,
    required this.totalEnforcements,
    required this.activeRestrictions,
    required this.lastUpdated,
  });
}
