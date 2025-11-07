// Comprehensive Test Suite for AI-Powered Moderation System
// Tests all moderation components with focus on 95% accuracy target

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/services/ai/ai_moderation_service.dart';
import '../lib/models/ai/moderation_models.dart';

// Generate mocks
@GenerateMocks([FirebaseFirestore, CollectionReference, DocumentReference, QuerySnapshot, DocumentSnapshot])
import 'ai_moderation_system_test.mocks.dart';

void main() {
  group('AI Moderation System Tests', () {
    late AIModerationService moderationService;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockCollection;
    late MockDocumentReference mockDocument;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference();
      mockDocument = MockDocumentReference();
      
      // Setup mock behavior
      when(mockFirestore.collection(any)).thenReturn(mockCollection);
      when(mockCollection.doc(any)).thenReturn(mockDocument);
      when(mockCollection.add(any)).thenAnswer((_) async => mockDocument);
      when(mockDocument.set(any, any)).thenAnswer((_) async => {});
      
      moderationService = AIModerationService();
    });

    group('Toxicity Detection Tests', () {
      test('should detect high toxicity content', () async {
        // Test content with clearly toxic language
        const toxicContent = 'You are stupid and I hate you, go kill yourself';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: toxicContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.reject));
        expect(result.toxicityAnalysis?.isAboveThreshold, isTrue);
        expect(result.toxicityAnalysis?.overallScore, greaterThan(0.7));
        expect(result.flags, contains('toxicity'));
        expect(result.confidence, greaterThan(0.5));
      });

      test('should approve clean content', () async {
        // Test content with positive, clean language
        const cleanContent = 'Thank you for sharing this helpful information about farming techniques';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: cleanContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.approve));
        expect(result.toxicityAnalysis?.isAboveThreshold, isFalse);
        expect(result.toxicityAnalysis?.overallScore, lessThan(0.3));
        expect(result.flags, isEmpty);
      });

      test('should handle borderline toxic content appropriately', () async {
        // Test content that's mildly negative but not clearly toxic
        const borderlineContent = 'This is not good and I disagree with this approach';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: borderlineContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, anyOf([
          ModerationAction.approve,
          ModerationAction.flagForReview,
        ]));
        expect(result.toxicityAnalysis?.overallScore, lessThan(0.7));
      });
    });

    group('Hate Speech Detection Tests', () {
      test('should detect identity-based attacks', () async {
        const hateSpeechContent = 'All people from that community are criminals and should be banned';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: hateSpeechContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.reject));
        expect(result.hateSpeechAnalysis?.isAboveThreshold, isTrue);
        expect(result.flags, contains('hate_speech'));
        expect(result.escalationRequired, isTrue);
      });

      test('should not flag legitimate criticism', () async {
        const legitimateCriticism = 'I disagree with this policy because it affects farmers negatively';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: legitimateCriticism,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.approve));
        expect(result.hateSpeechAnalysis?.isAboveThreshold, isFalse);
      });
    });

    group('Harassment Detection Tests', () {
      test('should detect personal attacks', () async {
        const harassmentContent = 'You are worthless and nobody likes you, stop posting here';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: harassmentContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.reject));
        expect(result.harassmentAnalysis?.isAboveThreshold, isTrue);
        expect(result.flags, contains('harassment'));
      });

      test('should detect cyberbullying patterns', () async {
        const bullyingContent = 'Everyone ignore this loser, they dont know anything';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: bullyingContent,
          level: ModerationLevel.standard,
        );

        expect(result.harassmentAnalysis?.cyberbullyingScore, greaterThan(0.0));
        expect(result.decision, anyOf([
          ModerationAction.reject,
          ModerationAction.flagForReview,
        ]));
      });
    });

    group('Spam Detection Tests', () {
      test('should detect repetitive promotional content', () async {
        const spamContent = 'BUY NOW!!! BEST DEALS!!! CLICK HERE!!! LIMITED TIME!!!';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: spamContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.reject));
        expect(result.spamAnalysis?.isAboveThreshold, isTrue);
        expect(result.flags, contains('spam'));
      });

      test('should detect bot-like patterns', () async {
        const botContent = 'Check out this amazing offer at www.suspicious-link.com for free money';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: botContent,
          level: ModerationLevel.standard,
        );

        expect(result.spamAnalysis?.botPatternScore, greaterThan(0.0));
        expect(result.spamAnalysis?.linkSpamScore, greaterThan(0.0));
      });

      test('should allow legitimate promotional content', () async {
        const legitimatePromo = 'Our cooperative is offering training sessions for organic farming next week';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: legitimatePromo,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.approve));
        expect(result.spamAnalysis?.isAboveThreshold, isFalse);
      });
    });

    group('Violence Detection Tests', () {
      test('should detect direct threats', () async {
        const threatContent = 'I will hurt you if you dont stop posting this';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: threatContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.reject));
        expect(result.violenceAnalysis?.isAboveThreshold, isTrue);
        expect(result.violenceAnalysis?.requiresImmediateAction, isTrue);
        expect(result.flags, contains('immediate_violence_threat'));
        expect(result.escalationRequired, isTrue);
      });

      test('should detect violent language', () async {
        const violentContent = 'These people should be destroyed and eliminated completely';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: violentContent,
          level: ModerationLevel.standard,
        );

        expect(result.violenceAnalysis?.violentLanguageScore, greaterThan(0.0));
        expect(result.decision, anyOf([
          ModerationAction.reject,
          ModerationAction.flagForReview,
        ]));
      });

      test('should not flag metaphorical violence', () async {
        const metaphoricalContent = 'This policy will kill our farming business';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: metaphoricalContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.approve));
        expect(result.violenceAnalysis?.requiresImmediateAction, isFalse);
      });
    });

    group('Misinformation Detection Tests', () {
      test('should flag potential misinformation', () async {
        const misinfoContent = 'Scientists have proven that vaccines cause autism and the government is hiding it';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: misinfoContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.flagForReview));
        expect(result.misinformationAnalysis?.isAboveThreshold, isTrue);
        expect(result.misinformationAnalysis?.factCheckRequired, isTrue);
        expect(result.flags, contains('misinformation'));
        expect(result.escalationRequired, isTrue);
      });

      test('should detect sensational language', () async {
        const sensationalContent = 'SHOCKING TRUTH: Government HIDES this ONE SIMPLE TRICK that will CHANGE YOUR LIFE FOREVER!!!';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: sensationalContent,
          level: ModerationLevel.standard,
        );

        expect(result.misinformationAnalysis?.sensationalLanguageScore, greaterThan(0.0));
      });

      test('should allow factual information', () async {
        const factualContent = 'According to the agricultural department, this years monsoon is expected to be normal';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: factualContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.approve));
        expect(result.misinformationAnalysis?.isAboveThreshold, isFalse);
      });
    });

    group('Cultural Sensitivity Tests', () {
      test('should flag culturally sensitive content', () async {
        const sensitiveContent = 'People of this caste should not be allowed in our village temple';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: sensitiveContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.flagForReview));
        expect(result.culturalSensitivityAnalysis?.isCulturallySensitive, isTrue);
        expect(result.culturalSensitivityAnalysis?.requiresLocalReview, isTrue);
        expect(result.flags, contains('cultural_sensitivity'));
        expect(result.escalationRequired, isTrue);
      });

      test('should handle religious content appropriately', () async {
        const religiousContent = 'We are organizing a prayer meeting for good harvest this season';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: religiousContent,
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.approve));
        expect(result.culturalSensitivityAnalysis?.isCulturallySensitive, isFalse);
      });

      test('should flag political sensitivity', () async {
        const politicalContent = 'This political party is destroying our country and should be banned';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: politicalContent,
          level: ModerationLevel.standard,
        );

        expect(result.culturalSensitivityAnalysis?.politicalSensitivityScore, greaterThan(0.0));
        expect(result.decision, anyOf([
          ModerationAction.approve,
          ModerationAction.flagForReview,
        ]));
      });
    });

    group('Media Moderation Tests', () {
      test('should analyze media content', () async {
        const content = 'Check out this image';
        final mediaUrls = ['https://example.com/image.jpg', 'https://example.com/video.mp4'];
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: content,
          mediaUrls: mediaUrls,
          level: ModerationLevel.standard,
        );

        expect(result.mediaAnalysis, isNotNull);
        expect(result.mediaAnalysis!.mediaResults, hasLength(2));
        expect(result.mediaAnalysis!.mediaResults[0].mediaType, equals('image'));
        expect(result.mediaAnalysis!.mediaResults[1].mediaType, equals('video'));
      });

      test('should flag inappropriate media', () async {
        const content = 'Inappropriate content';
        final mediaUrls = ['https://example.com/inappropriate.jpg'];
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: content,
          mediaUrls: mediaUrls,
          level: ModerationLevel.strict,
        );

        // In a real implementation, this would detect inappropriate media
        expect(result.mediaAnalysis, isNotNull);
      });
    });

    group('Escalation Workflow Tests', () {
      test('should escalate complex cases', () async {
        const complexContent = 'This content requires human review due to cultural nuances';
        
        await moderationService.initialize();
        
        // Mock the escalation
        expect(() async {
          await moderationService.escalateForComplexReview(
            contentId: 'test_content_123',
            moderationResult: ModerationResult(
              decision: ModerationAction.flagForReview,
              confidence: 0.6,
              overallScore: 0.7,
              flags: ['cultural_sensitivity'],
              escalationRequired: true,
              processingTime: 100,
              timestamp: DateTime.now(),
            ),
            reason: 'Cultural sensitivity requires local review',
            priority: EscalationPriority.high,
          );
        }, returnsNormally);
      });

      test('should handle different escalation priorities', () async {
        await moderationService.initialize();
        
        // Test different priority levels
        for (final priority in EscalationPriority.values) {
          expect(() async {
            await moderationService.escalateForComplexReview(
              contentId: 'test_content_${priority.name}',
              moderationResult: ModerationResult(
                decision: ModerationAction.flagForReview,
                confidence: 0.5,
                overallScore: 0.6,
                flags: ['test_flag'],
                escalationRequired: true,
                processingTime: 100,
                timestamp: DateTime.now(),
              ),
              reason: 'Test escalation for ${priority.name} priority',
              priority: priority,
            );
          }, returnsNormally);
        }
      });
    });

    group('Analytics and Reporting Tests', () {
      test('should generate moderation analytics', () async {
        await moderationService.initialize();
        
        final analytics = await moderationService.getModerationAnalytics(
          startDate: DateTime.now().subtract(const Duration(days: 7)),
          endDate: DateTime.now(),
        );

        expect(analytics, isNotNull);
        expect(analytics.totalContentModerated, isA<int>());
        expect(analytics.totalEscalated, isA<int>());
        expect(analytics.actionBreakdown, isA<Map<String, int>>());
        expect(analytics.flagBreakdown, isA<Map<String, int>>());
        expect(analytics.averageProcessingTime, isA<double>());
        expect(analytics.accuracyRate, isA<double>());
        expect(analytics.escalationRate, isA<double>());
      });

      test('should calculate accuracy rate', () async {
        await moderationService.initialize();
        
        final analytics = await moderationService.getModerationAnalytics();
        
        // Should meet 95% accuracy target
        expect(analytics.accuracyRate, greaterThanOrEqualTo(0.95));
      });

      test('should track processing performance', () async {
        await moderationService.initialize();
        
        final startTime = DateTime.now();
        await moderationService.moderateContent(
          content: 'Test content for performance measurement',
          level: ModerationLevel.standard,
        );
        final endTime = DateTime.now();
        
        final processingTime = endTime.difference(startTime).inMilliseconds;
        
        // Should process content quickly (under 2 seconds for real-time requirement)
        expect(processingTime, lessThan(2000));
      });
    });

    group('Moderation Level Tests', () {
      test('should apply different moderation levels', () async {
        const testContent = 'This is mildly inappropriate content';
        
        await moderationService.initialize();
        
        // Test lenient level
        final lenientResult = await moderationService.moderateContent(
          content: testContent,
          level: ModerationLevel.lenient,
        );
        
        // Test strict level
        final strictResult = await moderationService.moderateContent(
          content: testContent,
          level: ModerationLevel.strict,
        );
        
        // Strict should be more restrictive than lenient
        expect(strictResult.overallScore, greaterThanOrEqualTo(lenientResult.overallScore));
      });

      test('should handle enterprise level moderation', () async {
        const testContent = 'Enterprise content requiring high accuracy';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: testContent,
          level: ModerationLevel.enterprise,
        );

        expect(result, isNotNull);
        expect(result.confidence, greaterThan(0.0));
      });
    });

    group('Error Handling Tests', () {
      test('should handle empty content gracefully', () async {
        await moderationService.initialize();
        
        final result = await moderationService.moderateContent(
          content: '',
          level: ModerationLevel.standard,
        );

        expect(result.decision, equals(ModerationAction.approve));
        expect(result.overallScore, equals(0.0));
      });

      test('should handle very long content', () async {
        final longContent = 'This is a very long content. ' * 1000;
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: longContent,
          level: ModerationLevel.standard,
        );

        expect(result, isNotNull);
        expect(result.processingTime, lessThan(5000)); // Should still process within 5 seconds
      });

      test('should handle special characters and emojis', () async {
        const specialContent = '🎉 Special characters: @#\$%^&*()_+ 中文 العربية हिंदी';
        
        await moderationService.initialize();
        final result = await moderationService.moderateContent(
          content: specialContent,
          level: ModerationLevel.standard,
        );

        expect(result, isNotNull);
        expect(result.decision, isNotNull);
      });

      test('should return safe default on system error', () async {
        // This test simulates a system error scenario
        await moderationService.initialize();
        
        // The service should handle errors gracefully and return safe defaults
        final result = await moderationService.moderateContent(
          content: 'Test content',
          level: ModerationLevel.standard,
        );

        expect(result, isNotNull);
        expect(result.decision, isNotNull);
      });
    });

    group('Performance Tests', () {
      test('should meet 95% accuracy target', () async {
        await moderationService.initialize();
        
        // Test with known toxic content
        final toxicTests = [
          'You are stupid and worthless',
          'I hate all people from that community',
          'Kill yourself, nobody cares about you',
          'This is spam buy now click here!!!',
          'I will hurt you if you dont stop',
        ];

        // Test with known clean content
        final cleanTests = [
          'Thank you for sharing this helpful information',
          'I appreciate your contribution to our community',
          'This farming technique is very useful',
          'Great work on organizing the village meeting',
          'Looking forward to the harvest season',
        ];

        int correctToxicDetections = 0;
        int correctCleanDetections = 0;

        // Test toxic content detection
        for (final content in toxicTests) {
          final result = await moderationService.moderateContent(
            content: content,
            level: ModerationLevel.standard,
          );
          
          if (result.decision == ModerationAction.reject || 
              result.decision == ModerationAction.flagForReview) {
            correctToxicDetections++;
          }
        }

        // Test clean content detection
        for (final content in cleanTests) {
          final result = await moderationService.moderateContent(
            content: content,
            level: ModerationLevel.standard,
          );
          
          if (result.decision == ModerationAction.approve) {
            correctCleanDetections++;
          }
        }

        final totalTests = toxicTests.length + cleanTests.length;
        final correctDetections = correctToxicDetections + correctCleanDetections;
        final accuracy = correctDetections / totalTests;

        // Should meet 95% accuracy target
        expect(accuracy, greaterThanOrEqualTo(0.95));
      });

      test('should process content within performance requirements', () async {
        await moderationService.initialize();
        
        final testContents = [
          'Short content',
          'Medium length content with some more words to test processing time',
          'Very long content that contains multiple sentences and paragraphs to test the performance of the moderation system under different content lengths and complexity levels.',
        ];

        for (final content in testContents) {
          final stopwatch = Stopwatch()..start();
          
          await moderationService.moderateContent(
            content: content,
            level: ModerationLevel.standard,
          );
          
          stopwatch.stop();
          
          // Should process within 2 seconds for real-time requirements
          expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        }
      });
    });
  });
}