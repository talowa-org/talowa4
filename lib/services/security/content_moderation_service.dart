// Content Moderation Service for TALOWA
// Implements Task 18: Add security and content safety - Content Moderation

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

class ContentModerationService {
  static final ContentModerationService _instance = ContentModerationService._internal();
  factory ContentModerationService() => _instance;
  ContentModerationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Inappropriate content keywords in multiple languages
  final Map<String, List<String>> _inappropriateKeywords = {
    'english': [
      'hate', 'kill', 'murder', 'terrorist', 'bomb', 'weapon', 'drug',
      'violence', 'abuse', 'harassment', 'threat', 'suicide', 'self-harm',
      'scam', 'fraud', 'fake', 'spam', 'adult', 'porn', 'sex', 'nude'
    ],
    'telugu': [
      'చంపు', 'కొట్టు', 'హింస', 'దాడి', 'బాంబు', 'ఆయుధం', 'మత్తుపదార్థం',
      'మోసం', 'నకిలీ', 'స్పామ్', 'అసభ్య', 'వేధింపు', 'బెదిరింపు'
    ],
    'hindi': [
      'मार', 'हिंसा', 'हमला', 'बम', 'हथियार', 'नशा', 'धोखा',
      'नकली', 'स्पैम', 'अश्लील', 'परेशान', 'धमकी', 'आत्महत्या'
    ]
  };

  /// Analyze content for inappropriate material
  Future<ContentModerationResult> analyzeContent({
    required String content,
    required String contentType,
    String? authorId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final analysis = ContentModerationResult(
        contentId: _generateContentId(content),
        isAppropriate: true,
        confidenceScore: 1.0,
        flaggedReasons: [],
        suggestedActions: [],
        requiresHumanReview: false,
        detectedLanguage: _detectLanguage(content),
      );

      // Text content analysis
      if (contentType == 'text' || contentType == 'post') {
        await _analyzeTextContent(content, analysis);
      }

      // Image content analysis (placeholder for future ML integration)
      if (contentType == 'image') {
        await _analyzeImageContent(metadata, analysis);
      }

      // Video content analysis (placeholder)
      if (contentType == 'video') {
        await _analyzeVideoContent(metadata, analysis);
      }

      // Check author reputation if provided
      if (authorId != null) {
        await _checkAuthorReputation(authorId, analysis);
      }

      // Log moderation result
      await _logModerationResult(analysis);

      return analysis;
    } catch (e) {
      debugPrint('Error analyzing content: $e');
      return ContentModerationResult(
        contentId: _generateContentId(content),
        isAppropriate: false,
        confidenceScore: 0.0,
        flaggedReasons: ['analysis_error'],
        suggestedActions: ['manual_review'],
        requiresHumanReview: true,
        detectedLanguage: 'unknown',
      );
    }
  }

  /// Report content for manual review
  Future<String> reportContent({
    required String contentId,
    required String reporterId,
    required ContentReportReason reason,
    String? description,
    List<String>? evidenceUrls,
  }) async {
    try {
      final reportRef = await _firestore.collection('content_reports').add({
        'contentId': contentId,
        'reporterId': reporterId,
        'reason': reason.toString(),
        'description': description,
        'evidenceUrls': evidenceUrls ?? [],
        'status': 'pending',
        'priority': _calculateReportPriority(reason),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
        'resolution': null,
      });

      // Update content with report flag
      await _flagContent(contentId, 'user_reported');

      // Check if content should be auto-hidden
      await _checkAutoHideContent(contentId);

      await _logModerationAction(
        actionType: 'content_reported',
        actorId: reporterId,
        targetId: contentId,
        details: {
          'reason': reason.toString(),
          'reportId': reportRef.id,
        },
      );

      return reportRef.id;
    } catch (e) {
      debugPrint('Error reporting content: $e');
      rethrow;
    }
  }

