// Enhanced AI-Powered Content Moderation Service for TALOWA
// Implements advanced content filtering and automated policy enforcement

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'content_moderation_service.dart';

class AIContentModerationService {
  static final AIContentModerationService _instance = AIContentModerationService._internal();
  factory AIContentModerationService() => _instance;
  AIContentModerationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ContentModerationService _baseModeration = ContentModerationService();

  // AI-powered content analysis patterns
  final Map<String, List<AIContentPattern>> _aiPatterns = {
    'hate_speech': [
      AIContentPattern(
        pattern: r'\b(hate|despise|loathe)\s+(you|them|him|her)\b',
        severity: ModerationSeverity.high,
        confidence: 0.85,
        action: ModerationAction.hide,
      ),
      AIContentPattern(
        pattern: r'\b(kill|murder|die)\s+(yourself|themselves)\b',
        severity: ModerationSeverity.critical,
        confidence: 0.95,
        action: ModerationAction.remove,
      ),
    ],
    'misinformation': [
      AIContentPattern(
        pattern: r'\b(fake|false|lie)\s+(news|information|government)\b',
        severity: ModerationSeverity.medium,
        confidence: 0.70,
        action: ModerationAction.flag,
      ),
      AIContentPattern(
        pattern: r'\b(conspiracy|hoax|scam)\s+(government|official)\b',
        severity: ModerationSeverity.high,
        confidence: 0.80,
        action: ModerationAction.review,
      ),
    ],
    'spam': [
      AIContentPattern(
        pattern: r'\b(click|visit|buy|call)\s+(now|here|today)\b.*\b(www\.|http|\d{10})\b',
        severity: ModerationSeverity.medium,
        confidence: 0.90,
        action: ModerationAction.hide,
      ),
    ],
    'personal_attacks': [
      AIContentPattern(
        pattern: r'\b(stupid|idiot|fool|moron)\s+(@\w+|you|person)\b',
        severity: ModerationSeverity.medium,
        confidence: 0.75,
        action: ModerationAction.warn,
      ),
    ],
  };

  // Policy enforcement rules
  final Map<String, PolicyRule> _policyRules = {
    'community_guidelines': PolicyRule(
      name: 'Community Guidelines Violation',
      description: 'Content violates community standards',
      triggers: ['hate_speech', 'harassment', 'threats'],
      actions: [ModerationAction.hide, ModerationAction.warn_user],
      escalationThreshold: 3,
      autoEnforce: true,
    ),
    'misinformation_policy': PolicyRule(
      name: 'Misinformation Policy',
      description: 'Content contains false or misleading information',
      triggers: ['misinformation', 'fake_news'],
      actions: [ModerationAction.flag, ModerationAction.add_warning_label],
      escalationThreshold: 2,
      autoEnforce: false,
    ),
    'spam_policy': PolicyRule(
      name: 'Spam and Commercial Content Policy',
      description: 'Content identified as spam or unwanted commercial content',
      triggers: ['spam', 'commercial_content'],
      actions: [ModerationAction.hide, ModerationAction.limit_reach],
      escalationThreshold: 1,
      autoEnforce: true,
    ),
  };

  /// Enhanced AI-powered content analysis
  Future<AIContentModerationResult> analyzeContentWithAI({
    required String content,
    required String contentType,
    String? authorId,
    Map<String, dynamic>? metadata,
    bool enableAutoEnforcement = true,
  }) async {
    try {
      // Start with base moderation
      final baseResult = await _baseModeration.analyzeContent(
        content: content,
        contentType: contentType,
        authorId: authorId,
        metadata: metadata,
      );

      // Enhanced AI analysis
      final aiAnalysis = await _performAIAnalysis(content, contentType, metadata);
      
      // Combine results
      final combinedResult = AIContentModerationResult(
        contentId: baseResult.contentId,
        isAppropriate: baseResult.isAppropriate && aiAnalysis.isAppropriate,
        confidenceScore: _calculateCombinedConfidence(baseResult.confidenceScore, aiAnalysis.confidenceScore),
        flaggedReasons: [...baseResult.flaggedReasons, ...aiAnalysis.flaggedReasons],
        suggestedActions: _mergeSuggestedActions(baseResult.suggestedActions, aiAnalysis.suggestedActions),
        requiresHumanReview: baseResult.requiresHumanReview || aiAnalysis.requiresHumanReview,
        detectedLanguage: baseResult.detectedLanguage,
        aiAnalysis: aiAnalysis,
        policyViolations: aiAnalysis.policyViolations,
        riskScore: aiAnalysis.riskScore,
        automatedActions: aiAnalysis.automatedActions,
      );

      // Apply automated policy enforcement if enabled
      if (enableAutoEnforcement && !combinedResult.isAppropriate) {
        await _enforceAutomatedPolicies(combinedResult);
      }

      // Log enhanced analysis
      await _logAIAnalysis(combinedResult);

      return combinedResult;
    } catch (e) {
      debugPrint('Error in AI content analysis: $e');
      return AIContentModerationResult(
        contentId: 'error_${DateTime.now().millisecondsSinceEpoch}',
        isAppropriate: false,
        confidenceScore: 0.0,
        flaggedReasons: ['ai_analysis_error'],
        suggestedActions: ['manual_review'],
        requiresHumanReview: true,
        detectedLanguage: 'unknown',
        aiAnalysis: AIAnalysisResult(
          isAppropriate: false,
          confidenceScore: 0.0,
          flaggedReasons: ['analysis_error'],
          suggestedActions: ['manual_review'],
          requiresHumanReview: true,
          policyViolations: [],
          riskScore: 1.0,
          automatedActions: [],
        ),
        policyViolations: [],
        riskScore: 1.0,
        automatedActions: [],
      );
    }
  }

