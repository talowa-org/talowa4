// Notification Templates - Templates for different message types and priorities
// Part of Task 12: Build push notification system

import '../../models/notification_model.dart';

class NotificationTemplates {
  /// Create notification from template
  static NotificationModel createFromTemplate({
    required NotificationTemplateType templateType,
    required Map<String, dynamic> data,
    String? customTitle,
    String? customBody,
  }) {
    final template = _getTemplate(templateType);
    
    return NotificationModel(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: customTitle ?? _processTemplate(template.title, data),
      body: customBody ?? _processTemplate(template.body, data),
      type: template.notificationType,
      data: {
        ...template.defaultData,
        ...data,
        'templateType': templateType.toString(),
      },
      createdAt: DateTime.now(),
      isRead: false,
      imageUrl: data['imageUrl'],
      actionUrl: data['actionUrl'],
    );
  }

  /// Get template by type
  static NotificationTemplate _getTemplate(NotificationTemplateType type) {
    switch (type) {
      // Messaging templates
      case NotificationTemplateType.newMessage:
        return const NotificationTemplate(
          title: '{{senderName}}',
          body: '{{messagePreview}}',
          notificationType: NotificationType.general,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'message'},
        );

      case NotificationTemplateType.groupMessage:
        return const NotificationTemplate(
          title: '{{groupName}}',
          body: '{{senderName}}: {{messagePreview}}',
          notificationType: NotificationType.general,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'group_message'},
        );

      case NotificationTemplateType.missedCall:
        return const NotificationTemplate(
          title: 'Missed Call',
          body: 'Missed call from {{callerName}}',
          notificationType: NotificationType.general,
          priority: NotificationPriority.high,
          defaultData: {'type': 'missed_call'},
        );

      // Social feed templates
      case NotificationTemplateType.postLike:
        return const NotificationTemplate(
          title: 'New Like',
          body: '{{likerName}} liked your post',
          notificationType: NotificationType.postLike,
          priority: NotificationPriority.low,
          defaultData: {'type': 'post_like'},
        );