  /// Hide content from public view
  Future<void> hideContent({
    required String contentId,
    required String reason,
    String? moderatorId,
    bool permanent = false,
  }) async {
    try {
      await _firestore.collection('posts').doc(contentId).update({
        'isHidden': true,
        'hiddenReason': reason,
        'hiddenBy': moderatorId ?? 'system',
        'hiddenAt': FieldValue.serverTimestamp(),
        'isPermanentlyHidden': permanent,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logModerationAction(
        actionType: 'content_hidden',
        actorId: moderatorId ?? 'system',
        targetId: contentId,
        details: {
          'reason': reason,
          'permanent': permanent,
        },
      );
    } catch (e) {
      debugPrint('Error hiding content: $e');
      rethrow;
    }
  }

  /// Restore hidden content
  Future<void> restoreContent({
    required String contentId,
    String? moderatorId,
    String? reason,
  }) async {
    try {
      await _firestore.collection('posts').doc(contentId).update({
        'isHidden': false,
        'hiddenReason': null,
        'hiddenBy': null,
        'hiddenAt': null,
        'isPermanentlyHidden': false,
        'restoredBy': moderatorId ?? 'system',
        'restoredAt': FieldValue.serverTimestamp(),
        'restorationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logModerationAction(
        actionType: 'content_restored',
        actorId: moderatorId ?? 'system',
        targetId: contentId,
        details: {
          'reason': reason,
        },
      );
    } catch (e) {
      debugPrint('Error restoring content: $e');
      rethrow;
    }
  }

  /// Get content moderation queue for moderators
  Future<List<ContentModerationItem>> getModerationQueue({
    String status = 'pending',
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('content_reports')
          .where('status', isEqualTo: status)
          .orderBy('priority', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final items = <ContentModerationItem>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final contentId = data['contentId'] as String;
        
        // Get the actual content
        final contentDoc = await _firestore.collection('posts').doc(contentId).get();
        if (contentDoc.exists) {
          final contentData = contentDoc.data()!;
          items.add(ContentModerationItem(
            reportId: doc.id,
            contentId: contentId,
            content: contentData['content'] ?? '',
            contentType: contentData['type'] ?? 'text',
            authorId: contentData['authorId'] ?? '',
            reporterId: data['reporterId'] ?? '',
            reason: data['reason'] ?? '',
            description: data['description'],
            priority: data['priority'] ?? 1,
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            evidenceUrls: List<String>.from(data['evidenceUrls'] ?? []),
          ));
        }
      }

      return items;
    } catch (e) {
      debugPrint('Error getting moderation queue: $e');
      return [];
    }
  }

  /// Filter content based on safety settings
  Future<List<T>> filterContent<T>({
    required List<T> content,
    required String userId,
    required T Function(Map<String, dynamic>) fromMap,
    required Map<String, dynamic> Function(T) toMap,
  }) async {
    try {
      final safeContent = <T>[];
      final userPrefs = await _getUserContentPreferences(userId);
      
      for (final item in content) {
        final itemMap = toMap(item);
        
        // Skip hidden content
        if (itemMap['isHidden'] == true) {
          continue;
        }
        
        // Check content warnings
        final hasWarning = itemMap['hasContentWarning'] == true;
        if (hasWarning && !userPrefs.showSensitiveContent) {
          continue;
        }
        
        // Check content rating
        final contentRating = itemMap['contentRating'] as String? ?? 'general';
        if (!userPrefs.allowedRatings.contains(contentRating)) {
          continue;
        }
        
        safeContent.add(item);
      }
      
      return safeContent;
    } catch (e) {
      debugPrint('Error filtering content: $e');
      return content;
    }
  }

  /// Get content safety statistics
  Future<ContentSafetyStats> getContentSafetyStats() async {
    try {
      // Get total reports
      final reportsSnapshot = await _firestore.collection('content_reports').get();
      
      // Get pending reports
      final pendingSnapshot = await _firestore
          .collection('content_reports')
          .where('status', isEqualTo: 'pending')
          .get();
      
      // Get hidden content
      final hiddenSnapshot = await _firestore
          .collection('posts')
          .where('isHidden', isEqualTo: true)
          .get();
      
      // Get flagged content
      final flaggedSnapshot = await _firestore
          .collection('posts')
          .where('isFlagged', isEqualTo: true)
          .get();
      
      return ContentSafetyStats(
        totalReports: reportsSnapshot.docs.length,
        pendingReports: pendingSnapshot.docs.length,
        hiddenContent: hiddenSnapshot.docs.length,
        flaggedContent: flaggedSnapshot.docs.length,
        averageResponseTime: await _calculateAverageResponseTime(),
      );
    } catch (e) {
      debugPrint('Error getting content safety stats: $e');
      return ContentSafetyStats(
        totalReports: 0,
        pendingReports: 0,
        hiddenContent: 0,
        flaggedContent: 0,
        averageResponseTime: Duration.zero,
      );
    }
  }

  // Private helper methods

  Future<void> _analyzeTextContent(String content, ContentModerationResult analysis) async {
    final lowerContent = content.toLowerCase();
    
    // Check for inappropriate keywords
    for (final language in _inappropriateKeywords.keys) {
      final keywords = _inappropriateKeywords[language]!;
      for (final keyword in keywords) {
        if (lowerContent.contains(keyword.toLowerCase())) {
          analysis.isAppropriate = false;
          analysis.flaggedReasons.add('inappropriate_language');
          analysis.confidenceScore = 0.8;
          analysis.suggestedActions.add('hide_content');
          break;
        }
      }
    }
    
    // Check for spam patterns
    if (_isSpamContent(content)) {
      analysis.isAppropriate = false;
      analysis.flaggedReasons.add('spam');
      analysis.suggestedActions.add('hide_content');
    }
    
    // Check for excessive capitalization
    if (_hasExcessiveCaps(content)) {
      analysis.flaggedReasons.add('excessive_caps');
      analysis.suggestedActions.add('add_warning');
    }
    
    // Check for personal information
    if (_containsPersonalInfo(content)) {
      analysis.flaggedReasons.add('personal_information');
      analysis.suggestedActions.add('add_warning');
      analysis.requiresHumanReview = true;
    }
  }

  Future<void> _analyzeImageContent(Map<String, dynamic>? metadata, ContentModerationResult analysis) async {
    // Placeholder for image analysis
    // In a real implementation, this would use ML services like Google Vision API
    if (metadata != null) {
      final fileSize = metadata['fileSize'] as int? ?? 0;
      if (fileSize > 10 * 1024 * 1024) { // 10MB limit
        analysis.flaggedReasons.add('file_too_large');
        analysis.suggestedActions.add('compress_image');
      }
    }
  }

  Future<void> _analyzeVideoContent(Map<String, dynamic>? metadata, ContentModerationResult analysis) async {
    // Placeholder for video analysis
    if (metadata != null) {
      final duration = metadata['duration'] as int? ?? 0;
      if (duration > 300) { // 5 minutes limit
        analysis.flaggedReasons.add('video_too_long');
        analysis.suggestedActions.add('trim_video');
      }
    }
  }

  Future<void> _checkAuthorReputation(String authorId, ContentModerationResult analysis) async {
    try {
      final userDoc = await _firestore.collection('users').doc(authorId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final reportCount = userData['reportCount'] as int? ?? 0;
        final isFlagged = userData['isFlagged'] as bool? ?? false;
        
        if (reportCount > 5 || isFlagged) {
          analysis.requiresHumanReview = true;
          analysis.flaggedReasons.add('author_reputation');
          analysis.confidenceScore *= 0.7;
        }
      }
    } catch (e) {
      debugPrint('Error checking author reputation: $e');
    }
  }

  String _detectLanguage(String content) {
    // Simple language detection based on character patterns
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(content)) {
      return 'telugu';
    } else if (RegExp(r'[\u0900-\u097F]').hasMatch(content)) {
      return 'hindi';
    } else {
      return 'english';
    }
  }

  bool _isSpamContent(String content) {
    // Check for spam patterns
    final spamPatterns = [
      RegExp(r'(click here|visit now|buy now|limited time)', caseSensitive: false),
      RegExp(r'(www\.|http|\.com|\.org)', caseSensitive: false),
      RegExp(r'(\d{10,}|\+\d{2,3}\s?\d{10})', caseSensitive: false), // Phone numbers
    ];
    
    for (final pattern in spamPatterns) {
      if (pattern.hasMatch(content)) {
        return true;
      }
    }
    
    // Check for repetitive content
    final words = content.split(' ');
    final uniqueWords = words.toSet();
    if (words.length > 10 && uniqueWords.length < words.length * 0.3) {
      return true;
    }
    
    return false;
  }

  bool _hasExcessiveCaps(String content) {
    if (content.length < 10) return false;
    
    final capsCount = content.replaceAll(RegExp(r'[^A-Z]'), '').length;
    return capsCount > content.length * 0.7;
  }

  bool _containsPersonalInfo(String content) {
    final personalInfoPatterns = [
      RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\b'), // Credit card
      RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), // SSN pattern
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), // Email
    ];
    
    for (final pattern in personalInfoPatterns) {
      if (pattern.hasMatch(content)) {
        return true;
      }
    }
    
    return false;
  }

