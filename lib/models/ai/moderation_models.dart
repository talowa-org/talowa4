// AI Moderation Models for TALOWA Advanced Social Feed System
// Data models for AI-powered moderation system with comprehensive analysis results

import 'package:cloud_firestore/cloud_firestore.dart';

/// Enumeration for moderation actions
enum ModerationAction {
  approve,
  flagForReview,
  reject,
  shadowBan,
  temporaryRestriction,
  permanentBan,
}

/// Enumeration for moderation levels
enum ModerationLevel {
  lenient,
  standard,
  strict,
  enterprise,
}

/// Enumeration for escalation priorities
enum EscalationPriority {
  low,
  normal,
  high,
  critical,
  emergency,
}

/// Enumeration for harassment severity levels
enum HarassmentSeverity {
  none,
  mild,
  moderate,
  severe,
  critical,
}

/// Enumeration for violence severity levels
enum ViolenceSeverity {
  none,
  mild,
  moderate,
  severe,
  critical,
}

/// Enumeration for cultural context
enum CulturalContext {
  neutral,
  sensitive,
  controversial,
  taboo,
}

/// Main moderation result containing all analysis results
class ModerationResult {
  final ModerationAction decision;
  final double confidence;
  final double overallScore;
  final ToxicityAnalysis? toxicityAnalysis;
  final HateSpeechAnalysis? hateSpeechAnalysis;
  final HarassmentAnalysis? harassmentAnalysis;
  final SpamAnalysis? spamAnalysis;
  final ViolenceAnalysis? violenceAnalysis;
  final MisinformationAnalysis? misinformationAnalysis;
  final CulturalSensitivityAnalysis? culturalSensitivityAnalysis;
  final MediaModerationResult? mediaAnalysis;
  final List<String> flags;
  final String? reason;
  final bool escalationRequired;
  final int processingTime;
  final DateTime timestamp;