  /// Perform advanced AI pattern analysis
  Future<AIAnalysisResult> _performAIAnalysis(
    String content,
    String contentType,
    Map<String, dynamic>? metadata,
  ) async {
    final analysis = AIAnalysisResult(
      isAppropriate: true,
      confidenceScore: 1.0,
      flaggedReasons: [],
      suggestedActions: [],
      requiresHumanReview: false,
      policyViolations: [],
      riskScore: 0.0,
      automatedActions: [],
    );

    // Apply AI pattern matching
    await _applyAIPatterns(content, analysis);
    
    // Sentiment analysis
    await _performSentimentAnalysis(content, analysis);
    
    // Context analysis
    await _performContextAnalysis(content, metadata, analysis);
    
    // Risk scoring
    analysis.riskScore = _calculateRiskScore(analysis);
    
    // Determine if human review is needed
    analysis.requiresHumanReview = _shouldRequireHumanReview(analysis);
    
    return analysis;
  }

  /// Apply AI pattern matching
  Future<void> _applyAIPatterns(String content, AIAnalysisResult analysis) async {
    final lowerContent = content.toLowerCase();
    
    for (final category in _aiPatterns.keys) {
      final patterns = _aiPatterns[category]!;
      
      for (final pattern in patterns) {
        final regex = RegExp(pattern.pattern, caseSensitive: false);
        
        if (regex.hasMatch(lowerContent)) {
          analysis.isAppropriate = false;
          analysis.flaggedReasons.add(category);
          analysis.confidenceScore = min(analysis.confidenceScore, pattern.confidence);
          
          // Add policy violation
          final violation = PolicyViolation(
            category: category,
            severity: pattern.severity,
            confidence: pattern.confidence,
            suggestedAction: pattern.action,
            matchedPattern: pattern.pattern,
          );
          analysis.policyViolations.add(violation);
          
          // Add suggested action
          if (!analysis.suggestedActions.contains(pattern.action.toString())) {
            analysis.suggestedActions.add(pattern.action.toString());
          }
        }
      }
    }
  }

  /// Perform sentiment analysis
  Future<void> _performSentimentAnalysis(String content, AIAnalysisResult analysis) async {
    // Simple sentiment analysis based on word patterns
    final negativeWords = ['hate', 'angry', 'furious', 'disgusted', 'terrible', 'awful', 'horrible'];
    final positiveWords = ['love', 'happy', 'great', 'wonderful', 'amazing', 'excellent', 'fantastic'];
    
    final words = content.toLowerCase().split(RegExp(r'\W+'));
    int negativeCount = 0;
    int positiveCount = 0;
    
    for (final word in words) {
      if (negativeWords.contains(word)) negativeCount++;
      if (positiveWords.contains(word)) positiveCount++;
    }
    
    final sentimentScore = (positiveCount - negativeCount) / max(words.length, 1);
    
    if (sentimentScore < -0.3) {
      analysis.flaggedReasons.add('negative_sentiment');
      analysis.suggestedActions.add('review_sentiment');
    }
  }