      case NotificationTemplateType.postComment:
        return const NotificationTemplate(
          title: 'New Comment',
          body: '{{commenterName}} commented on your post: "{{commentPreview}}"',
          notificationType: NotificationType.postComment,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'post_comment'},
        );

      case NotificationTemplateType.postShare:
        return const NotificationTemplate(
          title: 'Post Shared',
          body: '{{sharerName}} shared your post',
          notificationType: NotificationType.postShare,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'post_share'},
        );

      case NotificationTemplateType.mentionInPost:
        return const NotificationTemplate(
          title: 'You were mentioned',
          body: '{{mentionerName}} mentioned you in a post',
          notificationType: NotificationType.mentionInPost,
          priority: NotificationPriority.high,
          defaultData: {'type': 'mention_post'},
        );

      case NotificationTemplateType.mentionInComment:
        return const NotificationTemplate(
          title: 'You were mentioned',
          body: '{{mentionerName}} mentioned you in a comment',
          notificationType: NotificationType.mentionInComment,
          priority: NotificationPriority.high,
          defaultData: {'type': 'mention_comment'},
        );

      // Emergency templates
      case NotificationTemplateType.emergencyAlert:
        return const NotificationTemplate(
          title: 'ðŸš¨ EMERGENCY ALERT',
          body: '{{alertMessage}}',
          notificationType: NotificationType.emergency,
          priority: NotificationPriority.critical,
          defaultData: {'type': 'emergency', 'bypassQuietHours': true},
        );

      case NotificationTemplateType.landGrabbingAlert:
        return const NotificationTemplate(
          title: 'âš ï¸ Land Grabbing Alert',
          body: 'Land grabbing reported in {{location}}. {{details}}',
          notificationType: NotificationType.landRightsAlert,
          priority: NotificationPriority.critical,
          defaultData: {'type': 'land_grabbing', 'bypassQuietHours': true},
        );

      case NotificationTemplateType.governmentAction:
        return const NotificationTemplate(
          title: 'ðŸ“¢ Government Action Alert',
          body: '{{actionType}} in {{location}}. {{details}}',
          notificationType: NotificationType.emergency,
          priority: NotificationPriority.high,
          defaultData: {'type': 'government_action'},
        );

      // Legal templates
      case NotificationTemplateType.courtDateReminder:
        return const NotificationTemplate(
          title: 'âš–ï¸ Court Date Reminder',
          body: 'Court hearing for {{caseName}} on {{date}} at {{time}}',
          notificationType: NotificationType.courtDateReminder,
          priority: NotificationPriority.high,
          defaultData: {'type': 'court_reminder'},
        );

      case NotificationTemplateType.legalUpdate:
        return const NotificationTemplate(
          title: 'ðŸ“‹ Legal Update',
          body: 'Update on {{caseName}}: {{updateDetails}}',
          notificationType: NotificationType.legalUpdate,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'legal_update'},
        );

      case NotificationTemplateType.documentExpiry:
        return const NotificationTemplate(
          title: 'ðŸ“„ Document Expiring',
          body: 'Your {{documentType}} expires on {{expiryDate}}',
          notificationType: NotificationType.documentExpiry,
          priority: NotificationPriority.high,
          defaultData: {'type': 'document_expiry'},
        );

      // Campaign templates
      case NotificationTemplateType.campaignUpdate:
        return const NotificationTemplate(
          title: 'ðŸ“¢ Campaign Update',
          body: '{{campaignName}}: {{updateMessage}}',
          notificationType: NotificationType.campaignUpdate,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'campaign_update'},
        );

      case NotificationTemplateType.meetingReminder:
        return const NotificationTemplate(
          title: 'ðŸ“… Meeting Reminder',
          body: '{{meetingTitle}} starts in {{timeUntil}} at {{location}}',
          notificationType: NotificationType.meetingReminder,
          priority: NotificationPriority.high,
          defaultData: {'type': 'meeting_reminder'},
        );

      case NotificationTemplateType.protestAlert:
        return const NotificationTemplate(
          title: 'âœŠ Protest Alert',
          body: 'Protest organized at {{location}} on {{date}}. {{details}}',
          notificationType: NotificationType.campaignUpdate,
          priority: NotificationPriority.high,
          defaultData: {'type': 'protest_alert'},
        );

      // Network templates
      case NotificationTemplateType.newFollower:
        return const NotificationTemplate(
          title: 'New Follower',
          body: '{{followerName}} started following you',
          notificationType: NotificationType.newFollower,
          priority: NotificationPriority.low,
          defaultData: {'type': 'new_follower'},
        );

      case NotificationTemplateType.networkMilestone:
        return const NotificationTemplate(
          title: 'ðŸŽ‰ Network Milestone',
          body: 'Congratulations! You now have {{count}} {{type}} in your network',
          notificationType: NotificationType.networkUpdate,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'network_milestone'},
        );

      case NotificationTemplateType.teamPromotion:
        return const NotificationTemplate(
          title: 'ðŸŽŠ Promotion!',
          body: 'Congratulations! You have been promoted to {{newRole}}',
          notificationType: NotificationType.networkUpdate,
          priority: NotificationPriority.high,
          defaultData: {'type': 'team_promotion'},
        );

      // System templates
      case NotificationTemplateType.systemUpdate:
        return const NotificationTemplate(
          title: 'ðŸ”„ App Update',
          body: '{{updateMessage}}',
          notificationType: NotificationType.systemUpdate,
          priority: NotificationPriority.low,
          defaultData: {'type': 'system_update'},
        );

      case NotificationTemplateType.maintenanceAlert:
        return const NotificationTemplate(
          title: 'ðŸ”§ Maintenance Alert',
          body: 'Scheduled maintenance from {{startTime}} to {{endTime}}',
          notificationType: NotificationType.systemUpdate,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'maintenance'},
        );

      case NotificationTemplateType.securityAlert:
        return const NotificationTemplate(
          title: 'ðŸ”’ Security Alert',
          body: '{{alertMessage}}',
          notificationType: NotificationType.systemUpdate,
          priority: NotificationPriority.high,
          defaultData: {'type': 'security_alert'},
        );

      // Success story templates
      case NotificationTemplateType.successStory:
        return const NotificationTemplate(
          title: 'ðŸŽ‰ Success Story',
          body: '{{title}}: {{summary}}',
          notificationType: NotificationType.successStory,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'success_story'},
        );

      case NotificationTemplateType.pattaReceived:
        return const NotificationTemplate(
          title: 'ðŸŽŠ Patta Received!',
          body: '{{farmerName}} received patta for {{landArea}} in {{village}}',
          notificationType: NotificationType.successStory,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'patta_success'},
        );

      case NotificationTemplateType.caseWon:
        return const NotificationTemplate(
          title: 'âš–ï¸ Case Won!',
          body: 'Victory in {{caseName}}! {{details}}',
          notificationType: NotificationType.successStory,
          priority: NotificationPriority.high,
          defaultData: {'type': 'case_victory'},
        );

      // Announcement templates
      case NotificationTemplateType.generalAnnouncement:
        return const NotificationTemplate(
          title: 'ðŸ“¢ Announcement',
          body: '{{announcementText}}',
          notificationType: NotificationType.announcement,
          priority: NotificationPriority.normal,
          defaultData: {'type': 'announcement'},
        );

      case NotificationTemplateType.coordinatorMessage:
        return const NotificationTemplate(
          title: 'ðŸ‘¤ Message from {{coordinatorName}}',
          body: '{{message}}',
          notificationType: NotificationType.announcement,
          priority: NotificationPriority.high,
          defaultData: {'type': 'coordinator_message'},
        );

      case NotificationTemplateType.policyUpdate:
        return const NotificationTemplate(
          title: 'ðŸ“‹ Policy Update',
          body: 'New policy: {{policyTitle}}. {{summary}}',
          notificationType: NotificationType.announcement,
          priority: NotificationPriority.high,
          defaultData: {'type': 'policy_update'},
        );
    }
  }

  /// Process template with data substitution
  static String _processTemplate(String template, Map<String, dynamic> data) {
    String processed = template;
    
    // Replace all {{key}} placeholders with data values
    data.forEach((key, value) {
      final placeholder = '{{$key}}';
      if (processed.contains(placeholder)) {
        processed = processed.replaceAll(placeholder, value.toString());
      }
    });

    // Handle special formatting
    processed = _applySpecialFormatting(processed, data);

    return processed;
  }

  /// Apply special formatting rules
  static String _applySpecialFormatting(String text, Map<String, dynamic> data) {
    // Truncate long messages
    if (text.length > 100) {
      text = '${text.substring(0, 97)}...';
    }

    // Format dates
    if (data.containsKey('date') && data['date'] is DateTime) {
      final date = data['date'] as DateTime;
      final formattedDate = '${date.day}/${date.month}/${date.year}';
      text = text.replaceAll('{{date}}', formattedDate);
    }

    // Format time
    if (data.containsKey('time') && data['time'] is DateTime) {
      final time = data['time'] as DateTime;
      final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      text = text.replaceAll('{{time}}', formattedTime);
    }

    return text;
  }

  /// Get notification channel ID based on template type
  static String getChannelId(NotificationTemplateType templateType) {
    final template = _getTemplate(templateType);
    
    switch (template.priority) {
      case NotificationPriority.critical:
        return 'talowa_emergency';
      case NotificationPriority.high:
        return 'talowa_important';
      case NotificationPriority.normal:
        return 'talowa_default';
      case NotificationPriority.low:
        return 'talowa_low_priority';
    }
  }

  /// Get notification sound based on template type
  static String? getNotificationSound(NotificationTemplateType templateType) {
    final template = _getTemplate(templateType);
    
    switch (template.priority) {
      case NotificationPriority.critical:
        return 'emergency_alert';
      case NotificationPriority.high:
        return 'important_alert';
      case NotificationPriority.normal:
        return 'default';
      case NotificationPriority.low:
        return null; // Silent
    }
  }

  /// Check if template should bypass quiet hours
  static bool shouldBypassQuietHours(NotificationTemplateType templateType) {
    final template = _getTemplate(templateType);
    return template.priority == NotificationPriority.critical ||
           template.defaultData['bypassQuietHours'] == true;
  }
}

