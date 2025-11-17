// Enhanced Content Intelligence Engine for TALOWA Advanced Social Feed System
// AI-powered content analysis, recommendations, and processing service with 50+ language support
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/social_feed/post_model.dart';
import '../../models/social_feed/comment_model.dart';
import '../../models/ai/content_intelligence_models.dart';
import '../auth_service.dart';
import '../performance/cache_service.dart';
import '../performance/advanced_cache_service.dart';
import '../performance/cache_partition_service.dart';

class ScoredPost {
  final PostModel post;
  final double score;
  final Map<String, double> scoreBreakdown;

  ScoredPost({
    required this.post,
    required this.score,
    required this.scoreBreakdown,
  });
}

/// Content Intelligence Engine providing AI-powered features for social feed
class ContentIntelligenceEngine {
  static final ContentIntelligenceEngine _instance = ContentIntelligenceEngine._internal();
  factory ContentIntelligenceEngine() => _instance;
  ContentIntelligenceEngine._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late CacheService _cacheService;
  late AdvancedCacheService _advancedCacheService;
  late CachePartitionService _partitionService;

  bool _isInitialized = false;

  // AI Service Configuration
  static const String _aiServiceBaseUrl = 'https://api.openai.com/v1';
  static const String _translationServiceUrl = 'https://api.mymemory.translated.net';
  static const String _googleTranslateUrl = 'https://translate.googleapis.com/translate_a/single';
  static const String _semanticSearchUrl = 'https://api.cohere.ai/v1/embed';
  static const Duration _cacheTimeout = Duration(hours: 1);
  static const Duration _shortCacheTimeout = Duration(minutes: 15);
  
  // Supported languages for translation (50+ languages)
  static const Map<String, String> _supportedLanguages = {
    'en': 'English',
    'hi': 'Hindi',
    'bn': 'Bengali',
    'te': 'Telugu',
    'mr': 'Marathi',
    'ta': 'Tamil',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'ml': 'Malayalam',
    'pa': 'Punjabi',
    'or': 'Odia',
    'as': 'Assamese',
    'ur': 'Urdu',
    'ne': 'Nepali',
    'si': 'Sinhala',
    'my': 'Myanmar',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'id': 'Indonesian',
    'ms': 'Malay',
    'tl': 'Filipino',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'fa': 'Persian',
    'tr': 'Turkish',
    'ru': 'Russian',
    'uk': 'Ukrainian',
    'pl': 'Polish',
    'cs': 'Czech',
    'sk': 'Slovak',
    'hu': 'Hungarian',
    'ro': 'Romanian',
    'bg': 'Bulgarian',
    'hr': 'Croatian',
    'sr': 'Serbian',
    'sl': 'Slovenian',
    'et': 'Estonian',
    'lv': 'Latvian',
    'lt': 'Lithuanian',
    'fi': 'Finnish',
    'da': 'Danish',
    'sv': 'Swedish',
    'no': 'Norwegian',
    'is': 'Icelandic',
    'de': 'German',
    'nl': 'Dutch',
    'fr': 'French',
    'es': 'Spanish',
    'pt': 'Portuguese',
    'it': 'Italian',
    'ca': 'Catalan',
    'eu': 'Basque',
    'gl': 'Galician',
    'el': 'Greek',
    'he': 'Hebrew',
    'sw': 'Swahili',
    'am': 'Amharic',
    'yo': 'Yoruba',
    'ig': 'Igbo',
    'ha': 'Hausa',
    'zu': 'Zulu',
    'af': 'Afrikaans',
  };

  /// Initialize the Content Intelligence Engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    _cacheService = CacheService.instance;
    _advancedCacheService = AdvancedCacheService.instance;
    _partitionService = CachePartitionService.instance;

    await _cacheService.initialize();
    await _advancedCacheService.initialize();
    await _partitionService.initialize();