  /// Perform context analysis
  Future<void> _performContextAnalysis(
    String content,
    Map<String, dynamic>? metadata,
    AIAnalysisResult analysis,
  ) async {
    // Check for context-specific issues
    if (metadata != null) {
      final timeOfDay = DateTime.now().hour;
      
      // Flag content posted during unusual hours (potential spam)
      if (timeOfDay < 6 || timeOfDay > 23) {
        analysis.flaggedReasons.add('unusual_posting_time');
      }
      
      // Check for rapid posting (potential spam)
      final lastPostTime = metadata['lastPostTime'] as DateTime?;
      if (lastPostTime != null) {
        final timeDiff = DateTime.now().difference(lastPostTime);
        if (timeDiff.inMinutes < 2) {
          analysis.flaggedReasons.add('rapid_posting');
          analysis.suggestedActions.add('rate_limit');
        }
      }
    }
  }

  /// Calculate combined risk score
  double _calculateRiskScore(AIAnalysisResult analysis) {
    double riskScore = 0.0;
    
    // Base risk from violations
    for (final violation in analysis.policyViolations) {
      switch (violation.severity) {
        case ModerationSeverity.low:
          riskScore += 0.2;
          break;
        case ModerationSeverity.medium:
          riskScore += 0.4;
          break;
        case ModerationSeverity.high:
          riskScore += 0.7;
          break;
        case ModerationSeverity.critical:
          riskScore += 1.0;
          break;
      }
    }
    
    // Additional risk factors
    if (analysis.flaggedReasons.contains('negative_sentiment')) riskScore += 0.1;
    if (analysis.flaggedReasons.contains('rapid_posting')) riskScore += 0.2;
    if (analysis.flaggedReasons.contains('unusual_posting_time')) riskScore += 0.1;
    
    return min(riskScore, 1.0);
  }

  /// Determine if human review is required
  bool _shouldRequireHumanReview(AIAnalysisResult analysis) {
    // Require human review for high-risk content
    if (analysis.riskScore > 0.7) return true;
    
    // Require review for critical violations
    for (final violation in analysis.policyViolations) {
      if (violation.severity == ModerationSeverity.critical) return true;
    }
    
    // Require review for ambiguous cases
    if (analysis.confidenceScore < 0.6 && analysis.flaggedReasons.isNotEmpty) return true;
    
    return false;
  }

  /// Enforce automated policies
  Future<void> _enforceAutomatedPolicies(AIContentModerationResult result) async {
    for (final violation in result.policyViolations) {
      final policyRule = _findApplicablePolicy(violation.category);
      
      if (policyRule != null && policyRule.autoEnforce) {
        for (final action in policyRule.actions) {
          await _executeAutomatedAction(result.contentId, action, violation);
          result.automatedActions.add(AutomatedAction(
            action: action,
            reason: violation.category,
            timestamp: DateTime.now(),
            confidence: violation.confidence,
          ));
        }
      }
    }
  }

  /// Find applicable policy rule
  PolicyRule? _findApplicablePolicy(String violationCategory) {
    for (final rule in _policyRules.values) {
      if (rule.triggers.contains(violationCategory)) {
        return rule;
      }
    }
    return null;
  }

  /// Execute automated moderation action
  Future<void> _executeAutomatedAction(
    String contentId,
    ModerationAction action,
    PolicyViolation violation,
  ) async {
    try {
      switch (action) {
        case ModerationAction.hide:
          await _baseModeration.hideContent(
            contentId: contentId,
            reason: 'Automated: ${violation.category}',
            moderatorId: 'ai_system',
          );
          break;
        case ModerationAction.remove:
          await _removeContent(contentId, violation);
          break;
        case ModerationAction.flag:
          await _flagContent(contentId, violation);
          break;
        case ModerationAction.warn:
          await _warnUser(contentId, violation);
          break;
        case ModerationAction.warn_user:
          await _warnUser(contentId, violation);
          break;
        case ModerationAction.add_warning_label:
          await _addWarningLabel(contentId, violation);
          break;
        case ModerationAction.limit_reach:
          await _limitContentReach(contentId, violation);
          break;
        case ModerationAction.review:
          await _queueForReview(contentId, violation);
          break;
      }
    } catch (e) {
      debugPrint('Error executing automated action: $e');
    }
  }

