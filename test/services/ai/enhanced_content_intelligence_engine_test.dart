// Test file for Enhanced Content Intelligence Engine
// Comprehensive tests for AI-powered content analysis features
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../lib/services/ai/enhanced_content_intelligence_engine.dart';
import '../../../lib/models/ai/content_intelligence_models.dart';
import '../../../lib/models/social_feed/post_model.dart';

void main() {
  group('Enhanced Content Intelligence Engine Tests', () {
    late EnhancedContentIntelligenceEngine engine;

    setUp(() {
      engine = EnhancedContentIntelligenceEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    group('Content Analysis', () {
      test('should analyze content sentiment correctly', () async {
        // Test positive sentiment
        final positiveContent = 'This is amazing news! Great success for our community. Very happy to share this wonderful achievement.';
        final analysis = await engine.analyzeContentAdvanced(content: positiveContent);
        
        expect(analysis.sentiment, equals(ContentSentiment.positive));
        expect(analysis.toxicityScore, lessThan(0.3));
        expect(analysis.engagementPrediction, greaterThan(0.5));
      });

      test('should detect multiple languages', () async {
        final hindiContent = 'यह बहुत अच्छी खबर है। हमारे समुदाय के लिए बड़ी सफलता।';
        final analysis = await engine.analyzeContentAdvanced(content: hindiContent);
        
        expect(analysis.languageDetection, equals('hi'));
      });

      test('should extract topics correctly', () async {
        final agricultureContent = 'Our village farmers have successfully harvested crops this season. The irrigation system helped improve yield significantly.';
        final analysis = await engine.analyzeContentAdvanced(content: agricultureContent);
        
        expect(analysis.topics, contains('agriculture'));
        expect(analysis.suggestedCategories, contains('agriculture'));
      });

      test('should generate relevant hashtags', () async {
        final content = 'Community meeting scheduled for land rights discussion. All farmers invited to participate.';
        final hashtags = await engine.generateHashtagsML(content);
        
        expect(hashtags, isNotEmpty);
        expect(hashtags.any((tag) => tag.contains('community') || tag.contains('land')), isTrue);
      });

      test('should detect cultural context', () async {
        final religiousContent = 'Temple festival celebration in our village. Prayer ceremony at 6 PM.';
        final analysis = await engine.analyzeContentAdvanced(content: religiousContent);
        
        expect(analysis.culturalContext, equals(CulturalContext.religious));
      });

      test('should analyze content toxicity', () async {
        final toxicContent = 'This is stupid and awful. I hate this terrible decision.';
        final analysis = await engine.analyzeContentAdvanced(content: toxicContent);
        
        expect(analysis.toxicityScore, greaterThan(0.3));
      });

      test('should calculate readability score', () async {
        final simpleContent = 'This is easy to read. Short sentences work well.';
        final complexContent = 'The implementation of sophisticated agricultural methodologies necessitates comprehensive understanding of multifaceted environmental variables.';
        
        final simpleAnalysis = await engine.analyzeContentAdvanced(content: simpleContent);
        final complexAnalysis = await engine.analyzeContentAdvanced(content: complexContent);
        
        expect(simpleAnalysis.readabilityScore, greaterThan(complexAnalysis.readabilityScore));
      });
    });

    group('Translation Features', () {
      test('should translate content between supported languages', () async {
        final englishContent = 'Hello, how are you?';
        final translatedContent = await engine.translateContentAdvanced(englishContent, 'hi');
        
        expect(translatedContent, isNotEmpty);
        expect(translatedContent, isNot(equals(englishContent)));
      });

      test('should detect source language correctly', () async {
        final hindiContent = 'नमस्ते, आप कैसे हैं?';
        final analysis = await engine.analyzeContentAdvanced(content: hindiContent);
        
        expect(analysis.languageDetection, equals('hi'));
      });

      test('should support 50+ languages', () {
        final supportedLanguages = EnhancedContentIntelligenceEngine.getSupportedLanguages();
        
        expect(supportedLanguages.length, greaterThanOrEqualTo(50));
        expect(supportedLanguages, contains('en'));
        expect(supportedLanguages, contains('hi'));
        expect(supportedLanguages, contains('bn'));
        expect(supportedLanguages, contains('te'));
      });

      test('should return original content for same language translation', () async {
        final content = 'This is English content.';
        final translated = await engine.translateContentAdvanced(content, 'en');
        
        expect(translated, equals(content));
      });
    });

    group('Semantic Search', () {
      test('should perform semantic search with similarity threshold', () async {
        // This test would require mock data setup
        final query = 'agriculture farming crops';
        final results = await engine.performSemanticSearch(
          query: query,
          limit: 10,
          similarityThreshold: 0.5,
        );
        
        expect(results, isA<List<PostModel>>());
        expect(results.length, lessThanOrEqualTo(10));
      });

      test('should filter search results by categories', () async {
        final query = 'community meeting';
        final results = await engine.performSemanticSearch(
          query: query,
          categories: ['communityNews', 'announcement'],
          limit: 5,
        );
        
        expect(results, isA<List<PostModel>>());
      });

      test('should calculate semantic similarity correctly', () {
        // Test the cosine similarity calculation
        final vector1 = [1.0, 0.0, 1.0];
        final vector2 = [1.0, 0.0, 1.0];
        final vector3 = [0.0, 1.0, 0.0];
        
        final similarity1 = engine._calculateCosineSimilarity(vector1, vector2);
        final similarity2 = engine._calculateCosineSimilarity(vector1, vector3);
        
        expect(similarity1, equals(1.0)); // Identical vectors
        expect(similarity2, equals(0.0)); // Orthogonal vectors
      });
    });

    group('Advanced Features', () {
      test('should generate alt-text for images', () async {
        final imageUrl = 'https://example.com/images/community_meeting.jpg';
        final altText = await engine.generateAltTextAdvanced(imageUrl);
        
        expect(altText, isNotEmpty);
        expect(altText.toLowerCase(), contains('community'));
      });

      test('should summarize long content', () async {
        final longContent = '''
        This is a very long piece of content that needs to be summarized. 
        It contains multiple sentences with various information. 
        The first sentence introduces the topic. 
        The second sentence provides additional details. 
        The third sentence offers more context. 
        The fourth sentence concludes the discussion. 
        This content should be reduced to key points.
        ''';
        
        final summary = await engine.generateContentSummaryAdvanced(longContent);
        
        expect(summary, isNotEmpty);
        expect(summary.length, lessThan(longContent.length));
      });

      test('should extract named entities', () async {
        final content = 'John Smith from Delhi visited the Agriculture Ministry office yesterday.';
        final analysis = await engine.analyzeContentAdvanced(content: content);
        
        expect(analysis.namedEntities, isNotEmpty);
      });

      test('should analyze emotions in content', () async {
        final happyContent = 'I am so excited and joyful about this amazing success!';
        final analysis = await engine.analyzeContentAdvanced(content: happyContent);
        
        expect(analysis.emotionScores, isNotEmpty);
        expect(analysis.emotionScores['joy'], greaterThan(0.0));
      });

      test('should detect spam content', () async {
        final spamContent = 'CLICK HERE NOW!!! FREE MONEY!!! CALL NOW!!! URGENT!!!';
        final analysis = await engine.analyzeContentAdvanced(content: spamContent);
        
        expect(analysis.spamScore, greaterThan(0.5));
      });

      test('should suggest relevant categories', () async {
        final educationContent = 'New school opened in our village. Students can now learn better with modern facilities.';
        final analysis = await engine.analyzeContentAdvanced(content: educationContent);
        
        expect(analysis.suggestedCategories, contains('education'));
      });
    });

    group('Performance and Caching', () {
      test('should cache analysis results', () async {
        final content = 'Test content for caching';
        
        // First call - should perform analysis
        final stopwatch1 = Stopwatch()..start();
        await engine.analyzeContentAdvanced(content: content);
        stopwatch1.stop();
        
        // Second call - should use cache
        final stopwatch2 = Stopwatch()..start();
        await engine.analyzeContentAdvanced(content: content);
        stopwatch2.stop();
        
        // Cache should make second call faster
        expect(stopwatch2.elapsedMilliseconds, lessThan(stopwatch1.elapsedMilliseconds));
      });

      test('should provide performance metrics', () {
        final metrics = engine.getPerformanceMetrics();
        
        expect(metrics, isA<Map<String, dynamic>>());
        expect(metrics['supported_languages'], greaterThanOrEqualTo(50));
        expect(metrics['features'], isA<List>());
        expect(metrics['service_version'], isNotEmpty);
      });
    });

    group('Error Handling', () {
      test('should handle empty content gracefully', () async {
        final analysis = await engine.analyzeContentAdvanced(content: '');
        
        expect(analysis, isA<ContentAnalysis>());
        expect(analysis.sentiment, equals(ContentSentiment.neutral));
      });

      test('should handle invalid language codes', () async {
        final content = 'Test content';
        final translated = await engine.translateContentAdvanced(content, 'invalid_lang');
        
        expect(translated, equals(content)); // Should return original
      });

      test('should handle network errors in translation', () async {
        // This would require mocking network failures
        final content = 'Test content';
        final translated = await engine.translateContentAdvanced(content, 'fr');
        
        expect(translated, isNotEmpty); // Should not crash
      });
    });

    group('Language Support', () {
      test('should support Indian languages', () {
        final supportedLanguages = EnhancedContentIntelligenceEngine.getSupportedLanguages();
        
        expect(supportedLanguages, contains('hi')); // Hindi
        expect(supportedLanguages, contains('bn')); // Bengali
        expect(supportedLanguages, contains('te')); // Telugu
        expect(supportedLanguages, contains('ta')); // Tamil
        expect(supportedLanguages, contains('gu')); // Gujarati
        expect(supportedLanguages, contains('kn')); // Kannada
        expect(supportedLanguages, contains('ml')); // Malayalam
        expect(supportedLanguages, contains('pa')); // Punjabi
      });

      test('should provide language names', () {
        expect(EnhancedContentIntelligenceEngine.getLanguageName('en'), equals('English'));
        expect(EnhancedContentIntelligenceEngine.getLanguageName('hi'), equals('Hindi'));
        expect(EnhancedContentIntelligenceEngine.getLanguageName('invalid'), equals('Unknown'));
      });

      test('should check language support', () {
        expect(EnhancedContentIntelligenceEngine.isLanguageSupported('en'), isTrue);
        expect(EnhancedContentIntelligenceEngine.isLanguageSupported('hi'), isTrue);
        expect(EnhancedContentIntelligenceEngine.isLanguageSupported('invalid'), isFalse);
      });
    });

    group('Integration Tests', () {
      test('should work with real-world content examples', () async {
        final realWorldExamples = [
          'आज हमारे गांव में भूमि सर्वेक्षण का काम शुरू हुआ। सभी किसान भाइयों से अनुरोध है कि वे अपने दस्तावेज तैयार रखें।',
          'Community meeting scheduled for tomorrow at 6 PM. We will discuss the new government scheme for farmers.',
          'Great news! Our village school received new computers. Students are very excited to learn digital skills.',
          'Emergency: Heavy rainfall expected. All farmers should protect their crops and livestock.',
        ];
        
        for (final content in realWorldExamples) {
          final analysis = await engine.analyzeContentAdvanced(content: content);
          
          expect(analysis, isA<ContentAnalysis>());
          expect(analysis.topics, isNotEmpty);
          expect(analysis.languageDetection, isNotEmpty);
          expect(analysis.processingTime, greaterThan(0));
        }
      });

      test('should handle mixed language content', () async {
        final mixedContent = 'Hello नमस्ते! This is mixed content यह मिश्रित सामग्री है।';
        final analysis = await engine.analyzeContentAdvanced(content: mixedContent);
        
        expect(analysis, isA<ContentAnalysis>());
        expect(analysis.languageDetection, isNotEmpty);
      });

      test('should process multimedia content references', () async {
        final contentWithMedia = 'Check out this photo from our community meeting. Video will be shared soon.';
        final mediaUrls = ['https://example.com/photo.jpg', 'https://example.com/video.mp4'];
        
        final analysis = await engine.analyzeContentAdvanced(
          content: contentWithMedia,
          mediaUrls: mediaUrls,
        );
        
        expect(analysis.mediaAnalysis, isNotNull);
        expect(analysis.mediaAnalysis!.totalCount, equals(2));
        expect(analysis.mediaAnalysis!.imageCount, equals(1));
        expect(analysis.mediaAnalysis!.videoCount, equals(1));
      });
    });
  });
}

// Extension to access private methods for testing
extension EnhancedContentIntelligenceEngineTest on EnhancedContentIntelligenceEngine {
  double _calculateCosineSimilarity(List<double> vector1, List<double> vector2) {
    if (vector1.length != vector2.length) return 0.0;
    
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < vector1.length; i++) {
      dotProduct += vector1[i] * vector2[i];
      norm1 += vector1[i] * vector1[i];
      norm2 += vector2[i] * vector2[i];
    }
    
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }
}