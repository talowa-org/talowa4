// Data models for Content Intelligence Engine
// AI-powered content analysis and processing models
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/advanced_models.dart';

/// Content sentiment analysis results
enum ContentSentiment {
  positive,
  negative,
  neutral,
  mixed,
}

extension ContentSentimentExtension on ContentSentiment {
  String get value {
    switch (this) {
      case ContentSentiment.positive:
        return 'positive';
      case ContentSentiment.negative:
        return 'negative';
      case ContentSentiment.neutral:
        return 'neutral';
      case ContentSentiment.mixed:
        return 'mixed';
    }
  }

  static ContentSentiment fromString(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return ContentSentiment.positive;
      case 'negative':
        return ContentSentiment.negative;
      case 'mixed':
        return ContentSentiment.mixed;
      default:
        return ContentSentiment.neutral;
    }
  }
}

/// Content type classification
enum ContentType {
  text,
  question,
  announcement,
  request,
  success,
  general,
  multimedia,
  educational,
  news,
  discussion,
}

extension ContentTypeExtension on ContentType {
  String get value {
    switch (this) {
      case ContentType.text:
        return 'text';
      case ContentType.question:
        return 'question';
      case ContentType.announcement:
        return 'announcement';
      case ContentType.request:
        return 'request';
      case ContentType.success:
        return 'success';
      case ContentType.general:
        return 'general';
      case ContentType.multimedia:
        return 'multimedia';
      case ContentType.educational:
        return 'educational';
      case ContentType.news:
        return 'news';
      case ContentType.discussion:
        return 'discussion';
    }
  }

  static ContentType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return ContentType.text;
      case 'question':
        return ContentType.question;
      case 'announcement':
        return ContentType.announcement;
      case 'request':
        return ContentType.request;
      case 'success':
        return ContentType.success;
      case 'multimedia':
        return ContentType.multimedia;
      case 'educational':
        return ContentType.educational;
      case 'news':
        return ContentType.news;
      case 'discussion':
        return ContentType.discussion;
      default:
        return ContentType.general;
    }
  }
}

/// Cultural context awareness
enum CulturalContext {
  neutral,
  sensitive,
  religious,
  political,
  social,
}

extension CulturalContextExtension on CulturalContext {
  String get value {
    switch (this) {
      case CulturalContext.neutral:
        return 'neutral';
      case CulturalContext.sensitive:
        return 'sensitive';
      case CulturalContext.religious:
        return 'religious';
      case CulturalContext.political:
        return 'political';
      case CulturalContext.social:
        return 'social';
    }
  }

  static CulturalContext fromString(String context) {
    switch (context.toLowerCase()) {
      case 'sensitive':
        return CulturalContext.sensitive;
      case 'religious':
        return CulturalContext.religious;
      case 'political':
        return CulturalContext.political;
      case 'social':
        return CulturalContext.social;
      default:
        return CulturalContext.neutral;
    }
  }
}

/// Media analysis results
class MediaAnalysis {
  final int totalCount;
  final int imageCount;
  final int videoCount;
  final int audioCount;
  final int documentCount;
  final bool hasInappropriateContent;
  final double qualityScore;
  final List<String> detectedObjects;
  final List<String> detectedText;
  final Map<String, dynamic> metadata;

  const MediaAnalysis({
    required this.totalCount,
    this.imageCount = 0,
    this.videoCount = 0,
    this.audioCount = 0,
    this.documentCount = 0,
    this.hasInappropriateContent = false,
    this.qualityScore = 0.0,
    this.detectedObjects = const [],
    this.detectedText = const [],
    this.metadata = const {},
  });