  /// Remove content completely
  Future<void> _removeContent(String contentId, PolicyViolation violation) async {
    await _firestore.collection('posts').doc(contentId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': 'ai_system',
      'deletionReason': 'Automated: ${violation.category}',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Flag content for review
  Future<void> _flagContent(String contentId, PolicyViolation violation) async {
    await _firestore.collection('posts').doc(contentId).update({
      'isFlagged': true,
      'flaggedAt': FieldValue.serverTimestamp(),
      'flaggedBy': 'ai_system',
      'flagReason': violation.category,
      'flagConfidence': violation.confidence,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Warn user about policy violation
  Future<void> _warnUser(String contentId, PolicyViolation violation) async {
    // Get post author
    final postDoc = await _firestore.collection('posts').doc(contentId).get();
    if (postDoc.exists) {
      final authorId = postDoc.data()!['authorId'] as String;
      
      // Create warning notification
      await _firestore.collection('notifications').add({
        'userId': authorId,
        'type': 'content_warning',
        'title': 'Content Policy Warning',
        'message': 'Your content was flagged for: ${violation.category}',
        'contentId': contentId,
        'severity': violation.severity.toString(),
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update user warning count
      await _firestore.collection('users').doc(authorId).update({
        'warningCount': FieldValue.increment(1),
        'lastWarningAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Add warning label to content
  Future<void> _addWarningLabel(String contentId, PolicyViolation violation) async {
    await _firestore.collection('posts').doc(contentId).update({
      'hasWarningLabel': true,
      'warningLabel': 'This content may contain: ${violation.category}',
      'warningAddedAt': FieldValue.serverTimestamp(),
      'warningAddedBy': 'ai_system',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Limit content reach
  Future<void> _limitContentReach(String contentId, PolicyViolation violation) async {
    await _firestore.collection('posts').doc(contentId).update({
      'reachLimited': true,
      'limitReason': violation.category,
      'limitedAt': FieldValue.serverTimestamp(),
      'limitedBy': 'ai_system',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Queue content for human review
  Future<void> _queueForReview(String contentId, PolicyViolation violation) async {
    await _firestore.collection('moderation_queue').add({
      'contentId': contentId,
      'queuedAt': FieldValue.serverTimestamp(),
      'queuedBy': 'ai_system',
      'reason': violation.category,
      'severity': violation.severity.toString(),
      'confidence': violation.confidence,
      'status': 'pending',
      'priority': _getPriorityFromSeverity(violation.severity),
    });
  }

  /// Get priority level from severity
  int _getPriorityFromSeverity(ModerationSeverity severity) {
    switch (severity) {
      case ModerationSeverity.critical:
        return 1;
      case ModerationSeverity.high:
        return 2;
      case ModerationSeverity.medium:
        return 3;
      case ModerationSeverity.low:
        return 4;
    }
  }

  /// Calculate combined confidence score
  double _calculateCombinedConfidence(double baseScore, double aiScore) {
    return (baseScore + aiScore) / 2;
  }

  /// Merge suggested actions
  List<String> _mergeSuggestedActions(List<String> baseActions, List<String> aiActions) {
    final combined = <String>{};
    combined.addAll(baseActions);
    combined.addAll(aiActions);
    return combined.toList();
  }

  /// Log AI analysis results
  Future<void> _logAIAnalysis(AIContentModerationResult result) async {
    try {
      await _firestore.collection('ai_moderation_logs').add({
        'contentId': result.contentId,
        'isAppropriate': result.isAppropriate,
        'confidenceScore': result.confidenceScore,
        'flaggedReasons': result.flaggedReasons,
        'policyViolations': result.policyViolations.map((v) => {
          'category': v.category,
          'severity': v.severity.toString(),
          'confidence': v.confidence,
          'suggestedAction': v.suggestedAction.toString(),
        }).toList(),
        'riskScore': result.riskScore,
        'automatedActions': result.automatedActions.map((a) => {
          'action': a.action.toString(),
          'reason': a.reason,
          'timestamp': a.timestamp.toIso8601String(),
          'confidence': a.confidence,
        }).toList(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging AI analysis: $e');
    }
  }

  /// Get AI moderation statistics
  Future<AIModerationStats> getAIModerationStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();
      
      final logsQuery = _firestore
          .collection('ai_moderation_logs')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end);
      
      final logsSnapshot = await logsQuery.get();
      
      int totalAnalyzed = logsSnapshot.docs.length;
      int flaggedContent = 0;
      int automatedActions = 0;
      Map<String, int> violationTypes = {};
      Map<String, int> actionTypes = {};
      
      for (final doc in logsSnapshot.docs) {
        final data = doc.data();
        
        if (data['isAppropriate'] == false) flaggedContent++;
        
        final violations = data['policyViolations'] as List? ?? [];
        for (final violation in violations) {
          final category = violation['category'] as String;
          violationTypes[category] = (violationTypes[category] ?? 0) + 1;
        }
        
        final actions = data['automatedActions'] as List? ?? [];
        automatedActions += actions.length;
        for (final action in actions) {
          final actionType = action['action'] as String;
          actionTypes[actionType] = (actionTypes[actionType] ?? 0) + 1;
        }
      }
      
      return AIModerationStats(
        totalAnalyzed: totalAnalyzed,
        flaggedContent: flaggedContent,
        automatedActions: automatedActions,
        violationTypes: violationTypes,
        actionTypes: actionTypes,
        period: DateRange(start: start, end: end),
        accuracy: flaggedContent > 0 ? (automatedActions / flaggedContent) : 1.0,
      );
    } catch (e) {
      debugPrint('Error getting AI moderation stats: $e');
      return AIModerationStats(
        totalAnalyzed: 0,
        flaggedContent: 0,
        automatedActions: 0,
        violationTypes: {},
        actionTypes: {},
        period: DateRange(start: DateTime.now(), end: DateTime.now()),
        accuracy: 0.0,
      );
    }
  }
}

// Data models for AI content moderation

class AIContentPattern {
  final String pattern;
  final ModerationSeverity severity;
  final double confidence;
  final ModerationAction action;

  AIContentPattern({
    required this.pattern,
    required this.severity,
    required this.confidence,
    required this.action,
  });
}

class PolicyRule {
  final String name;
  final String description;
  final List<String> triggers;
  final List<ModerationAction> actions;
  final int escalationThreshold;
  final bool autoEnforce;

  PolicyRule({
    required this.name,
    required this.description,
    required this.triggers,
    required this.actions,
    required this.escalationThreshold,
    required this.autoEnforce,
  });
}

class PolicyViolation {
  final String category;
  final ModerationSeverity severity;
  final double confidence;
  final ModerationAction suggestedAction;
  final String matchedPattern;

  PolicyViolation({
    required this.category,
    required this.severity,
    required this.confidence,
    required this.suggestedAction,
    required this.matchedPattern,
  });
}

class AutomatedAction {
  final ModerationAction action;
  final String reason;
  final DateTime timestamp;
  final double confidence;

  AutomatedAction({
    required this.action,
    required this.reason,
    required this.timestamp,
    required this.confidence,
  });
}

class AIAnalysisResult {
  bool isAppropriate;
  double confidenceScore;
  List<String> flaggedReasons;
  List<String> suggestedActions;
  bool requiresHumanReview;
  List<PolicyViolation> policyViolations;
  double riskScore;
  List<AutomatedAction> automatedActions;

  AIAnalysisResult({
    required this.isAppropriate,
    required this.confidenceScore,
    required this.flaggedReasons,
    required this.suggestedActions,
    required this.requiresHumanReview,
    required this.policyViolations,
    required this.riskScore,
    required this.automatedActions,
  });
}

class AIContentModerationResult {
  final String contentId;
  final bool isAppropriate;
  final double confidenceScore;
  final List<String> flaggedReasons;
  final List<String> suggestedActions;
  final bool requiresHumanReview;
  final String detectedLanguage;
  final AIAnalysisResult aiAnalysis;
  final List<PolicyViolation> policyViolations;
  final double riskScore;
  final List<AutomatedAction> automatedActions;

  AIContentModerationResult({
    required this.contentId,
    required this.isAppropriate,
    required this.confidenceScore,
    required this.flaggedReasons,
    required this.suggestedActions,
    required this.requiresHumanReview,
    required this.detectedLanguage,
    required this.aiAnalysis,
    required this.policyViolations,
    required this.riskScore,
    required this.automatedActions,
  });
}

class AIModerationStats {
  final int totalAnalyzed;
  final int flaggedContent;
  final int automatedActions;
  final Map<String, int> violationTypes;
  final Map<String, int> actionTypes;
  final DateRange period;
  final double accuracy;

  AIModerationStats({
    required this.totalAnalyzed,
    required this.flaggedContent,
    required this.automatedActions,
    required this.violationTypes,
    required this.actionTypes,
    required this.period,
    required this.accuracy,
  });
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

enum ModerationSeverity {
  low,
  medium,
  high,
  critical,
}

enum ModerationAction {
  hide,
  remove,
  flag,
  warn,
  warn_user,
  add_warning_label,
  limit_reach,
  review,
}