  String _generateContentId(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  int _calculateReportPriority(ContentReportReason reason) {
    switch (reason) {
      case ContentReportReason.threats:
      case ContentReportReason.violence:
        return 5; // Highest priority
      case ContentReportReason.harassment:
      case ContentReportReason.hateSpeech:
        return 4;
      case ContentReportReason.inappropriateContent:
      case ContentReportReason.spam:
        return 3;
      case ContentReportReason.misinformation:
        return 2;
      case ContentReportReason.other:
        return 1; // Lowest priority
    }
  }

  Future<void> _flagContent(String contentId, String reason) async {
    try {
      await _firestore.collection('posts').doc(contentId).update({
        'isFlagged': true,
        'flaggedReason': reason,
        'flaggedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error flagging content: $e');
    }
  }

  Future<void> _checkAutoHideContent(String contentId) async {
    try {
      // Get report count for this content
      final reportsSnapshot = await _firestore
          .collection('content_reports')
          .where('contentId', isEqualTo: contentId)
          .get();
      
      // Auto-hide if multiple reports
      if (reportsSnapshot.docs.length >= 3) {
        await hideContent(
          contentId: contentId,
          reason: 'Multiple user reports',
        );
      }
    } catch (e) {
      debugPrint('Error checking auto hide: $e');
    }
  }

  Future<UserContentPreferences> _getUserContentPreferences(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_content_preferences')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return UserContentPreferences.fromMap(doc.data()!);
      } else {
        return UserContentPreferences.defaultPreferences();
      }
    } catch (e) {
      debugPrint('Error getting user content preferences: $e');
      return UserContentPreferences.defaultPreferences();
    }
  }

