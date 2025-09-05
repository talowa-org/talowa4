// TALOWA Onboarding System Test
// Tests the onboarding and help system functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talowa/services/onboarding_service.dart';
import 'package:talowa/services/help_documentation_service.dart';
import 'package:talowa/models/onboarding/tutorial_progress.dart';

void main() {
  group('Onboarding System Tests', () {
    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
      await OnboardingService.initialize();
    });

    group('OnboardingService', () {
      test('should initialize with default values', () {
        expect(OnboardingService.isOnboardingCompleted(), false);
        expect(OnboardingService.isMessagingTutorialCompleted(), false);
        expect(OnboardingService.isCallingTutorialCompleted(), false);
        expect(OnboardingService.isGroupManagementTutorialCompleted(), false);
      });

      test('should mark tutorials as completed', () async {
        await OnboardingService.markMessagingTutorialCompleted();
        expect(OnboardingService.isMessagingTutorialCompleted(), true);

        await OnboardingService.markCallingTutorialCompleted();
        expect(OnboardingService.isCallingTutorialCompleted(), true);

        await OnboardingService.markGroupManagementTutorialCompleted();
        expect(OnboardingService.isGroupManagementTutorialCompleted(), true);
      });

      test('should track feature discovery', () async {
        const featureKey = 'test_feature';
        
        expect(OnboardingService.isFeatureDiscoveryShown(featureKey), false);
        expect(OnboardingService.shouldShowFeatureDiscovery(featureKey), false); // No onboarding completed
        
        await OnboardingService.markOnboardingCompleted();
        expect(OnboardingService.shouldShowFeatureDiscovery(featureKey), true);
        
        await OnboardingService.markFeatureDiscoveryShown(featureKey);
        expect(OnboardingService.isFeatureDiscoveryShown(featureKey), true);
        expect(OnboardingService.shouldShowFeatureDiscovery(featureKey), false);
      });

      test('should calculate tutorial progress correctly', () {
        // Test for regular member (2 tutorials: messaging + calling)
        var progress = OnboardingService.getTutorialProgress('member');
        expect(progress.overallProgress, 0.0);
        expect(progress.nextRecommendedTutorial, 'messaging');

        // Complete messaging tutorial
        OnboardingService.markMessagingTutorialCompleted();
        progress = OnboardingService.getTutorialProgress('member');
        expect(progress.overallProgress, 0.5);
        expect(progress.nextRecommendedTutorial, 'calling');

        // Complete calling tutorial
        OnboardingService.markCallingTutorialCompleted();
        progress = OnboardingService.getTutorialProgress('member');
        expect(progress.overallProgress, 1.0);
        expect(progress.nextRecommendedTutorial, 'group_management'); // Still shows group management as next even for members
      });

      test('should calculate coordinator progress correctly', () {
        // Test for coordinator (3 tutorials: messaging + calling + group management)
        var progress = OnboardingService.getTutorialProgress('coordinator');
        expect(progress.overallProgress, 0.0);

        // Complete messaging tutorial
        OnboardingService.markMessagingTutorialCompleted();
        progress = OnboardingService.getTutorialProgress('coordinator');
        expect(progress.overallProgress, closeTo(0.33, 0.01));

        // Complete calling tutorial
        OnboardingService.markCallingTutorialCompleted();
        progress = OnboardingService.getTutorialProgress('coordinator');
        expect(progress.overallProgress, closeTo(0.67, 0.01));

        // Complete group management tutorial
        OnboardingService.markGroupManagementTutorialCompleted();
        progress = OnboardingService.getTutorialProgress('coordinator');
        expect(progress.overallProgress, 1.0);
      });

      test('should provide contextual tips for different screens', () {
        var tips = OnboardingService.getContextualTips('messages_screen');
        expect(tips, isNotEmpty);
        expect(tips.length, greaterThan(0));

        tips = OnboardingService.getContextualTips('chat_screen');
        expect(tips, isNotEmpty);

        tips = OnboardingService.getContextualTips('nonexistent_screen');
        expect(tips, isEmpty);
      });

      test('should provide tutorial steps', () {
        var steps = OnboardingService.getMessagingTutorialSteps();
        expect(steps, isNotEmpty);
        expect(steps.length, greaterThan(3));
        expect(steps.first.title, contains('TALOWA'));

        steps = OnboardingService.getCallingTutorialSteps();
        expect(steps, isNotEmpty);
        expect(steps.first.title, contains('Voice'));

        steps = OnboardingService.getGroupManagementTutorialSteps();
        expect(steps, isNotEmpty);
        expect(steps.first.title, contains('Coordinator'));
      });

      test('should reset onboarding progress', () async {
        // Complete some tutorials
        await OnboardingService.markMessagingTutorialCompleted();
        await OnboardingService.markCallingTutorialCompleted();
        await OnboardingService.markOnboardingCompleted();
        
        expect(OnboardingService.isMessagingTutorialCompleted(), true);
        expect(OnboardingService.isCallingTutorialCompleted(), true);
        expect(OnboardingService.isOnboardingCompleted(), true);

        // Reset progress
        await OnboardingService.resetOnboardingProgress();
        
        expect(OnboardingService.isMessagingTutorialCompleted(), false);
        expect(OnboardingService.isCallingTutorialCompleted(), false);
        expect(OnboardingService.isOnboardingCompleted(), false);
      });
    });

    group('HelpDocumentationService', () {
      late HelpDocumentationService helpService;

      setUp(() async {
        helpService = HelpDocumentationService();
        await helpService.initialize();
      });

      test('should load help categories', () async {
        final categories = await helpService.getHelpCategories();
        expect(categories, isNotEmpty);
        expect(categories.length, greaterThanOrEqualTo(3));
        
        // Check for expected categories
        final categoryIds = categories.map((c) => c.id).toList();
        expect(categoryIds, contains('messaging'));
        expect(categoryIds, contains('calling'));
        expect(categoryIds, contains('general'));
      });

      test('should get articles by category', () async {
        final messagingArticles = await helpService.getArticlesByCategory('messaging');
        expect(messagingArticles, isNotEmpty);
        
        final callingArticles = await helpService.getArticlesByCategory('calling');
        expect(callingArticles, isNotEmpty);
        
        final nonexistentArticles = await helpService.getArticlesByCategory('nonexistent');
        expect(nonexistentArticles, isEmpty);
      });

      test('should get article by ID', () async {
        final article = await helpService.getArticleById('send_first_message');
        expect(article, isNotNull);
        expect(article!.title, contains('Send'));
        
        final nonexistentArticle = await helpService.getArticleById('nonexistent');
        expect(nonexistentArticle, isNull);
      });

      test('should search articles', () async {
        var results = await helpService.searchArticles('message');
        expect(results, isNotEmpty);
        expect(results.first.relevanceScore, greaterThan(0));
        
        results = await helpService.searchArticles('voice call');
        expect(results, isNotEmpty);
        
        results = await helpService.searchArticles('nonexistent query');
        expect(results, isEmpty);
        
        results = await helpService.searchArticles('');
        expect(results, isEmpty);
      });

      test('should get FAQs', () async {
        final faqs = await helpService.getFAQs();
        expect(faqs, isNotEmpty);
        
        // All returned articles should be FAQs
        for (final article in faqs) {
          expect(article.isFAQ, true);
        }
      });

      test('should get articles for specific roles', () async {
        final memberArticles = await helpService.getArticlesForRole('member');
        expect(memberArticles, isNotEmpty);
        
        final coordinatorArticles = await helpService.getArticlesForRole('coordinator');
        expect(coordinatorArticles, isNotEmpty);
        
        // Coordinator articles should include group management
        final hasGroupManagement = coordinatorArticles.any(
          (article) => article.category == 'group_management'
        );
        expect(hasGroupManagement, true);
      });

      test('should get contextual help', () async {
        final contextualHelp = await helpService.getContextualHelp('messages_screen');
        expect(contextualHelp, isNotEmpty);
        
        final chatHelp = await helpService.getContextualHelp('chat_screen');
        expect(chatHelp, isNotEmpty);
        
        final noHelp = await helpService.getContextualHelp('nonexistent_screen');
        expect(noHelp, isEmpty);
      });
    });

    group('TutorialProgress Model', () {
      test('should calculate completion correctly', () {
        var progress = const TutorialProgress(
          messagingCompleted: false,
          callingCompleted: false,
          groupManagementCompleted: false,
          overallProgress: 0.0,
        );
        
        expect(progress.isBasicTutorialCompleted, false);
        expect(progress.isAllTutorialsCompleted, false);
        expect(progress.nextRecommendedTutorial, 'messaging');
        expect(progress.completionPercentage, 0);

        progress = const TutorialProgress(
          messagingCompleted: true,
          callingCompleted: true,
          groupManagementCompleted: false,
          overallProgress: 0.67,
        );
        
        expect(progress.isBasicTutorialCompleted, true);
        expect(progress.isAllTutorialsCompleted, false);
        expect(progress.nextRecommendedTutorial, 'group_management');
        expect(progress.completionPercentage, 67);

        progress = const TutorialProgress(
          messagingCompleted: true,
          callingCompleted: true,
          groupManagementCompleted: true,
          overallProgress: 1.0,
        );
        
        expect(progress.isBasicTutorialCompleted, true);
        expect(progress.isAllTutorialsCompleted, true);
        expect(progress.nextRecommendedTutorial, null);
        expect(progress.completionPercentage, 100);
      });

      test('should serialize and deserialize correctly', () {
        const original = TutorialProgress(
          messagingCompleted: true,
          callingCompleted: false,
          groupManagementCompleted: true,
          overallProgress: 0.67,
          lastUpdated: null,
        );

        final json = original.toJson();
        final deserialized = TutorialProgress.fromJson(json);

        expect(deserialized.messagingCompleted, original.messagingCompleted);
        expect(deserialized.callingCompleted, original.callingCompleted);
        expect(deserialized.groupManagementCompleted, original.groupManagementCompleted);
        expect(deserialized.overallProgress, original.overallProgress);
      });
    });
  });
}