  ModerationResult({
    required this.decision,
    required this.confidence,
    required this.overallScore,
    this.toxicityAnalysis,
    this.hateSpeechAnalysis,
    this.harassmentAnalysis,
    this.spamAnalysis,
    this.violenceAnalysis,
    this.misinformationAnalysis,
    this.culturalSensitivityAnalysis,
    this.mediaAnalysis,
    required this.flags,
    this.reason,
    required this.escalationRequired,
    required this.processingTime,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'decision': decision.name,
      'confidence': confidence,
      'overallScore': overallScore,
      'toxicityAnalysis': toxicityAnalysis?.toMap(),
      'hateSpeechAnalysis': hateSpeechAnalysis?.toMap(),
      'harassmentAnalysis': harassmentAnalysis?.toMap(),
      'spamAnalysis': spamAnalysis?.toMap(),
      'violenceAnalysis': violenceAnalysis?.toMap(),
      'misinformationAnalysis': misinformationAnalysis?.toMap(),
      'culturalSensitivityAnalysis': culturalSensitivityAnalysis?.toMap(),
      'mediaAnalysis': mediaAnalysis?.toMap(),
      'flags': flags,
      'reason': reason,
      'escalationRequired': escalationRequired,
      'processingTime': processingTime,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ModerationResult.fromMap(Map<String, dynamic> map) {
    return ModerationResult(
      decision: ModerationAction.values.firstWhere(
        (e) => e.name == map['decision'],
        orElse: () => ModerationAction.flagForReview,
      ),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      toxicityAnalysis: map['toxicityAnalysis'] != null
          ? ToxicityAnalysis.fromMap(map['toxicityAnalysis'])
          : null,
      hateSpeechAnalysis: map['hateSpeechAnalysis'] != null
          ? HateSpeechAnalysis.fromMap(map['hateSpeechAnalysis'])
          : null,
      harassmentAnalysis: map['harassmentAnalysis'] != null
          ? HarassmentAnalysis.fromMap(map['harassmentAnalysis'])
          : null,
      spamAnalysis: map['spamAnalysis'] != null
          ? SpamAnalysis.fromMap(map['spamAnalysis'])
          : null,
      violenceAnalysis: map['violenceAnalysis'] != null
          ? ViolenceAnalysis.fromMap(map['violenceAnalysis'])
          : null,
      misinformationAnalysis: map['misinformationAnalysis'] != null
          ? MisinformationAnalysis.fromMap(map['misinformationAnalysis'])
          : null,
      culturalSensitivityAnalysis: map['culturalSensitivityAnalysis'] != null
          ? CulturalSensitivityAnalysis.fromMap(map['culturalSensitivityAnalysis'])
          : null,
      mediaAnalysis: map['mediaAnalysis'] != null
          ? MediaModerationResult.fromMap(map['mediaAnalysis'])
          : null,
      flags: List<String>.from(map['flags'] ?? []),
      reason: map['reason'],
      escalationRequired: map['escalationRequired'] ?? false,
      processingTime: map['processingTime'] ?? 0,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

/// Toxicity analysis result with ensemble scoring
class ToxicityAnalysis {
  final double overallScore;
  final double? perspectiveScore;
  final double? openAiScore;
  final double? localScore;
  final List<String> categories;
  final bool isAboveThreshold;
  final double confidence;
  final List<String> detectedPhrases;

  ToxicityAnalysis({
    required this.overallScore,
    this.perspectiveScore,
    this.openAiScore,
    this.localScore,
    required this.categories,
    required this.isAboveThreshold,
    required this.confidence,
    required this.detectedPhrases,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'perspectiveScore': perspectiveScore,
      'openAiScore': openAiScore,
      'localScore': localScore,
      'categories': categories,
      'isAboveThreshold': isAboveThreshold,
      'confidence': confidence,
      'detectedPhrases': detectedPhrases,
    };
  }

  factory ToxicityAnalysis.fromMap(Map<String, dynamic> map) {
    return ToxicityAnalysis(
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      perspectiveScore: (map['perspectiveScore'] as num?)?.toDouble(),
      openAiScore: (map['openAiScore'] as num?)?.toDouble(),
      localScore: (map['localScore'] as num?)?.toDouble(),
      categories: List<String>.from(map['categories'] ?? []),
      isAboveThreshold: map['isAboveThreshold'] ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      detectedPhrases: List<String>.from(map['detectedPhrases'] ?? []),
    );
  }
}

/// Hate speech analysis result
class HateSpeechAnalysis {
  final double overallScore;
  final double? identityAttackScore;
  final double? discriminationScore;
  final double? slurScore;
  final bool isAboveThreshold;
  final double confidence;
  final List<String> targetedGroups;
  final List<String> detectedSlurs;

  HateSpeechAnalysis({
    required this.overallScore,
    this.identityAttackScore,
    this.discriminationScore,
    this.slurScore,
    required this.isAboveThreshold,
    required this.confidence,
    required this.targetedGroups,
    required this.detectedSlurs,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'identityAttackScore': identityAttackScore,
      'discriminationScore': discriminationScore,
      'slurScore': slurScore,
      'isAboveThreshold': isAboveThreshold,
      'confidence': confidence,
      'targetedGroups': targetedGroups,
      'detectedSlurs': detectedSlurs,
    };
  }

  factory HateSpeechAnalysis.fromMap(Map<String, dynamic> map) {
    return HateSpeechAnalysis(
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      identityAttackScore: (map['identityAttackScore'] as num?)?.toDouble(),
      discriminationScore: (map['discriminationScore'] as num?)?.toDouble(),
      slurScore: (map['slurScore'] as num?)?.toDouble(),
      isAboveThreshold: map['isAboveThreshold'] ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      targetedGroups: List<String>.from(map['targetedGroups'] ?? []),
      detectedSlurs: List<String>.from(map['detectedSlurs'] ?? []),
    );
  }
}

/// Harassment analysis result
class HarassmentAnalysis {
  final double overallScore;
  final double? personalAttackScore;
  final double? intimidationScore;
  final double? cyberbullyingScore;
  final bool isAboveThreshold;
  final double confidence;
  final List<String> harassmentTypes;
  final HarassmentSeverity severity;

  HarassmentAnalysis({
    required this.overallScore,
    this.personalAttackScore,
    this.intimidationScore,
    this.cyberbullyingScore,
    required this.isAboveThreshold,
    required this.confidence,
    required this.harassmentTypes,
    required this.severity,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'personalAttackScore': personalAttackScore,
      'intimidationScore': intimidationScore,
      'cyberbullyingScore': cyberbullyingScore,
      'isAboveThreshold': isAboveThreshold,
      'confidence': confidence,
      'harassmentTypes': harassmentTypes,
      'severity': severity.name,
    };
  }

  factory HarassmentAnalysis.fromMap(Map<String, dynamic> map) {
    return HarassmentAnalysis(
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      personalAttackScore: (map['personalAttackScore'] as num?)?.toDouble(),
      intimidationScore: (map['intimidationScore'] as num?)?.toDouble(),
      cyberbullyingScore: (map['cyberbullyingScore'] as num?)?.toDouble(),
      isAboveThreshold: map['isAboveThreshold'] ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      harassmentTypes: List<String>.from(map['harassmentTypes'] ?? []),
      severity: HarassmentSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => HarassmentSeverity.none,
      ),
    );
  }
}

/// Spam analysis result
class SpamAnalysis {
  final double overallScore;
  final double? repetitiveScore;
  final double? promotionalScore;
  final double? botPatternScore;
  final double? linkSpamScore;
  final bool isAboveThreshold;
  final double confidence;
  final List<String> spamTypes;
  final List<String> suspiciousPatterns;

  SpamAnalysis({
    required this.overallScore,
    this.repetitiveScore,
    this.promotionalScore,
    this.botPatternScore,
    this.linkSpamScore,
    required this.isAboveThreshold,
    required this.confidence,
    required this.spamTypes,
    required this.suspiciousPatterns,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'repetitiveScore': repetitiveScore,
      'promotionalScore': promotionalScore,
      'botPatternScore': botPatternScore,
      'linkSpamScore': linkSpamScore,
      'isAboveThreshold': isAboveThreshold,
      'confidence': confidence,
      'spamTypes': spamTypes,
      'suspiciousPatterns': suspiciousPatterns,
    };
  }

  factory SpamAnalysis.fromMap(Map<String, dynamic> map) {
    return SpamAnalysis(
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      repetitiveScore: (map['repetitiveScore'] as num?)?.toDouble(),
      promotionalScore: (map['promotionalScore'] as num?)?.toDouble(),
      botPatternScore: (map['botPatternScore'] as num?)?.toDouble(),
      linkSpamScore: (map['linkSpamScore'] as num?)?.toDouble(),
      isAboveThreshold: map['isAboveThreshold'] ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      spamTypes: List<String>.from(map['spamTypes'] ?? []),
      suspiciousPatterns: List<String>.from(map['suspiciousPatterns'] ?? []),
    );
  }
}

/// Violence analysis result
class ViolenceAnalysis {
  final double overallScore;
  final double? threatScore;
  final double? violentLanguageScore;
  final double? selfHarmScore;
  final bool isAboveThreshold;
  final double confidence;
  final List<String> threatTypes;
  final ViolenceSeverity severity;
  final bool requiresImmediateAction;

  ViolenceAnalysis({
    required this.overallScore,
    this.threatScore,
    this.violentLanguageScore,
    this.selfHarmScore,
    required this.isAboveThreshold,
    required this.confidence,
    required this.threatTypes,
    required this.severity,
    required this.requiresImmediateAction,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'threatScore': threatScore,
      'violentLanguageScore': violentLanguageScore,
      'selfHarmScore': selfHarmScore,
      'isAboveThreshold': isAboveThreshold,
      'confidence': confidence,
      'threatTypes': threatTypes,
      'severity': severity.name,
      'requiresImmediateAction': requiresImmediateAction,
    };
  }

  factory ViolenceAnalysis.fromMap(Map<String, dynamic> map) {
    return ViolenceAnalysis(
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      threatScore: (map['threatScore'] as num?)?.toDouble(),
      violentLanguageScore: (map['violentLanguageScore'] as num?)?.toDouble(),
      selfHarmScore: (map['selfHarmScore'] as num?)?.toDouble(),
      isAboveThreshold: map['isAboveThreshold'] ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      threatTypes: List<String>.from(map['threatTypes'] ?? []),
      severity: ViolenceSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => ViolenceSeverity.none,
      ),
      requiresImmediateAction: map['requiresImmediateAction'] ?? false,
    );
  }
}

/// Misinformation analysis result
class MisinformationAnalysis {
  final double overallScore;
  final double? factualAccuracyScore;
  final double? sourceCredibilityScore;
  final double? sensationalLanguageScore;
  final bool isAboveThreshold;
  final double confidence;
  final List<String> misinformationTypes;
  final bool factCheckRequired;
  final List<String> suspiciousClaims;

  MisinformationAnalysis({
    required this.overallScore,
    this.factualAccuracyScore,
    this.sourceCredibilityScore,
    this.sensationalLanguageScore,
    required this.isAboveThreshold,
    required this.confidence,
    required this.misinformationTypes,
    required this.factCheckRequired,
    required this.suspiciousClaims,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'factualAccuracyScore': factualAccuracyScore,
      'sourceCredibilityScore': sourceCredibilityScore,
      'sensationalLanguageScore': sensationalLanguageScore,
      'isAboveThreshold': isAboveThreshold,
      'confidence': confidence,
      'misinformationTypes': misinformationTypes,
      'factCheckRequired': factCheckRequired,
      'suspiciousClaims': suspiciousClaims,
    };
  }

  factory MisinformationAnalysis.fromMap(Map<String, dynamic> map) {
    return MisinformationAnalysis(
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      factualAccuracyScore: (map['factualAccuracyScore'] as num?)?.toDouble(),
      sourceCredibilityScore: (map['sourceCredibilityScore'] as num?)?.toDouble(),
      sensationalLanguageScore: (map['sensationalLanguageScore'] as num?)?.toDouble(),
      isAboveThreshold: map['isAboveThreshold'] ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      misinformationTypes: List<String>.from(map['misinformationTypes'] ?? []),
      factCheckRequired: map['factCheckRequired'] ?? false,
      suspiciousClaims: List<String>.from(map['suspiciousClaims'] ?? []),
    );
  }
}

/// Cultural sensitivity analysis result
class CulturalSensitivityAnalysis {
  final double overallScore;
  final double? religiousSensitivityScore;
  final double? politicalSensitivityScore;
  final double? socialSensitivityScore;
  final bool isCulturallySensitive;
  final double confidence;
  final List<String> sensitiveTopics;
  final CulturalContext culturalContext;
  final bool requiresLocalReview;

  CulturalSensitivityAnalysis({
    required this.overallScore,
    this.religiousSensitivityScore,
    this.politicalSensitivityScore,
    this.socialSensitivityScore,
    required this.isCulturallySensitive,
    required this.confidence,
    required this.sensitiveTopics,
    required this.culturalContext,
    required this.requiresLocalReview,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'religiousSensitivityScore': religiousSensitivityScore,
      'politicalSensitivityScore': politicalSensitivityScore,
      'socialSensitivityScore': socialSensitivityScore,
      'isCulturallySensitive': isCulturallySensitive,
      'confidence': confidence,
      'sensitiveTopics': sensitiveTopics,
      'culturalContext': culturalContext.name,
      'requiresLocalReview': requiresLocalReview,
    };
  }

  factory CulturalSensitivityAnalysis.fromMap(Map<String, dynamic> map) {
    return CulturalSensitivityAnalysis(
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      religiousSensitivityScore: (map['religiousSensitivityScore'] as num?)?.toDouble(),
      politicalSensitivityScore: (map['politicalSensitivityScore'] as num?)?.toDouble(),
      socialSensitivityScore: (map['socialSensitivityScore'] as num?)?.toDouble(),
      isCulturallySensitive: map['isCulturallySensitive'] ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      sensitiveTopics: List<String>.from(map['sensitiveTopics'] ?? []),
      culturalContext: CulturalContext.values.firstWhere(
        (e) => e.name == map['culturalContext'],
        orElse: () => CulturalContext.neutral,
      ),
      requiresLocalReview: map['requiresLocalReview'] ?? false,
    );
  }
}

/// Media moderation result for images and videos
class MediaModerationResult {
  final double overallScore;
  final List<MediaAnalysisResult> mediaResults;
  final bool hasInappropriateContent;
  final double confidence;
  final List<MediaAnalysisResult> flaggedContent;
  final bool requiresHumanReview;

  MediaModerationResult({
    required this.overallScore,
    required this.mediaResults,
    required this.hasInappropriateContent,
    required this.confidence,
    required this.flaggedContent,
    required this.requiresHumanReview,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'mediaResults': mediaResults.map((r) => r.toMap()).toList(),
      'hasInappropriateContent': hasInappropriateContent,
      'confidence': confidence,
      'flaggedContent': flaggedContent.map((r) => r.toMap()).toList(),
      'requiresHumanReview': requiresHumanReview,
    };
  }

  factory MediaModerationResult.fromMap(Map<String, dynamic> map) {
    return MediaModerationResult(
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      mediaResults: (map['mediaResults'] as List?)
              ?.map((r) => MediaAnalysisResult.fromMap(r))
              .toList() ??
          [],
      hasInappropriateContent: map['hasInappropriateContent'] ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      flaggedContent: (map['flaggedContent'] as List?)
              ?.map((r) => MediaAnalysisResult.fromMap(r))
              .toList() ??
          [],
      requiresHumanReview: map['requiresHumanReview'] ?? false,
    );
  }
}

/// Individual media analysis result
class MediaAnalysisResult {
  final String url;
  final String mediaType;
  final double inappropriateScore;
  final double confidence;
  final List<String> flags;

  MediaAnalysisResult({
    required this.url,
    required this.mediaType,
    required this.inappropriateScore,
    required this.confidence,
    required this.flags,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'mediaType': mediaType,
      'inappropriateScore': inappropriateScore,
      'confidence': confidence,
      'flags': flags,
    };
  }

  factory MediaAnalysisResult.fromMap(Map<String, dynamic> map) {
    return MediaAnalysisResult(
      url: map['url'] ?? '',
      mediaType: map['mediaType'] ?? '',
      inappropriateScore: (map['inappropriateScore'] as num?)?.toDouble() ?? 0.0,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      flags: List<String>.from(map['flags'] ?? []),
    );
  }
}

/// Moderation decision helper class
class ModerationDecision {
  final ModerationAction action;
  final double confidence;
  final double overallScore;
  final List<String> flags;
  final String? reason;
  final bool escalationRequired;

  ModerationDecision({
    required this.action,
    required this.confidence,
    required this.overallScore,
    required this.flags,
    this.reason,
    required this.escalationRequired,
  });
}

/// Moderation analytics data
class ModerationAnalytics {
  final int totalContentModerated;
  final int totalEscalated;
  final Map<String, int> actionBreakdown;
  final Map<String, int> flagBreakdown;
  final double averageProcessingTime;
  final double accuracyRate;
  final double escalationRate;
  final DateTime periodStart;
  final DateTime periodEnd;

  ModerationAnalytics({
    required this.totalContentModerated,
    required this.totalEscalated,
    required this.actionBreakdown,
    required this.flagBreakdown,
    required this.averageProcessingTime,
    required this.accuracyRate,
    required this.escalationRate,
    required this.periodStart,
    required this.periodEnd,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalContentModerated': totalContentModerated,
      'totalEscalated': totalEscalated,
      'actionBreakdown': actionBreakdown,
      'flagBreakdown': flagBreakdown,
      'averageProcessingTime': averageProcessingTime,
      'accuracyRate': accuracyRate,
      'escalationRate': escalationRate,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
    };
  }

  factory ModerationAnalytics.fromMap(Map<String, dynamic> map) {
    return ModerationAnalytics(
      totalContentModerated: map['totalContentModerated'] ?? 0,
      totalEscalated: map['totalEscalated'] ?? 0,
      actionBreakdown: Map<String, int>.from(map['actionBreakdown'] ?? {}),
      flagBreakdown: Map<String, int>.from(map['flagBreakdown'] ?? {}),
      averageProcessingTime: (map['averageProcessingTime'] as num?)?.toDouble() ?? 0.0,
      accuracyRate: (map['accuracyRate'] as num?)?.toDouble() ?? 0.0,
      escalationRate: (map['escalationRate'] as num?)?.toDouble() ?? 0.0,
      periodStart: map['periodStart'] is Timestamp
          ? (map['periodStart'] as Timestamp).toDate()
          : DateTime.now().subtract(const Duration(days: 30)),
      periodEnd: map['periodEnd'] is Timestamp
          ? (map['periodEnd'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}