/// Notification template data structure
class NotificationTemplate {
  final String title;
  final String body;
  final NotificationType notificationType;
  final NotificationPriority priority;
  final Map<String, dynamic> defaultData;

  const NotificationTemplate({
    required this.title,
    required this.body,
    required this.notificationType,
    required this.priority,
    this.defaultData = const {},
  });
}

/// Template types for different notification scenarios
enum NotificationTemplateType {
  // Messaging
  newMessage,
  groupMessage,
  missedCall,

  // Social feed
  postLike,
  postComment,
  postShare,
  mentionInPost,
  mentionInComment,

  // Emergency
  emergencyAlert,
  landGrabbingAlert,
  governmentAction,

  // Legal
  courtDateReminder,
  legalUpdate,
  documentExpiry,

  // Campaign
  campaignUpdate,
  meetingReminder,
  protestAlert,

  // Network
  newFollower,
  networkMilestone,
  teamPromotion,

  // System
  systemUpdate,
  maintenanceAlert,
  securityAlert,

  // Success stories
  successStory,
  pattaReceived,
  caseWon,

  // Announcements
  generalAnnouncement,
  coordinatorMessage,
  policyUpdate,
}

/// Notification priority levels
enum NotificationPriority {
  low,
  normal,
  high,
  critical,
}