  Future<Duration> _calculateAverageResponseTime() async {
    try {
      final resolvedReports = await _firestore
          .collection('content_reports')
          .where('status', isEqualTo: 'resolved')
          .limit(100)
          .get();
      
      if (resolvedReports.docs.isEmpty) return Duration.zero;
      
      int totalMinutes = 0;
      for (final doc in resolvedReports.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
        
        if (reviewedAt != null) {
          final diff = reviewedAt.difference(createdAt);
          totalMinutes += diff.inMinutes;
        }
      }
      
      final averageMinutes = totalMinutes / resolvedReports.docs.length;
      return Duration(minutes: averageMinutes.round());
    } catch (e) {
      debugPrint('Error calculating average response time: $e');
      return Duration.zero;
    }
  }

  Future<void> _logModerationResult(ContentModerationResult result) async {
    try {
      await _firestore.collection('moderation_logs').add({
        'contentId': result.contentId,
        'isAppropriate': result.isAppropriate,
        'confidenceScore': result.confidenceScore,
        'flaggedReasons': result.flaggedReasons,
        'suggestedActions': result.suggestedActions,
        'requiresHumanReview': result.requiresHumanReview,
        'detectedLanguage': result.detectedLanguage,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging moderation result: $e');
    }
  }

  Future<void> _logModerationAction({
    required String actionType,
    required String actorId,
    required String targetId,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _firestore.collection('moderation_actions').add({
        'actionType': actionType,
        'actorId': actorId,
        'targetId': targetId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging moderation action: $e');
    }
  }
}

// Data models for content moderation

enum ContentReportReason {
  spam,
  harassment,
  inappropriateContent,
  violence,
  threats,
  hateSpeech,
  misinformation,
  other,
}

class ContentModerationResult {
  final String contentId;
  bool isAppropriate;
  double confidenceScore;
  final List<String> flaggedReasons;
  final List<String> suggestedActions;
  bool requiresHumanReview;
  final String detectedLanguage;

  ContentModerationResult({
    required this.contentId,
    required this.isAppropriate,
    required this.confidenceScore,
    required this.flaggedReasons,
    required this.suggestedActions,
    required this.requiresHumanReview,
    required this.detectedLanguage,
  });
}

class ContentModerationItem {
  final String reportId;
  final String contentId;
  final String content;
  final String contentType;
  final String authorId;
  final String reporterId;
  final String reason;
  final String? description;
  final int priority;
  final DateTime createdAt;
  final List<String> evidenceUrls;

  ContentModerationItem({
    required this.reportId,
    required this.contentId,
    required this.content,
    required this.contentType,
    required this.authorId,
    required this.reporterId,
    required this.reason,
    this.description,
    required this.priority,
    required this.createdAt,
    required this.evidenceUrls,
  });
}

class UserContentPreferences {
  final bool showSensitiveContent;
  final List<String> allowedRatings;
  final bool autoHideReportedContent;
  final bool requireContentWarnings;

  UserContentPreferences({
    required this.showSensitiveContent,
    required this.allowedRatings,
    required this.autoHideReportedContent,
    required this.requireContentWarnings,
  });

  static UserContentPreferences defaultPreferences() {
    return UserContentPreferences(
      showSensitiveContent: false,
      allowedRatings: ['general', 'teen'],
      autoHideReportedContent: true,
      requireContentWarnings: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showSensitiveContent': showSensitiveContent,
      'allowedRatings': allowedRatings,
      'autoHideReportedContent': autoHideReportedContent,
      'requireContentWarnings': requireContentWarnings,
    };
  }

  factory UserContentPreferences.fromMap(Map<String, dynamic> map) {
    return UserContentPreferences(
      showSensitiveContent: map['showSensitiveContent'] ?? false,
      allowedRatings: List<String>.from(map['allowedRatings'] ?? ['general', 'teen']),
      autoHideReportedContent: map['autoHideReportedContent'] ?? true,
      requireContentWarnings: map['requireContentWarnings'] ?? true,
    );
  }
}

class ContentSafetyStats {
  final int totalReports;
  final int pendingReports;
  final int hiddenContent;
  final int flaggedContent;
  final Duration averageResponseTime;

  ContentSafetyStats({
    required this.totalReports,
    required this.pendingReports,
    required this.hiddenContent,
    required this.flaggedContent,
    required this.averageResponseTime,
  });
}