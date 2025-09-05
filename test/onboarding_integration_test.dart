// TALOWA Onboarding Integration Test
// Tests the complete onboarding and help system implementation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:talowa/services/onboarding_service.dart';
import 'package:talowa/screens/onboarding/onboarding_screen.dart';
import 'package:talowa/screens/help/help_center_screen.dart';
import 'package:talowa/widgets/onboarding/feature_discovery_widget.dart';
// ContextualTipsWidget is defined in feature_discovery_widget.dart

void main() {
  group('Onboarding System Integration Tests', () {
    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
      await OnboardingService.initialize();
    });

    testWidgets('OnboardingService initializes correctly', (WidgetTester tester) async {
      await OnboardingService.initialize();
      
      // Initially, onboarding should not be completed
      expect(OnboardingService.isOnboardingCompleted(), false);
      expect(OnboardingService.isMessagingTutorialCompleted(), false);
      expect(OnboardingService.isCallingTutorialCompleted(), false);
      expect(OnboardingService.isGroupManagementTutorialCompleted(), false);
    });

    testWidgets('Messaging tutorial steps are loaded correctly', (WidgetTester tester) async {
      final steps = OnboardingService.getMessagingTutorialSteps();
      
      expect(steps.isNotEmpty, true);
      expect(steps.length, greaterThan(3)); // Should have multiple steps
      
      // Check that steps have required properties
      for (final step in steps) {
        expect(step.id.isNotEmpty, true);
        expect(step.title.isNotEmpty, true);
        expect(step.content.isNotEmpty, true);
        expect(step.actionText.isNotEmpty, true);
      }
    });

    testWidgets('Calling tutorial steps are loaded correctly', (WidgetTester tester) async {
      final steps = OnboardingService.getCallingTutorialSteps();
      
      expect(steps.isNotEmpty, true);
      expect(steps.length, greaterThan(2)); // Should have multiple steps
      
      // Check for voice calling specific content
      final hasCallContent = steps.any((step) => 
        step.content.toLowerCase().contains('call') || 
        step.title.toLowerCase().contains('call')
      );
      expect(hasCallContent, true);
    });

    testWidgets('Group management tutorial steps are loaded correctly', (WidgetTester tester) async {
      final steps = OnboardingService.getGroupManagementTutorialSteps();
      
      expect(steps.isNotEmpty, true);
      expect(steps.length, greaterThan(3)); // Should have multiple steps
      
      // Check for group management specific content
      final hasGroupContent = steps.any((step) => 
        step.content.toLowerCase().contains('group') || 
        step.title.toLowerCase().contains('group')
      );
      expect(hasGroupContent, true);
    });

    testWidgets('Tutorial completion tracking works', (WidgetTester tester) async {
      // Mark messaging tutorial as completed
      await OnboardingService.markMessagingTutorialCompleted();
      expect(OnboardingService.isMessagingTutorialCompleted(), true);
      
      // Mark calling tutorial as completed
      await OnboardingService.markCallingTutorialCompleted();
      expect(OnboardingService.isCallingTutorialCompleted(), true);
      
      // Mark group management tutorial as completed
      await OnboardingService.markGroupManagementTutorialCompleted();
      expect(OnboardingService.isGroupManagementTutorialCompleted(), true);
      
      // Overall onboarding should still be separate
      expect(OnboardingService.isOnboardingCompleted(), false);
      
      // Mark overall onboarding as completed
      await OnboardingService.markOnboardingCompleted();
      expect(OnboardingService.isOnboardingCompleted(), true);
    });

    testWidgets('Feature discovery tracking works', (WidgetTester tester) async {
      const featureKey = 'test_feature';
      
      // Initially should not be shown
      expect(OnboardingService.isFeatureDiscoveryShown(featureKey), false);
      
      // Should show feature discovery for new features
      expect(OnboardingService.shouldShowFeatureDiscovery(featureKey), false); // False because onboarding not completed
      
      // Complete onboarding first
      await OnboardingService.markOnboardingCompleted();
      expect(OnboardingService.shouldShowFeatureDiscovery(featureKey), true);
      
      // Mark as shown
      await OnboardingService.markFeatureDiscoveryShown(featureKey);
      expect(OnboardingService.isFeatureDiscoveryShown(featureKey), true);
      expect(OnboardingService.shouldShowFeatureDiscovery(featureKey), false);
    });

    testWidgets('Contextual tips are provided for different screens', (WidgetTester tester) async {
      final messagesTips = OnboardingService.getContextualTips('messages_screen');
      final chatTips = OnboardingService.getContextualTips('chat_screen');
      final groupTips = OnboardingService.getContextualTips('group_screen');
      final callTips = OnboardingService.getContextualTips('voice_call_screen');
      
      expect(messagesTips.isNotEmpty, true);
      expect(chatTips.isNotEmpty, true);
      expect(groupTips.isNotEmpty, true);
      expect(callTips.isNotEmpty, true);
      
      // Tips should be relevant to their screens
      expect(messagesTips.any((tip) => tip.toLowerCase().contains('message')), true);
      expect(chatTips.any((tip) => tip.toLowerCase().contains('message') || tip.toLowerCase().contains('chat')), true);
      expect(groupTips.any((tip) => tip.toLowerCase().contains('group')), true);
      expect(callTips.any((tip) => tip.toLowerCase().contains('call')), true);
    });

    testWidgets('Tutorial progress calculation works correctly', (WidgetTester tester) async {
      // Test for regular member (2 tutorials: messaging + calling)
      var progress = OnboardingService.getTutorialProgress('member');
      expect(progress.overallProgress, 0.0); // Nothing completed yet
      
      await OnboardingService.markMessagingTutorialCompleted();
      progress = OnboardingService.getTutorialProgress('member');
      expect(progress.overallProgress, 0.5); // 1 of 2 completed
      
      await OnboardingService.markCallingTutorialCompleted();
      progress = OnboardingService.getTutorialProgress('member');
      expect(progress.overallProgress, 1.0); // 2 of 2 completed
      
      // Test for coordinator (3 tutorials: messaging + calling + group management)
      await OnboardingService.resetOnboardingProgress();
      progress = OnboardingService.getTutorialProgress('coordinator');
      expect(progress.overallProgress, 0.0); // Nothing completed yet
      
      await OnboardingService.markMessagingTutorialCompleted();
      progress = OnboardingService.getTutorialProgress('coordinator');
      expect(progress.overallProgress, closeTo(0.33, 0.01)); // 1 of 3 completed
      
      await OnboardingService.markCallingTutorialCompleted();
      progress = OnboardingService.getTutorialProgress('coordinator');
      expect(progress.overallProgress, closeTo(0.67, 0.01)); // 2 of 3 completed
      
      await OnboardingService.markGroupManagementTutorialCompleted();
      progress = OnboardingService.getTutorialProgress('coordinator');
      expect(progress.overallProgress, 1.0); // 3 of 3 completed
    });

    testWidgets('OnboardingScreen widget can be created', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            tutorialType: 'messaging',
            onCompleted: () {},
          ),
        ),
      );
      
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Messaging'), findsOneWidget);
    });

    testWidgets('HelpCenterScreen widget can be created', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HelpCenterScreen(),
        ),
      );
      
      expect(find.byType(HelpCenterScreen), findsOneWidget);
      expect(find.text('Help Center'), findsOneWidget);
    });

    testWidgets('FeatureDiscoveryWidget can be created', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FeatureDiscoveryWidget(
            featureKey: 'test_feature',
            title: 'Test Feature',
            description: 'This is a test feature',
            child: Container(),
          ),
        ),
      );
      
      expect(find.byType(FeatureDiscoveryWidget), findsOneWidget);
    });

    testWidgets('ContextualTipsWidget can be created', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ContextualTipsWidget(
            screenName: 'test_screen',
            child: Container(),
          ),
        ),
      );
      
      expect(find.byType(ContextualTipsWidget), findsOneWidget);
    });

    testWidgets('Reset onboarding progress works', (WidgetTester tester) async {
      // Complete all tutorials
      await OnboardingService.markOnboardingCompleted();
      await OnboardingService.markMessagingTutorialCompleted();
      await OnboardingService.markCallingTutorialCompleted();
      await OnboardingService.markGroupManagementTutorialCompleted();
      await OnboardingService.markFeatureDiscoveryShown('test_feature');
      
      // Verify they are completed
      expect(OnboardingService.isOnboardingCompleted(), true);
      expect(OnboardingService.isMessagingTutorialCompleted(), true);
      expect(OnboardingService.isCallingTutorialCompleted(), true);
      expect(OnboardingService.isGroupManagementTutorialCompleted(), true);
      expect(OnboardingService.isFeatureDiscoveryShown('test_feature'), true);
      
      // Reset progress
      await OnboardingService.resetOnboardingProgress();
      
      // Verify everything is reset
      expect(OnboardingService.isOnboardingCompleted(), false);
      expect(OnboardingService.isMessagingTutorialCompleted(), false);
      expect(OnboardingService.isCallingTutorialCompleted(), false);
      expect(OnboardingService.isGroupManagementTutorialCompleted(), false);
      expect(OnboardingService.isFeatureDiscoveryShown('test_feature'), false);
    });
  });

  group('Help Documentation System Tests', () {
    testWidgets('Help documentation service initializes', (WidgetTester tester) async {
      // This test would verify that the help documentation service
      // loads help categories and articles correctly
      // Implementation depends on the actual service structure
    });
  });
}