/// Extension for template type localization
extension NotificationTemplateTypeExtension on NotificationTemplateType {
  String get displayName {
    switch (this) {
      case NotificationTemplateType.newMessage:
        return 'New Message';
      case NotificationTemplateType.groupMessage:
        return 'Group Message';
      case NotificationTemplateType.missedCall:
        return 'Missed Call';
      case NotificationTemplateType.postLike:
        return 'Post Like';
      case NotificationTemplateType.postComment:
        return 'Post Comment';
      case NotificationTemplateType.postShare:
        return 'Post Share';
      case NotificationTemplateType.mentionInPost:
        return 'Mention in Post';
      case NotificationTemplateType.mentionInComment:
        return 'Mention in Comment';
      case NotificationTemplateType.emergencyAlert:
        return 'Emergency Alert';
      case NotificationTemplateType.landGrabbingAlert:
        return 'Land Grabbing Alert';
      case NotificationTemplateType.governmentAction:
        return 'Government Action';
      case NotificationTemplateType.courtDateReminder:
        return 'Court Date Reminder';
      case NotificationTemplateType.legalUpdate:
        return 'Legal Update';
      case NotificationTemplateType.documentExpiry:
        return 'Document Expiry';
      case NotificationTemplateType.campaignUpdate:
        return 'Campaign Update';
      case NotificationTemplateType.meetingReminder:
        return 'Meeting Reminder';
      case NotificationTemplateType.protestAlert:
        return 'Protest Alert';
      case NotificationTemplateType.newFollower:
        return 'New Follower';
      case NotificationTemplateType.networkMilestone:
        return 'Network Milestone';
      case NotificationTemplateType.teamPromotion:
        return 'Team Promotion';
      case NotificationTemplateType.systemUpdate:
        return 'System Update';
      case NotificationTemplateType.maintenanceAlert:
        return 'Maintenance Alert';
      case NotificationTemplateType.securityAlert:
        return 'Security Alert';
      case NotificationTemplateType.successStory:
        return 'Success Story';
      case NotificationTemplateType.pattaReceived:
        return 'Patta Received';
      case NotificationTemplateType.caseWon:
        return 'Case Won';
      case NotificationTemplateType.generalAnnouncement:
        return 'General Announcement';
      case NotificationTemplateType.coordinatorMessage:
        return 'Coordinator Message';
      case NotificationTemplateType.policyUpdate:
        return 'Policy Update';
    }
  }
}
