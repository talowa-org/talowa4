// TALOWA Onboarding Service
// Manages user onboarding flow and feature discovery
// Reference: in-app-communication/requirements.md - Requirements 2.2, 3.1, 9.1

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding/onboarding_step.dart';
import '../models/onboarding/tutorial_progress.dart';

class OnboardingService {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyMessagingTutorialCompleted = 'messaging_tutorial_completed';
  static const String _keyCallingTutorialCompleted = 'calling_tutorial_completed';
  static const String _keyGroupManagementTutorialCompleted = 'group_management_tutorial_completed';
  static const String _keyFeatureDiscoveryShown = 'feature_discovery_shown';
  static const String _keyLastOnboardingVersion = 'last_onboarding_version';
  
  static const int currentOnboardingVersion = 1;

  static SharedPreferences? _prefs;

  /// Initialize the onboarding service
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if user has completed initial onboarding
  static bool isOnboardingCompleted() {
    return _prefs?.getBool(_keyOnboardingCompleted) ?? false;
  }

  /// Mark initial onboarding as completed
  static Future<void> markOnboardingCompleted() async {
    await _prefs?.setBool(_keyOnboardingCompleted, true);
    await _prefs?.setInt(_keyLastOnboardingVersion, currentOnboardingVersion);
  }

  /// Check if messaging tutorial has been completed
  static bool isMessagingTutorialCompleted() {
    return _prefs?.getBool(_keyMessagingTutorialCompleted) ?? false;
  }

  /// Mark messaging tutorial as completed
  static Future<void> markMessagingTutorialCompleted() async {
    await _prefs?.setBool(_keyMessagingTutorialCompleted, true);
  }

  /// Check if calling tutorial has been completed
  static bool isCallingTutorialCompleted() {
    return _prefs?.getBool(_keyCallingTutorialCompleted) ?? false;
  }

  /// Mark calling tutorial as completed
  static Future<void> markCallingTutorialCompleted() async {
    await _prefs?.setBool(_keyCallingTutorialCompleted, true);
  }

  /// Check if group management tutorial has been completed
  static bool isGroupManagementTutorialCompleted() {
    return _prefs?.getBool(_keyGroupManagementTutorialCompleted) ?? false;
  }

  /// Mark group management tutorial as completed
  static Future<void> markGroupManagementTutorialCompleted() async {
    await _prefs?.setBool(_keyGroupManagementTutorialCompleted, true);
  }

  /// Check if feature discovery has been shown for a specific feature
  static bool isFeatureDiscoveryShown(String featureKey) {
    final shownFeatures = _prefs?.getStringList(_keyFeatureDiscoveryShown) ?? [];
    return shownFeatures.contains(featureKey);
  }

  /// Mark feature discovery as shown for a specific feature
  static Future<void> markFeatureDiscoveryShown(String featureKey) async {
    final shownFeatures = _prefs?.getStringList(_keyFeatureDiscoveryShown) ?? [];
    if (!shownFeatures.contains(featureKey)) {
      shownFeatures.add(featureKey);
      await _prefs?.setStringList(_keyFeatureDiscoveryShown, shownFeatures);
    }
  }

  /// Check if onboarding needs to be updated (new version)
  static bool needsOnboardingUpdate() {
    final lastVersion = _prefs?.getInt(_keyLastOnboardingVersion) ?? 0;
    return lastVersion < currentOnboardingVersion;
  }

  /// Reset all onboarding progress (for testing or re-onboarding)
  static Future<void> resetOnboardingProgress() async {
    await _prefs?.remove(_keyOnboardingCompleted);
    await _prefs?.remove(_keyMessagingTutorialCompleted);
    await _prefs?.remove(_keyCallingTutorialCompleted);
    await _prefs?.remove(_keyGroupManagementTutorialCompleted);
    await _prefs?.remove(_keyFeatureDiscoveryShown);
    await _prefs?.remove(_keyLastOnboardingVersion);
  }

  /// Get tutorial progress for a specific user role
  static TutorialProgress getTutorialProgress(String userRole) {
    return TutorialProgress(
      messagingCompleted: isMessagingTutorialCompleted(),
      callingCompleted: isCallingTutorialCompleted(),
      groupManagementCompleted: isGroupManagementTutorialCompleted(),
      overallProgress: _calculateOverallProgress(userRole),
    );
  }

  /// Calculate overall tutorial progress based on user role
  static double _calculateOverallProgress(String userRole) {
    int completedTutorials = 0;
    int totalTutorials = 2; // messaging and calling are basic for all users

    if (isMessagingTutorialCompleted()) completedTutorials++;
    if (isCallingTutorialCompleted()) completedTutorials++;

    // Add group management for coordinators and above
    if (userRole == 'coordinator' || userRole == 'admin' || userRole == 'founder') {
      totalTutorials++;
      if (isGroupManagementTutorialCompleted()) completedTutorials++;
    }

    return totalTutorials > 0 ? completedTutorials / totalTutorials : 0.0;
  }