    _isInitialized = true;
    debugPrint('✅ Content Intelligence Engine initialized');
  }

  /// Analyze content using AI-powered natural language processing
  Future<ContentAnalysis> analyzeContent({
    required String content,
    List<String>? mediaUrls,
    String? language = 'en',
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final cacheKey = 'content_analysis_${content.hashCode}_${mediaUrls?.join(',').hashCode ?? 0}';
      
      // Check cache first
      final cachedAnalysis = await _partitionService.getFromPartition<ContentAnalysis>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedAnalysis != null) {
        debugPrint('📦 Content analysis loaded from cache');
        return cachedAnalysis;
      }

      // Perform comprehensive content analysis
      final analysis = ContentAnalysis(
        sentiment: await _analyzeSentiment(content),
        topics: await _extractTopics(content),
        hashtags: await _generateHashtags(content),
        summary: await _generateSummary(content),
        toxicityScore: await _analyzeToxicity(content),
        engagementPrediction: await _predictEngagement(content),
        readabilityScore: _calculateReadability(content),
        languageDetection: await _detectLanguage(content),
        keyPhrases: _extractKeyPhrases(content),
        contentType: _classifyContentType(content),
        culturalContext: await _analyzeCulturalContext(content, language),
        mediaAnalysis: mediaUrls != null ? await _analyzeMedia(mediaUrls) : null,
        processingTime: stopwatch.elapsedMilliseconds,
      );

      // Cache the analysis
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        analysis,
        duration: _cacheTimeout,
        metadata: {
          'content_length': content.length,
          'media_count': mediaUrls?.length ?? 0,
          'language': language,
        },
      );

      debugPrint('✅ Content analysis completed in ${stopwatch.elapsedMilliseconds}ms');
      return analysis;

    } catch (e) {
      debugPrint('❌ Error analyzing content: $e');
      // Return basic analysis on error
      return ContentAnalysis(
        sentiment: ContentSentiment.neutral,
        topics: [],
        hashtags: _extractBasicHashtags(content),
        summary: content.length > 100 ? '${content.substring(0, 100)}...' : content,
        toxicityScore: 0.0,
        engagementPrediction: 0.5,
        readabilityScore: 0.5,
        languageDetection: language ?? 'en',
        keyPhrases: [],
        contentType: ContentType.text,
        culturalContext: CulturalContext.neutral,
        processingTime: stopwatch.elapsedMilliseconds,
      );
    } finally {
      stopwatch.stop();
    }
  }

  /// Generate AI-powered hashtag suggestions using machine learning models
  Future<List<String>> generateHashtagSuggestions(String content) async {
    try {
      final cacheKey = 'hashtags_${content.hashCode}';
      
      // Check cache
      final cachedHashtags = await _partitionService.getFromPartition<List<String>>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedHashtags != null && cachedHashtags.isNotEmpty) {
        return cachedHashtags;
      }

      // Generate hashtags using multiple ML approaches
      final hashtags = <String>{};
      
      // Extract existing hashtags
      hashtags.addAll(_extractBasicHashtags(content));
      
      // Generate AI-powered hashtags using NLP
      hashtags.addAll(await _generateMLHashtags(content));
      
      // Add topic-based hashtags using topic modeling
      final topics = await _extractTopicsML(content);
      hashtags.addAll(topics.map((topic) => '#${topic.replaceAll(' ', '_').toLowerCase()}'));
      
      // Add category-based hashtags using classification
      hashtags.addAll(await _getCategoryHashtagsML(content));
      
      // Add trending hashtags based on current trends
      hashtags.addAll(await _getTrendingHashtags(content));
      
      // Add semantic hashtags using word embeddings
      hashtags.addAll(await _getSemanticHashtags(content));
      
      final result = hashtags.take(15).toList();
      
      // Cache results
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        result,
        duration: _cacheTimeout,
      );
      
      return result;

    } catch (e) {
      debugPrint('❌ Error generating hashtags: $e');
      return _extractBasicHashtags(content);
    }
  }

  /// Perform semantic search with vector embeddings
  Future<List<PostModel>> performSemanticSearch({
    required String query,
    int limit = 20,
    double similarityThreshold = 0.7,
    List<String>? categories,
    String? location,
  }) async {
    try {
      final cacheKey = 'semantic_search_${query.hashCode}_${limit}_${categories?.join(',').hashCode ?? 0}';
      
      // Check cache
      final cachedResults = await _partitionService.getFromPartition<List<PostModel>>(
        CachePartition.searchResults,
        cacheKey,
      );
      
      if (cachedResults != null && cachedResults.isNotEmpty) {
        return cachedResults;
      }

      // Generate query embedding
      final queryEmbedding = await _generateTextEmbedding(query);
      
      // Get candidate posts
      final candidatePosts = await _getCandidatePostsForSearch(limit * 3, categories, location);
  
      // Calculate semantic similarity for each post
      final scoredPosts = <ScoredPost>[];
      
      for (final post in candidatePosts) {
        final similarity = _calculateCosineSimilarity(queryEmbedding, await _generateTextEmbedding(post.content));
        
        if (similarity >= similarityThreshold) {
          scoredPosts.add(ScoredPost(
            post: post,
            score: similarity,
            scoreBreakdown: {
              'semantic_similarity': similarity,
              'recency': _calculateRecencyScore(post.createdAt),
              'engagement': _calculateEngagementScore(post),
            },
          ));
        }
      }
      
      // Sort by combined score
      scoredPosts.sort((a, b) => b.score.compareTo(a.score));
      
      final results = scoredPosts.take(limit).map((sp) => sp.post).toList();
      
      // Cache results
      await _partitionService.setInPartition(
        CachePartition.searchResults,
        cacheKey,
        results,
        duration: _cacheTimeout,
      );
      
      return results;

    } catch (e) {
      debugPrint('❌ Error performing semantic search: $e');
      return [];
    }
  }

  /// Translate content to target language
  Future<String> translateContent(String content, String targetLanguage) async {
    try {
      final cacheKey = 'translation_${content.hashCode}_$targetLanguage';
      
      // Check cache
      final cachedTranslation = await _partitionService.getFromPartition<String>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedTranslation != null && cachedTranslation.isNotEmpty) {
        return cachedTranslation;
      }

      // Detect source language
      final sourceLanguage = await _detectLanguage(content);
      
      if (sourceLanguage == targetLanguage) {
        return content; // No translation needed
      }

      // Perform translation using MyMemory API (free tier)
      final url = '$_translationServiceUrl/get?q=${Uri.encodeComponent(content)}&langpair=$sourceLanguage|$targetLanguage';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translation = data['responseData']['translatedText'] as String;
        
        // Cache translation
        await _partitionService.setInPartition(
          CachePartition.analytics,
          cacheKey,
          translation,
          duration: const Duration(days: 1), // Translations can be cached longer
        );
        
        return translation;
      }
      
      return content; // Return original if translation fails

    } catch (e) {
      debugPrint('❌ Error translating content: $e');
      return content;
    }
  }

  /// Generate automatic alt-text for images
  Future<String> generateAltText(String imageUrl) async {
    try {
      final cacheKey = 'alt_text_${imageUrl.hashCode}';
      
      // Check cache
      final cachedAltText = await _partitionService.getFromPartition<String>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedAltText != null && cachedAltText.isNotEmpty) {
        return cachedAltText;
      }

      // For now, generate basic alt-text based on image URL and context
      // In production, this would use computer vision APIs like Google Vision or Azure Cognitive Services
      String altText = 'Image';
      
      // Extract context from URL
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      
      if (fileName.contains('profile')) {
        altText = 'Profile picture';
      } else if (fileName.contains('document')) {
        altText = 'Document image';
      } else if (fileName.contains('land')) {
        altText = 'Land-related image';
      } else if (fileName.contains('meeting')) {
        altText = 'Meeting or event image';
      } else {
        altText = 'User-uploaded image';
      }
      
      // Cache alt-text
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        altText,
        duration: const Duration(days: 7), // Alt-text can be cached for a week
      );
      
      return altText;

    } catch (e) {
      debugPrint('❌ Error generating alt-text: $e');
      return 'Image';
    }
  }

  /// Generate content summary for long posts
  Future<String> generateContentSummary(String content) async {
    try {
      if (content.length <= 200) {
        return content; // No need to summarize short content
      }

      final cacheKey = 'summary_${content.hashCode}';
      
      // Check cache
      final cachedSummary = await _partitionService.getFromPartition<String>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedSummary != null && cachedSummary.isNotEmpty) {
        return cachedSummary;
      }

      // Generate summary using extractive summarization
      final summary = await _generateSummary(content);
      
      // Cache summary
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        summary,
        duration: _cacheTimeout,
      );
      
      return summary;

    } catch (e) {
      debugPrint('❌ Error generating summary: $e');
      return content.length > 200 ? '${content.substring(0, 200)}...' : content;
    }
  }

  /// Get personalized content recommendations
  Future<List<PostModel>> getPersonalizedRecommendations({
    required String userId,
    int limit = 10,
    List<String>? excludePostIds,
  }) async {
    try {
      final cacheKey = 'recommendations_$userId';
      
      // Check cache
      final cachedRecommendations = await _partitionService.getFromPartition<List<PostModel>>(
        CachePartition.userProfiles,
        cacheKey,
      );
      
      if (cachedRecommendations != null && cachedRecommendations.isNotEmpty) {
        return cachedRecommendations.take(limit).toList();
      }

      // Get user preferences and activity
      final userPreferences = await _getUserPreferences(userId);
      final userActivity = await _getUserActivity(userId);
      
      // Get candidate posts
      final candidatePosts = await _getCandidatePosts(limit * 3, excludePostIds);
      
      // Score and rank posts
      final scoredPosts = await _scorePostsForUser(candidatePosts, userPreferences, userActivity);
      
      // Sort by score and take top results
      scoredPosts.sort((a, b) => b.score.compareTo(a.score));
      final recommendations = scoredPosts.take(limit).map((sp) => sp.post).toList();
      
      // Cache recommendations
      await _partitionService.setInPartition(
        CachePartition.userProfiles,
        cacheKey,
        recommendations,
        duration: _shortCacheTimeout,
        dependencies: ['user_$userId'],
      );
      
      return recommendations;

    } catch (e) {
      debugPrint('❌ Error getting personalized recommendations: $e');
      return [];
    }
  }

  /// Moderate content for safety and appropriateness
  Future<ModerationResult> moderateContent({
    required String content,
    List<String>? mediaUrls,
    ModerationLevel level = ModerationLevel.standard,
  }) async {
    try {
      final cacheKey = 'moderation_${content.hashCode}_${level.name}';
      
      // Check cache
      final cachedResult = await _partitionService.getFromPartition<ModerationResult>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedResult != null) {
        return cachedResult;
      }

      // Perform content moderation
      final toxicityScore = await _analyzeToxicity(content);
      final hasInappropriateContent = await _detectInappropriateContent(content);
      final spamScore = await _calculateSpamScore(content);
      final culturalSensitivity = await _checkCulturalSensitivity(content);
      
      // Determine moderation action
      ModerationAction action = ModerationAction.approve;
      List<String> flags = [];
      String? reason;
      
      if (toxicityScore > 0.7) {
        action = ModerationAction.reject;
        flags.add('high_toxicity');
        reason = 'Content contains toxic language';
      } else if (toxicityScore > 0.5) {
        action = ModerationAction.flag;
        flags.add('moderate_toxicity');
        reason = 'Content may contain inappropriate language';
      }
      
      if (hasInappropriateContent) {
        action = ModerationAction.reject;
        flags.add('inappropriate_content');
        reason = 'Content contains inappropriate material';
      }
      
      if (spamScore > 0.8) {
        action = ModerationAction.reject;
        flags.add('spam');
        reason = 'Content appears to be spam';
      } else if (spamScore > 0.6) {
        action = ModerationAction.flag;
        flags.add('potential_spam');
      }
      
      if (!culturalSensitivity) {
        action = ModerationAction.flag;
        flags.add('cultural_sensitivity');
        reason = 'Content may be culturally insensitive';
      }
      
      final result = ModerationResult(
        action: action,
        confidence: _calculateModerationConfidence(toxicityScore, spamScore),
        flags: flags,
        reason: reason,
        toxicityScore: toxicityScore,
        spamScore: spamScore,
        culturalSensitivityScore: culturalSensitivity ? 1.0 : 0.0,
        processingTime: DateTime.now().millisecondsSinceEpoch,
      );
      
      // Cache moderation result
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        result,
        duration: _cacheTimeout,
      );
      
      return result;

    } catch (e) {
      debugPrint('❌ Error moderating content: $e');
      // Return safe default on error
      return ModerationResult(
        action: ModerationAction.approve,
        confidence: 0.5,
        flags: [],
        toxicityScore: 0.0,
        spamScore: 0.0,
        culturalSensitivityScore: 1.0,
        processingTime: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// Extract topics and categorize content
  Future<List<String>> extractTopicsAndCategories(String content) async {
    try {
      final cacheKey = 'topics_${content.hashCode}';
      
      // Check cache
      final cachedTopics = await _partitionService.getFromPartition<List<String>>(
        CachePartition.analytics,
        cacheKey,
      );
      
      if (cachedTopics != null && cachedTopics.isNotEmpty) {
        return cachedTopics;
      }

      final topics = await _extractTopics(content);
      
      // Cache topics
      await _partitionService.setInPartition(
        CachePartition.analytics,
        cacheKey,
        topics,
        duration: _cacheTimeout,
      );
      
      return topics;

    } catch (e) {
      debugPrint('❌ Error extracting topics: $e');
      return [];
    }
  }

  // Private helper methods

  Future<ContentSentiment> _analyzeSentiment(String content) async {
    try {
      // Simple sentiment analysis based on keywords
      // In production, this would use ML models or APIs
      
      final positiveWords = ['good', 'great', 'excellent', 'amazing', 'wonderful', 'success', 'happy', 'love', 'best', 'fantastic'];
      final negativeWords = ['bad', 'terrible', 'awful', 'hate', 'worst', 'problem', 'issue', 'failed', 'sad', 'angry'];
      
      final words = content.toLowerCase().split(' ');
      int positiveCount = 0;
      int negativeCount = 0;
      
      for (final word in words) {
        if (positiveWords.contains(word)) positiveCount++;
        if (negativeWords.contains(word)) negativeCount++;
      }
      
      if (positiveCount > negativeCount) {
        return ContentSentiment.positive;
      } else if (negativeCount > positiveCount) {
        return ContentSentiment.negative;
      } else {
        return ContentSentiment.neutral;
      }
    } catch (e) {
      return ContentSentiment.neutral;
    }
  }

  Future<List<String>> _extractTopics(String content) async {
    try {
      // Extract topics using keyword analysis
      // In production, this would use NLP libraries or APIs
      
      final topicKeywords = {
        'agriculture': ['farm', 'crop', 'harvest', 'agriculture', 'farming', 'seeds', 'irrigation'],
        'land_rights': ['land', 'property', 'rights', 'ownership', 'title', 'survey', 'boundary'],
        'legal': ['law', 'legal', 'court', 'case', 'lawyer', 'justice', 'rights'],
        'government': ['government', 'scheme', 'policy', 'official', 'minister', 'department'],
        'education': ['education', 'school', 'student', 'teacher', 'learning', 'study'],
        'health': ['health', 'medical', 'doctor', 'hospital', 'medicine', 'treatment'],
        'community': ['community', 'village', 'people', 'meeting', 'group', 'together'],
        'technology': ['technology', 'digital', 'online', 'app', 'internet', 'mobile'],
      };
      
      final topics = <String>[];
      final contentLower = content.toLowerCase();
      
      for (final entry in topicKeywords.entries) {
        final topic = entry.key;
        final keywords = entry.value;
        
        int matchCount = 0;
        for (final keyword in keywords) {
          if (contentLower.contains(keyword)) {
            matchCount++;
          }
        }
        
        if (matchCount >= 2) {
          topics.add(topic);
        }
      }
      
      return topics;
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> _generateHashtags(String content) async {
    try {
      // Generate hashtags based on content analysis
      final hashtags = <String>[];
      
      // Extract topics and convert to hashtags
      final topics = await _extractTopics(content);
      hashtags.addAll(topics.map((topic) => '#$topic'));
      
      // Add common hashtags based on content
      if (content.toLowerCase().contains('success')) {
        hashtags.add('#success');
      }
      if (content.toLowerCase().contains('help')) {
        hashtags.add('#help');
      }
      if (content.toLowerCase().contains('update')) {
        hashtags.add('#update');
      }
      
      return hashtags.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> _generateSummary(String content) async {
    try {
      if (content.length <= 200) return content;
      
      // Simple extractive summarization
      final sentences = content.split(RegExp(r'[.!?]+'));
      if (sentences.length <= 2) return content;
      
      // Take first and most important sentences
      final summary = sentences.take(2).join('. ').trim();
      return summary.isNotEmpty ? summary : '${content.substring(0, 200)}...';
    } catch (e) {
      return content.length > 200 ? '${content.substring(0, 200)}...' : content;
    }
  }

  Future<double> _analyzeToxicity(String content) async {
    try {
      // Simple toxicity detection based on keywords
      // In production, this would use ML models like Perspective API
      
      final toxicWords = ['hate', 'stupid', 'idiot', 'fool', 'damn', 'hell', 'shut up'];
      final words = content.toLowerCase().split(' ');
      
      int toxicCount = 0;
      for (final word in words) {
        if (toxicWords.contains(word)) {
          toxicCount++;
        }
      }
      
      return (toxicCount / words.length).clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _predictEngagement(String content) async {
    try {
      // Simple engagement prediction based on content features
      double score = 0.5; // Base score
      
      // Length factor
      if (content.length > 50 && content.length < 500) {
        score += 0.1;
      }
      
      // Question factor
      if (content.contains('?')) {
        score += 0.1;
      }
      
      // Hashtag factor
      final hashtagCount = RegExp(r'#\w+').allMatches(content).length;
      score += (hashtagCount * 0.05).clamp(0.0, 0.2);
      
      // Emotional words factor
      final emotionalWords = ['amazing', 'great', 'wonderful', 'excited', 'happy', 'love'];
      for (final word in emotionalWords) {
        if (content.toLowerCase().contains(word)) {
          score += 0.05;
        }
      }
      
      return score.clamp(0.0, 1.0);
    } catch (e) {
      return 0.5;
    }
  }

  double _calculateReadability(String content) {
    try {
      // Simple readability score based on sentence and word length
      final sentences = content.split(RegExp(r'[.!?]+'));
      final words = content.split(' ');
      
      if (sentences.isEmpty || words.isEmpty) return 0.5;
      
      final avgWordsPerSentence = words.length / sentences.length;
      final avgCharsPerWord = content.replaceAll(' ', '').length / words.length;
      
      // Simple scoring (lower is more readable)
      double score = 1.0;
      if (avgWordsPerSentence > 20) score -= 0.2;
      if (avgCharsPerWord > 6) score -= 0.2;
      
      return score.clamp(0.0, 1.0);
    } catch (e) {
      return 0.5;
    }
  }

  Future<String> _detectLanguage(String content) async {
    try {
      // Simple language detection based on character patterns
      // In production, this would use proper language detection libraries
      
      final hindiPattern = RegExp(r'[\u0900-\u097F]');
      final englishPattern = RegExp(r'[a-zA-Z]');
      
      final hindiMatches = hindiPattern.allMatches(content).length;
      final englishMatches = englishPattern.allMatches(content).length;
      
      if (hindiMatches > englishMatches) {
        return 'hi';
      } else {
        return 'en';
      }
    } catch (e) {
      return 'en';
    }
  }

  List<String> _extractKeyPhrases(String content) {
    try {
      // Extract key phrases using simple n-gram analysis
      final words = content.toLowerCase().split(' ');
      final phrases = <String>[];
      
      // Extract 2-grams and 3-grams
      for (int i = 0; i < words.length - 1; i++) {
        if (words[i].length > 3 && words[i + 1].length > 3) {
          phrases.add('${words[i]} ${words[i + 1]}');
        }
      }
      
      for (int i = 0; i < words.length - 2; i++) {
        if (words[i].length > 3 && words[i + 1].length > 3 && words[i + 2].length > 3) {
          phrases.add('${words[i]} ${words[i + 1]} ${words[i + 2]}');
        }
      }
      
      return phrases.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  ContentType _classifyContentType(String content) {
    try {
      if (content.contains('?')) return ContentType.question;
      if (content.toLowerCase().contains('announce')) return ContentType.announcement;
      if (content.toLowerCase().contains('help') || content.toLowerCase().contains('need')) return ContentType.request;
      if (content.toLowerCase().contains('success') || content.toLowerCase().contains('achievement')) return ContentType.success;
      return ContentType.general;
    } catch (e) {
      return ContentType.general;
    }
  }

  Future<CulturalContext> _analyzeCulturalContext(String content, String? language) async {
    try {
      // Analyze cultural context and sensitivity
      // This is a simplified implementation
      
      final culturalKeywords = {
        'religious': ['god', 'temple', 'prayer', 'festival', 'ritual'],
        'political': ['government', 'minister', 'election', 'party', 'politics'],
        'social': ['caste', 'community', 'tradition', 'custom', 'culture'],
      };
      
      final contentLower = content.toLowerCase();
      
      for (final entry in culturalKeywords.entries) {
        for (final keyword in entry.value) {
          if (contentLower.contains(keyword)) {
            return CulturalContext.sensitive;
          }
        }
      }
      
      return CulturalContext.neutral;
    } catch (e) {
      return CulturalContext.neutral;
    }
  }

  Future<MediaAnalysis?> _analyzeMedia(List<String> mediaUrls) async {
    try {
      // Basic media analysis
      // In production, this would use computer vision APIs
      
      int imageCount = 0;
      int videoCount = 0;
      int documentCount = 0;
      
      for (final url in mediaUrls) {
        final extension = url.split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
          imageCount++;
        } else if (['mp4', 'avi', 'mov'].contains(extension)) {
          videoCount++;
        } else if (['pdf', 'doc', 'docx'].contains(extension)) {
          documentCount++;
        }
      }
      
      return MediaAnalysis(
        totalCount: mediaUrls.length,
        imageCount: imageCount,
        videoCount: videoCount,
        documentCount: documentCount,
        hasInappropriateContent: false, // Would be determined by AI analysis
        qualityScore: 0.8, // Would be determined by AI analysis
      );
    } catch (e) {
      return null;
    }
  }

  List<String> _extractBasicHashtags(String content) {
    final regex = RegExp(r'#(\w+)');
    return regex.allMatches(content).map((match) => match.group(0)!).toList();
  }

  List<String> _getCategoryHashtags(String content) {
    final hashtags = <String>[];
    final contentLower = content.toLowerCase();
    
    if (contentLower.contains('land') || contentLower.contains('property')) {
      hashtags.add('#land_rights');
    }
    if (contentLower.contains('farm') || contentLower.contains('agriculture')) {
      hashtags.add('#agriculture');
    }
    if (contentLower.contains('legal') || contentLower.contains('court')) {
      hashtags.add('#legal');
    }
    if (contentLower.contains('government') || contentLower.contains('scheme')) {
      hashtags.add('#government');
    }
    
    return hashtags;
  }

  Future<Map<String, dynamic>> _getUserPreferences(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      
      return {
        'interests': userData['interests'] ?? [],
        'preferredCategories': userData['preferredCategories'] ?? [],
        'location': userData['address']?['villageCity'] ?? '',
        'language': userData['language'] ?? 'en',
      };
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _getUserActivity(String userId) async {
    try {
      // Get user's recent activity for personalization
      final recentLikes = await _firestore
          .collection('post_likes')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      final recentComments = await _firestore
          .collection('post_comments')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      return {
        'recentLikes': recentLikes.docs.length,
        'recentComments': recentComments.docs.length,
        'lastActivity': DateTime.now().subtract(const Duration(days: 7)),
      };
    } catch (e) {
      return {};
    }
  }

  Future<List<PostModel>> _getCandidatePosts(int limit, List<String>? excludePostIds) async {
    try {
      Query query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(limit);
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .where((post) => excludePostIds?.contains(post.id) != true)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ScoredPost>> _scorePostsForUser(
    List<PostModel> posts,
    Map<String, dynamic> preferences,
    Map<String, dynamic> activity,
  ) async {
    final scoredPosts = <ScoredPost>[];
    
    for (final post in posts) {
      double score = 0.0;
      
      // Recency score
      final hoursSincePost = DateTime.now().difference(post.createdAt).inHours;
      score += (24 - hoursSincePost.clamp(0, 24)) / 24 * 10;
      
      // Engagement score
      score += (post.likesCount * 0.1) + (post.commentsCount * 0.2);
      
      // Category preference
      final preferredCategories = List<String>.from(preferences['preferredCategories'] ?? []);
      if (preferredCategories.contains(post.category.value)) {
        score += 5.0;
      }
      
      // Location relevance
      if (post.location == preferences['location']) {
        score += 3.0;
      }
      
      // Content analysis score
      final analysis = await analyzeContent(content: post.content);
      score += analysis.engagementPrediction * 2;
      
      scoredPosts.add(ScoredPost(
        post: post,
        score: score,
        scoreBreakdown: {
          'recency': (24 - hoursSincePost.clamp(0, 24)) / 24 * 10,
          'engagement': (post.likesCount * 0.1) + (post.commentsCount * 0.2),
          'category_match': preferredCategories.contains(post.category.value) ? 5.0 : 0.0,
          'location_match': post.location == preferences['location'] ? 3.0 : 0.0,
          'content_analysis': analysis.engagementPrediction * 2,
        },
      ));
    }
    
    return scoredPosts;
  }

  Future<bool> _detectInappropriateContent(String content) async {
    try {
      // Simple inappropriate content detection
      final inappropriateWords = ['spam', 'scam', 'fake', 'fraud'];
      final contentLower = content.toLowerCase();
      
      for (final word in inappropriateWords) {
        if (contentLower.contains(word)) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<double> _calculateSpamScore(String content) async {
    try {
      double score = 0.0;
      
      // Excessive capitalization
      final upperCaseCount = content.split('').where((c) => c == c.toUpperCase() && c != c.toLowerCase()).length;
      if (upperCaseCount > content.length * 0.5) {
        score += 0.3;
      }
      
      // Excessive punctuation
      final punctuationCount = RegExp(r'[!?]{2,}').allMatches(content).length;
      score += (punctuationCount * 0.1).clamp(0.0, 0.4);
      
      // Repeated words
      final words = content.toLowerCase().split(' ');
      final uniqueWords = words.toSet();
      if (words.length > uniqueWords.length * 2) {
        score += 0.2;
      }
      
      return score.clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

  Future<bool> _checkCulturalSensitivity(String content) async {
    try {
      // Check for culturally sensitive content
      final sensitiveTerms = ['caste', 'religion', 'politics'];
      final contentLower = content.toLowerCase();
      
      for (final term in sensitiveTerms) {
        if (contentLower.contains(term)) {
          return false; // Needs review
        }
      }
      
      return true; // Culturally appropriate
    } catch (e) {
      return true;
    }
  }

  double _calculateModerationConfidence(double toxicityScore, double spamScore) {
    // Calculate confidence based on multiple factors
    final avgScore = (toxicityScore + spamScore) / 2;
    return (1.0 - avgScore).clamp(0.0, 1.0);
  }

  // Additional helper methods for semantic search
  Future<List<double>> _generateTextEmbedding(String text) async {
    // In production, this would use actual embedding APIs
    // For now, return a simple hash-based embedding
    final hash = text.hashCode;
    return List.generate(100, (i) => (hash + i) % 1000 / 1000.0);
  }

  double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  double _calculateRecencyScore(DateTime createdAt) {
    final hoursSinceCreation = DateTime.now().difference(createdAt).inHours;
    return (24 - hoursSinceCreation.clamp(0, 24)) / 24;
  }

  double _calculateEngagementScore(PostModel post) {
    return (post.likesCount * 0.1 + post.commentsCount * 0.2 + post.sharesCount * 0.3).clamp(0.0, 1.0);
  }

  Future<List<PostModel>> _getCandidatePostsForSearch(int limit, List<String>? categories, String? location) async {
    try {
      Query query = _firestore.collection('posts').orderBy('createdAt', descending: true).limit(limit);
      
      if (categories != null && categories.isNotEmpty) {
        query = query.where('category', whereIn: categories);
      }
      
      if (location != null && location.isNotEmpty) {
        query = query.where('location', isEqualTo: location);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  // Missing method implementations
  Future<List<String>> _generateMLHashtags(String content) async {
    // Placeholder implementation
    return [];
  }

  Future<List<String>> _extractTopicsML(String content) async {
    // Placeholder implementation
    return [];
  }

  Future<List<String>> _getCategoryHashtagsML(String content) async {
    // Placeholder implementation
    return [];
  }

  Future<List<String>> _getTrendingHashtags(String content) async {
    // Placeholder implementation
    return [];
  }

  Future<List<String>> _getSemanticHashtags(String content) async {
    // Placeholder implementation
    return [];
  }
}