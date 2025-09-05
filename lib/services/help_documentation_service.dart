// TALOWA Help Documentation Service
// Provides comprehensive help content with screenshots and guides
// Reference: in-app-communication/requirements.md - Requirements 2.2, 3.1, 9.1

import 'package:flutter/material.dart';
import '../models/help/help_article.dart';
import '../models/help/help_category.dart';
import '../models/help/help_search_result.dart';

class HelpDocumentationService {
  static final HelpDocumentationService _instance = HelpDocumentationService._internal();
  factory HelpDocumentationService() => _instance;
  HelpDocumentationService._internal();

  // Cache for help content
  List<HelpCategory>? _helpCategories;
  List<HelpArticle>? _allArticles;

  /// Initialize help documentation
  Future<void> initialize() async {
    await _loadHelpContent();
  }

  /// Get all help categories
  Future<List<HelpCategory>> getHelpCategories() async {
    if (_helpCategories == null) {
      await _loadHelpContent();
    }
    return _helpCategories ?? [];
  }

  /// Get articles for a specific category
  Future<List<HelpArticle>> getArticlesByCategory(String categoryId) async {
    final categories = await getHelpCategories();
    final category = categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => HelpCategory.empty(),
    );
    return category.articles;
  }

  /// Get a specific help article by ID
  Future<HelpArticle?> getArticleById(String articleId) async {
    if (_allArticles == null) {
      await _loadHelpContent();
    }
    try {
      return _allArticles?.firstWhere((article) => article.id == articleId);
    } catch (e) {
      return null;
    }
  }

  /// Search help articles
  Future<List<HelpSearchResult>> searchArticles(String query) async {
    if (_allArticles == null) {
      await _loadHelpContent();
    }

    if (query.trim().isEmpty) return [];

    final results = <HelpSearchResult>[];
    final lowercaseQuery = query.toLowerCase();

    for (final article in _allArticles ?? []) {
      int relevanceScore = 0;
      List<String> matchedSections = [];

      // Check title match (highest priority)
      if (article.title.toLowerCase().contains(lowercaseQuery)) {
        relevanceScore += 10;
        matchedSections.add('title');
      }

      // Check tags match
      for (final tag in article.tags) {
        if (tag.toLowerCase().contains(lowercaseQuery)) {
          relevanceScore += 5;
          matchedSections.add('tags');
          break;
        }
      }

      // Check content match
      if (article.content.toLowerCase().contains(lowercaseQuery)) {
        relevanceScore += 3;
        matchedSections.add('content');
      }

      // Check steps match
      for (final step in article.steps) {
        if (step.toLowerCase().contains(lowercaseQuery)) {
          relevanceScore += 2;
          matchedSections.add('steps');
          break;
        }
      }

      if (relevanceScore > 0) {
        results.add(HelpSearchResult(
          article: article,
          relevanceScore: relevanceScore,
          matchedSections: matchedSections,
          snippet: _generateSnippet(article.content, lowercaseQuery),
        ));
      }
    }

    // Sort by relevance score (descending)
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return results;
  }

  /// Get frequently asked questions
  Future<List<HelpArticle>> getFAQs() async {
    final articles = await _getAllArticles();
    return articles.where((article) => article.isFAQ).toList();
  }

  /// Get articles for specific user role
  Future<List<HelpArticle>> getArticlesForRole(String userRole) async {
    final articles = await _getAllArticles();
    return articles.where((article) => 
        article.targetRoles.isEmpty || article.targetRoles.contains(userRole)
    ).toList();
  }

  /// Get contextual help for specific screen
  Future<List<HelpArticle>> getContextualHelp(String screenName) async {
    final articles = await _getAllArticles();
    return articles.where((article) => 
        article.contextualScreens.contains(screenName)
    ).toList();
  }

  /// Load all help content
  Future<void> _loadHelpContent() async {
    _helpCategories = _createHelpCategories();
    _allArticles = _helpCategories!
        .expand((category) => category.articles)
        .toList();
  }

  /// Get all articles (internal helper)
  Future<List<HelpArticle>> _getAllArticles() async {
    if (_allArticles == null) {
      await _loadHelpContent();
    }
    return _allArticles ?? [];
  }

  /// Generate search snippet
  String _generateSnippet(String content, String query) {
    if (content.isEmpty) return '';
    
    final index = content.toLowerCase().indexOf(query.toLowerCase());
    if (index == -1) {
      // Return first 100 characters if query not found
      final maxLength = content.length > 100 ? 100 : content.length;
      return content.substring(0, maxLength) + (content.length > 100 ? '...' : '');
    }

    final start = (index - 50).clamp(0, content.length);
    final end = (index + query.length + 50).clamp(0, content.length);
    
    String snippet = content.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < content.length) snippet = '$snippet...';
    
    return snippet;
  }

  /// Create help categories with articles
  List<HelpCategory> _createHelpCategories() {
    return [
      // Messaging Help Category
      const HelpCategory(
        id: 'messaging',
        title: 'Messaging & Communication',
        description: 'Learn how to use TALOWA messaging features',
        iconData: Icons.message,
        articles: [
          HelpArticle(
            id: 'send_first_message',
            title: 'How to Send Your First Message',
            content: 'Learn how to start conversations and send secure messages in TALOWA.',
            steps: [
              'Open the Messages tab from the bottom navigation',
              'Tap the "+" button to start a new conversation',
              'Select "Direct Message" to chat with a specific person',
              'Search for the person you want to message',
              'Type your message and tap Send',
            ],
            tags: ['messaging', 'chat', 'send', 'conversation'],
            category: 'messaging',
            estimatedReadTime: 2,
            screenshots: ['messaging_tab.png', 'new_message.png', 'send_message.png'],
            contextualScreens: ['messages_screen', 'chat_screen'],
          ),
          HelpArticle(
            id: 'group_messaging',
            title: 'Joining and Using Group Chats',
            content: 'Group chats help you stay connected with activists in your area.',
            steps: [
              'You\'ll automatically be added to relevant groups based on your location',
              'Tap on a group name to open the conversation',
              'Type your message and send it to all group members',
              'Use @mentions to notify specific members',
              'Tap the group name to see members and settings',
            ],
            tags: ['group', 'chat', 'village', 'mandal', 'community'],
            category: 'messaging',
            estimatedReadTime: 3,
            screenshots: ['group_list.png', 'group_chat.png', 'group_members.png'],
            contextualScreens: ['messages_screen', 'group_screen'],
          ),
          HelpArticle(
            id: 'anonymous_reporting',
            title: 'How to Report Issues Anonymously',
            content: 'Report land grabbing and other issues safely without revealing your identity.',
            steps: [
              'Go to Messages and tap the "+" button',
              'Select "Anonymous Report"',
              'Choose the type of issue you want to report',
              'Describe the issue in detail',
              'Add photos or documents if available',
              'Submit the report - your identity will be protected',
            ],
            tags: ['anonymous', 'report', 'land grabbing', 'safety', 'privacy'],
            category: 'messaging',
            estimatedReadTime: 4,
            screenshots: ['anonymous_report.png', 'report_form.png'],
            contextualScreens: ['messages_screen', 'anonymous_reporting_screen'],
            isFAQ: true,
          ),
          HelpArticle(
            id: 'message_security',
            title: 'Understanding Message Security',
            content: 'All TALOWA messages are encrypted end-to-end for your privacy and security.',
            steps: [
              'All messages are automatically encrypted',
              'Only you and the recipient can read your messages',
              'Look for the lock icon to confirm encryption',
              'Anonymous messages provide additional privacy protection',
              'Your message history is stored securely on your device',
            ],
            tags: ['security', 'encryption', 'privacy', 'safety'],
            category: 'messaging',
            estimatedReadTime: 3,
            screenshots: ['encryption_indicator.png', 'security_settings.png'],
            isFAQ: true,
          ),
        ],
      ),

      // Voice Calling Help Category
      const HelpCategory(
        id: 'calling',
        title: 'Voice Calling',
        description: 'Make secure voice calls through TALOWA',
        iconData: Icons.call,
        articles: [
          HelpArticle(
            id: 'make_voice_call',
            title: 'How to Make a Voice Call',
            content: 'Make encrypted voice calls to other TALOWA members.',
            steps: [
              'Open a chat with the person you want to call',
              'Tap the phone icon in the top right corner',
              'Wait for the other person to answer',
              'Use the call controls to mute, switch to speaker, or end the call',
            ],
            tags: ['voice call', 'calling', 'phone', 'audio'],
            category: 'calling',
            estimatedReadTime: 2,
            screenshots: ['call_button.png', 'voice_call_screen.png', 'call_controls.png'],
            contextualScreens: ['chat_screen', 'voice_call_screen'],
          ),
          HelpArticle(
            id: 'call_controls',
            title: 'Using Call Controls',
            content: 'Learn about the various controls available during a voice call.',
            steps: [
              'Mute button: Tap to mute/unmute your microphone',
              'Speaker button: Switch between earpiece and speaker',
              'End call button: Tap the red button to end the call',
              'Quality indicator: Shows your connection strength',
            ],
            tags: ['call controls', 'mute', 'speaker', 'end call'],
            category: 'calling',
            estimatedReadTime: 2,
            screenshots: ['call_controls_detail.png'],
            contextualScreens: ['voice_call_screen'],
          ),
          HelpArticle(
            id: 'call_quality',
            title: 'Improving Call Quality',
            content: 'Tips for better call quality, especially on slower networks.',
            steps: [
              'Move to an area with better network coverage',
              'Close other apps that might be using data',
              'Use Wi-Fi when available for better quality',
              'The app automatically adjusts quality based on your connection',
              'If quality is poor, try calling back later',
            ],
            tags: ['call quality', 'network', 'connection', 'audio quality'],
            category: 'calling',
            estimatedReadTime: 3,
            screenshots: ['quality_indicator.png', 'network_settings.png'],
            isFAQ: true,
          ),
        ],
      ),

      // Group Management Help Category (for coordinators)
      const HelpCategory(
        id: 'group_management',
        title: 'Group Management',
        description: 'Coordinator tools for managing groups and communities',
        iconData: Icons.admin_panel_settings,
        articles: [
          HelpArticle(
            id: 'create_group',
            title: 'How to Create a Group',
            content: 'As a coordinator, you can create groups to organize your community.',
            steps: [
              'Go to Messages and tap the "+" button',
              'Select "Group Chat"',
              'Enter a group name and description',
              'Select members to add to the group',
              'Set group permissions and privacy settings',
              'Tap "Create" to create the group',
            ],
            tags: ['create group', 'coordinator', 'community', 'organize'],
            category: 'group_management',
            estimatedReadTime: 3,
            targetRoles: ['coordinator', 'admin', 'founder'],
            screenshots: ['create_group.png', 'group_settings.png'],
            contextualScreens: ['messages_screen', 'create_group_screen'],
          ),
          HelpArticle(
            id: 'manage_group_members',
            title: 'Managing Group Members',
            content: 'Add, remove, and manage members in your groups.',
            steps: [
              'Open the group chat',
              'Tap the group name at the top',
              'Select "Members" to see all group members',
              'Tap "Add Members" to invite new people',
              'Long press on a member to remove them or change their role',
              'Set member permissions as needed',
            ],
            tags: ['group members', 'add members', 'remove members', 'permissions'],
            category: 'group_management',
            estimatedReadTime: 4,
            targetRoles: ['coordinator', 'admin', 'founder'],
            screenshots: ['group_members.png', 'add_members.png', 'member_permissions.png'],
            contextualScreens: ['group_screen', 'group_members_screen'],
          ),
          HelpArticle(
            id: 'broadcast_messages',
            title: 'Sending Broadcast Messages',
            content: 'Send important announcements to multiple groups at once.',
            steps: [
              'Go to Messages and tap the "+" button',
              'Select "Broadcast Message"',
              'Choose which groups or areas to send to',
              'Write your announcement message',
              'Select priority level (normal or urgent)',
              'Tap "Send" to broadcast to all selected recipients',
            ],
            tags: ['broadcast', 'announcement', 'urgent', 'coordinator'],
            category: 'group_management',
            estimatedReadTime: 3,
            targetRoles: ['coordinator', 'admin', 'founder'],
            screenshots: ['broadcast_message.png', 'select_recipients.png'],
            contextualScreens: ['messages_screen', 'bulk_message_screen'],
          ),
          HelpArticle(
            id: 'emergency_broadcasting',
            title: 'Emergency Broadcasting',
            content: 'Send urgent alerts that reach members immediately via multiple channels.',
            steps: [
              'In Messages, tap the menu (three dots)',
              'Select "Emergency Broadcast"',
              'Choose the emergency type and affected area',
              'Write a clear, urgent message',
              'Select delivery channels (push, SMS, email)',
              'Confirm and send - this will reach all members immediately',
            ],
            tags: ['emergency', 'urgent', 'alert', 'broadcast', 'crisis'],
            category: 'group_management',
            estimatedReadTime: 4,
            targetRoles: ['coordinator', 'admin', 'founder'],
            screenshots: ['emergency_broadcast.png', 'emergency_channels.png'],
            contextualScreens: ['messages_screen'],
            isFAQ: true,
          ),
        ],
      ),

      // General Help Category
      const HelpCategory(
        id: 'general',
        title: 'General Help',
        description: 'Common questions and basic app usage',
        iconData: Icons.help,
        articles: [
          HelpArticle(
            id: 'getting_started',
            title: 'Getting Started with TALOWA',
            content: 'Welcome to TALOWA! This guide will help you get started with the app.',
            steps: [
              'Complete your profile with accurate information',
              'Verify your phone number and location',
              'Take the messaging tutorial to learn basic features',
              'Join relevant groups for your area',
              'Start connecting with other activists in your network',
            ],
            tags: ['getting started', 'welcome', 'setup', 'profile'],
            category: 'general',
            estimatedReadTime: 5,
            screenshots: ['welcome_screen.png', 'profile_setup.png', 'tutorial_start.png'],
            isFAQ: true,
          ),
          HelpArticle(
            id: 'privacy_settings',
            title: 'Managing Your Privacy',
            content: 'Control who can see your information and contact you.',
            steps: [
              'Go to Settings from the More tab',
              'Select "Privacy & Security"',
              'Choose who can see your profile information',
              'Set message and call permissions',
              'Configure anonymous reporting preferences',
              'Review and update settings regularly',
            ],
            tags: ['privacy', 'security', 'settings', 'permissions'],
            category: 'general',
            estimatedReadTime: 4,
            screenshots: ['privacy_settings.png', 'security_options.png'],
            contextualScreens: ['settings_screen'],
            isFAQ: true,
          ),
          HelpArticle(
            id: 'troubleshooting',
            title: 'Common Issues and Solutions',
            content: 'Solutions to common problems you might encounter.',
            steps: [
              'If messages aren\'t sending, check your internet connection',
              'For call quality issues, try moving to better network coverage',
              'If you can\'t join a group, contact your coordinator',
              'For login problems, verify your phone number is correct',
              'If the app is slow, try closing and reopening it',
              'Contact support if problems persist',
            ],
            tags: ['troubleshooting', 'problems', 'issues', 'solutions', 'help'],
            category: 'general',
            estimatedReadTime: 3,
            isFAQ: true,
          ),
        ],
      ),
    ];
  }
}