  /// Get onboarding steps for messaging tutorial
  static List<OnboardingStep> getMessagingTutorialSteps() {
    return [
      OnboardingStep(
        id: 'messaging_intro',
        title: 'Welcome to TALOWA Messaging',
        description: 'Secure communication for land rights activism',
        content: 'TALOWA messaging provides end-to-end encrypted communication to help you coordinate with fellow activists, share important updates, and report issues safely.',
        iconData: Icons.message,
        actionText: 'Get Started',
      ),
      OnboardingStep(
        id: 'send_message',
        title: 'Send Your First Message',
        description: 'Learn how to send secure messages',
        content: 'Tap the compose button to start a new conversation. You can send text messages, share photos of land documents, and even send voice messages.',
        iconData: Icons.send,
        actionText: 'Try It',
        isInteractive: true,
      ),
      OnboardingStep(
        id: 'group_chats',
        title: 'Join Group Conversations',
        description: 'Connect with your village and mandal',
        content: 'Group chats help you stay connected with other activists in your area. You\'ll automatically be added to relevant groups based on your location.',
        iconData: Icons.group,
        actionText: 'Explore Groups',
      ),
      OnboardingStep(
        id: 'anonymous_reporting',
        title: 'Anonymous Reporting',
        description: 'Report issues safely and securely',
        content: 'Use anonymous reporting to safely report land grabbing or other issues without revealing your identity. Your reports will be forwarded to coordinators.',
        iconData: Icons.security,
        actionText: 'Learn More',
      ),
      OnboardingStep(
        id: 'message_security',
        title: 'Your Messages Are Secure',
        description: 'End-to-end encryption protects your privacy',
        content: 'All your messages are encrypted end-to-end, meaning only you and the recipient can read them. Not even TALOWA can access your private conversations.',
        iconData: Icons.lock,
        actionText: 'Got It',
      ),
    ];
  }

  /// Get onboarding steps for calling tutorial
  static List<OnboardingStep> getCallingTutorialSteps() {
    return [
      OnboardingStep(
        id: 'calling_intro',
        title: 'Voice Calling in TALOWA',
        description: 'Secure voice communication',
        content: 'Make encrypted voice calls to other TALOWA members directly through the app. Perfect for discussing sensitive matters privately.',
        iconData: Icons.call,
        actionText: 'Learn More',
      ),
      OnboardingStep(
        id: 'make_call',
        title: 'Making a Call',
        description: 'Start a voice conversation',
        content: 'From any chat, tap the call button to start a voice call. The call will be encrypted and secure.',
        iconData: Icons.phone,
        actionText: 'Try It',
        isInteractive: true,
      ),
      OnboardingStep(
        id: 'call_controls',
        title: 'Call Controls',
        description: 'Manage your calls effectively',
        content: 'During a call, you can mute/unmute, switch to speaker, or end the call. All controls are easily accessible.',
        iconData: Icons.settings_voice,
        actionText: 'Practice',
      ),
      OnboardingStep(
        id: 'call_quality',
        title: 'Call Quality',
        description: 'Optimized for rural networks',
        content: 'TALOWA calling is optimized for 2G and 3G networks common in rural areas. The app automatically adjusts quality based on your connection.',
        iconData: Icons.network_check,
        actionText: 'Understand',
      ),
    ];
  }

  /// Get onboarding steps for group management tutorial (coordinators only)
  static List<OnboardingStep> getGroupManagementTutorialSteps() {
    return [
      OnboardingStep(
        id: 'group_management_intro',
        title: 'Group Management for Coordinators',
        description: 'Lead your community effectively',
        content: 'As a coordinator, you have special powers to create groups, manage members, and send important announcements to your community.',
        iconData: Icons.admin_panel_settings,
        actionText: 'Get Started',
      ),
      OnboardingStep(
        id: 'create_group',
        title: 'Creating Groups',
        description: 'Organize your community',
        content: 'Create groups for your village, specific campaigns, or legal cases. You can set group permissions and manage who can join.',
        iconData: Icons.group_add,
        actionText: 'Try Creating',
        isInteractive: true,
      ),
      OnboardingStep(
        id: 'manage_members',
        title: 'Managing Members',
        description: 'Add and remove group participants',
        content: 'Add new members to groups, remove inactive ones, and assign roles. You can also moderate conversations to maintain focus.',
        iconData: Icons.people,
        actionText: 'Practice',
      ),
      OnboardingStep(
        id: 'broadcast_messages',
        title: 'Broadcast Messages',
        description: 'Reach your entire network',
        content: 'Send important announcements to all members in your area. Use this for emergency alerts, meeting notifications, or campaign updates.',
        iconData: Icons.campaign,
        actionText: 'Learn How',
      ),
      OnboardingStep(
        id: 'emergency_features',
        title: 'Emergency Broadcasting',
        description: 'Rapid response capabilities',
        content: 'In emergencies, you can send priority messages that bypass normal queues and reach all members immediately via push notifications and SMS.',
        iconData: Icons.emergency,
        actionText: 'Understand',
      ),
    ];
  }

  /// Get contextual help tips for specific screens
  static List<String> getContextualTips(String screenName) {
    switch (screenName) {
      case 'messages_screen':
        return [
          'Swipe left on any conversation to access quick actions',
          'Long press a message to reply, react, or forward it',
          'Use the search bar to find specific messages or contacts',
          'The green dot indicates when someone is online',
        ];
      case 'chat_screen':
        return [
          'Tap and hold to record voice messages',
          'Double-tap a message to quickly react with ❤️',
          'Swipe right on a message to reply to it',
          'Tap the camera icon to share photos or documents',
        ];
      case 'group_screen':
        return [
          'Tap the group name to see member list and settings',
          'Use @mentions to notify specific group members',
          'Only coordinators can add new members to location-based groups',
          'Anonymous messages appear with a masked sender icon',
        ];
      case 'voice_call_screen':
        return [
          'Tap the speaker icon to switch between earpiece and speaker',
          'The quality indicator shows your connection strength',
          'Calls automatically adjust quality based on network conditions',
          'All calls are end-to-end encrypted for your privacy',
        ];
      default:
        return [];
    }
  }

  /// Check if user should see feature discovery for new features
  static bool shouldShowFeatureDiscovery(String featureKey) {
    // Don't show if user hasn't completed basic onboarding
    if (!isOnboardingCompleted()) return false;
    
    // Don't show if already shown
    if (isFeatureDiscoveryShown(featureKey)) return false;
    
    return true;
  }
}