  factory MediaAnalysis.fromMap(Map<String, dynamic> data) {
    return MediaAnalysis(
      totalCount: data['totalCount'] ?? 0,
      imageCount: data['imageCount'] ?? 0,
      videoCount: data['videoCount'] ?? 0,
      audioCount: data['audioCount'] ?? 0,
      documentCount: data['documentCount'] ?? 0,
      hasInappropriateContent: data['hasInappropriateContent'] ?? false,
      qualityScore: (data['qualityScore'] ?? 0.0).toDouble(),
      detectedObjects: List<String>.from(data['detectedObjects'] ?? []),
      detectedText: List<String>.from(data['detectedText'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCount': totalCount,
      'imageCount': imageCount,
      'videoCount': videoCount,
      'audioCount': audioCount,
      'documentCount': documentCount,
      'hasInappropriateContent': hasInappropriateContent,
      'qualityScore': qualityScore,
      'detectedObjects': detectedObjects,
      'detectedText': detectedText,
      'metadata': metadata,
    };
  }
}

/// Translation result
class TranslationResult {
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double confidence;
  final DateTime timestamp;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.confidence = 0.0,
    required this.timestamp,
  });

  factory TranslationResult.fromMap(Map<String, dynamic> data) {
    return TranslationResult(
      originalText: data['originalText'] ?? '',
      translatedText: data['translatedText'] ?? '',
      sourceLanguage: data['sourceLanguage'] ?? 'en',
      targetLanguage: data['targetLanguage'] ?? 'en',
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'originalText': originalText,
      'translatedText': translatedText,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Comprehensive content analysis results
class ContentAnalysis {
  final ContentSentiment sentiment;
  final List<String> topics;
  final List<String> hashtags;
  final String summary;
  final double toxicityScore;
  final double engagementPrediction;
  final double readabilityScore;
  final String languageDetection;
  final List<String> keyPhrases;
  final ContentType contentType;
  final CulturalContext culturalContext;
  final MediaAnalysis? mediaAnalysis;
  final int processingTime;
  final List<String> suggestedCategories;
  final double spamScore;
  final List<String> namedEntities;
  final Map<String, double> emotionScores;
  final List<TranslationResult> translations;

  const ContentAnalysis({
    required this.sentiment,
    required this.topics,
    required this.hashtags,
    required this.summary,
    required this.toxicityScore,
    required this.engagementPrediction,
    required this.readabilityScore,
    required this.languageDetection,
    required this.keyPhrases,
    required this.contentType,
    required this.culturalContext,
    this.mediaAnalysis,
    required this.processingTime,
    this.suggestedCategories = const [],
    this.spamScore = 0.0,
    this.namedEntities = const [],
    this.emotionScores = const {},
    this.translations = const [],
  });

  factory ContentAnalysis.fromMap(Map<String, dynamic> data) {
    return ContentAnalysis(
      sentiment: ContentSentimentExtension.fromString(data['sentiment'] ?? 'neutral'),
      topics: List<String>.from(data['topics'] ?? []),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      summary: data['summary'] ?? '',
      toxicityScore: (data['toxicityScore'] ?? 0.0).toDouble(),
      engagementPrediction: (data['engagementPrediction'] ?? 0.0).toDouble(),
      readabilityScore: (data['readabilityScore'] ?? 0.0).toDouble(),
      languageDetection: data['languageDetection'] ?? 'en',
      keyPhrases: List<String>.from(data['keyPhrases'] ?? []),
      contentType: ContentTypeExtension.fromString(data['contentType'] ?? 'general'),
      culturalContext: CulturalContextExtension.fromString(data['culturalContext'] ?? 'neutral'),
      mediaAnalysis: data['mediaAnalysis'] != null 
          ? MediaAnalysis.fromMap(Map<String, dynamic>.from(data['mediaAnalysis']))
          : null,
      processingTime: data['processingTime'] ?? 0,
      suggestedCategories: List<String>.from(data['suggestedCategories'] ?? []),
      spamScore: (data['spamScore'] ?? 0.0).toDouble(),
      namedEntities: List<String>.from(data['namedEntities'] ?? []),
      emotionScores: Map<String, double>.from(data['emotionScores'] ?? {}),
      translations: (data['translations'] as List<dynamic>?)
          ?.map((item) => TranslationResult.fromMap(Map<String, dynamic>.from(item)))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sentiment': sentiment.value,
      'topics': topics,
      'hashtags': hashtags,
      'summary': summary,
      'toxicityScore': toxicityScore,
      'engagementPrediction': engagementPrediction,
      'readabilityScore': readabilityScore,
      'languageDetection': languageDetection,
      'keyPhrases': keyPhrases,
      'contentType': contentType.value,
      'culturalContext': culturalContext.value,
      'mediaAnalysis': mediaAnalysis?.toMap(),
      'processingTime': processingTime,
      'suggestedCategories': suggestedCategories,
      'spamScore': spamScore,
      'namedEntities': namedEntities,
      'emotionScores': emotionScores,
      'translations': translations.map((t) => t.toMap()).toList(),
    };
  }
}

/// Moderation levels
enum ModerationLevel {
  basic,
  standard,
  strict,
  custom,
}

extension ModerationLevelExtension on ModerationLevel {
  String get name {
    switch (this) {
      case ModerationLevel.basic:
        return 'basic';
      case ModerationLevel.standard:
        return 'standard';
      case ModerationLevel.strict:
        return 'strict';
      case ModerationLevel.custom:
        return 'custom';
    }
  }

  static ModerationLevel fromString(String level) {
    switch (level.toLowerCase()) {
      case 'basic':
        return ModerationLevel.basic;
      case 'standard':
        return ModerationLevel.standard;
      case 'strict':
        return ModerationLevel.strict;
      case 'custom':
        return ModerationLevel.custom;
      default:
        return ModerationLevel.standard;
    }
  }
}

/// Moderation actions
enum ModerationAction {
  approve,
  flag,
  reject,
  review,
}

extension ModerationActionExtension on ModerationAction {
  String get value {
    switch (this) {
      case ModerationAction.approve:
        return 'approve';
      case ModerationAction.flag:
        return 'flag';
      case ModerationAction.reject:
        return 'reject';
      case ModerationAction.review:
        return 'review';
    }
  }

  static ModerationAction fromString(String action) {
    switch (action.toLowerCase()) {
      case 'approve':
        return ModerationAction.approve;
      case 'flag':
        return ModerationAction.flag;
      case 'reject':
        return ModerationAction.reject;
      case 'review':
        return ModerationAction.review;
      default:
        return ModerationAction.approve;
    }
  }
}

/// Moderation result
class ModerationResult {
  final ModerationAction action;
  final double confidence;
  final List<String> flags;
  final String? reason;
  final double toxicityScore;
  final double spamScore;
  final double culturalSensitivityScore;
  final int processingTime;
  final Map<String, dynamic> metadata;

  const ModerationResult({
    required this.action,
    required this.confidence,
    this.flags = const [],
    this.reason,
    this.toxicityScore = 0.0,
    this.spamScore = 0.0,
    this.culturalSensitivityScore = 1.0,
    required this.processingTime,
    this.metadata = const {},
  });

  factory ModerationResult.fromMap(Map<String, dynamic> data) {
    return ModerationResult(
      action: ModerationActionExtension.fromString(data['action'] ?? 'approve'),
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      flags: List<String>.from(data['flags'] ?? []),
      reason: data['reason'],
      toxicityScore: (data['toxicityScore'] ?? 0.0).toDouble(),
      spamScore: (data['spamScore'] ?? 0.0).toDouble(),
      culturalSensitivityScore: (data['culturalSensitivityScore'] ?? 1.0).toDouble(),
      processingTime: data['processingTime'] ?? 0,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action.value,
      'confidence': confidence,
      'flags': flags,
      'reason': reason,
      'toxicityScore': toxicityScore,
      'spamScore': spamScore,
      'culturalSensitivityScore': culturalSensitivityScore,
      'processingTime': processingTime,
      'metadata': metadata,
    };
  }
}

/// Scored post for recommendations
class ScoredPost {
  final PostModel post;
  final double score;
  final Map<String, double> scoreBreakdown;

  const ScoredPost({
    required this.post,
    required this.score,
    this.scoreBreakdown = const {},
  });

  factory ScoredPost.fromMap(Map<String, dynamic> data, PostModel post) {
    return ScoredPost(
      post: post,
      score: (data['score'] ?? 0.0).toDouble(),
      scoreBreakdown: Map<String, double>.from(data['scoreBreakdown'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': post.id,
      'score': score,
      'scoreBreakdown': scoreBreakdown,
    };
  }
}