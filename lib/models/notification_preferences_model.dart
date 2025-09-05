// Notification Preferences Model - User notification settings
// Complete notification preferences data model

class NotificationPreferences {
  final bool enablePushNotifications;
  final bool enableInAppNotifications;
  final bool enableSound;
  final bool enableVibration;
  
  // Notification types
  final bool enableEmergencyNotifications;
  final bool enableCampaignNotifications;
  final bool enableSocialNotifications;
  final bool enableReferralNotifications;
  final bool enableAnnouncementNotifications;
  final bool enableEngagementNotifications;
  
  // Advanced settings
  final bool enableEmergencyOverride;
  final bool enableBatching;
  final int maxNotificationsPerHour;
  final QuietHours quietHours;

  const NotificationPreferences({
    this.enablePushNotifications = true,
    this.enableInAppNotifications = true,
    this.enableSound = true,
    this.enableVibration = true,
    this.enableEmergencyNotifications = true,
    this.enableCampaignNotifications = true,
    this.enableSocialNotifications = true,
    this.enableReferralNotifications = true,
    this.enableAnnouncementNotifications = true,
    this.enableEngagementNotifications = true,
    this.enableEmergencyOverride = true,
    this.enableBatching = true,
    this.maxNotificationsPerHour = 10,
    this.quietHours = const QuietHours(),
  });

  NotificationPreferences copyWith({
    bool? enablePushNotifications,
    bool? enableInAppNotifications,
    bool? enableSound,
    bool? enableVibration,
    bool? enableEmergencyNotifications,
    bool? enableCampaignNotifications,
    bool? enableSocialNotifications,
    bool? enableReferralNotifications,
    bool? enableAnnouncementNotifications,
    bool? enableEngagementNotifications,
    bool? enableEmergencyOverride,
    bool? enableBatching,
    int? maxNotificationsPerHour,
    QuietHours? quietHours,
  }) {
    return NotificationPreferences(
      enablePushNotifications: enablePushNotifications ?? this.enablePushNotifications,
      enableInAppNotifications: enableInAppNotifications ?? this.enableInAppNotifications,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      enableEmergencyNotifications: enableEmergencyNotifications ?? this.enableEmergencyNotifications,
      enableCampaignNotifications: enableCampaignNotifications ?? this.enableCampaignNotifications,
      enableSocialNotifications: enableSocialNotifications ?? this.enableSocialNotifications,
      enableReferralNotifications: enableReferralNotifications ?? this.enableReferralNotifications,
      enableAnnouncementNotifications: enableAnnouncementNotifications ?? this.enableAnnouncementNotifications,
      enableEngagementNotifications: enableEngagementNotifications ?? this.enableEngagementNotifications,
      enableEmergencyOverride: enableEmergencyOverride ?? this.enableEmergencyOverride,
      enableBatching: enableBatching ?? this.enableBatching,
      maxNotificationsPerHour: maxNotificationsPerHour ?? this.maxNotificationsPerHour,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enablePushNotifications': enablePushNotifications,
      'enableInAppNotifications': enableInAppNotifications,
      'enableSound': enableSound,
      'enableVibration': enableVibration,
      'enableEmergencyNotifications': enableEmergencyNotifications,
      'enableCampaignNotifications': enableCampaignNotifications,
      'enableSocialNotifications': enableSocialNotifications,
      'enableReferralNotifications': enableReferralNotifications,
      'enableAnnouncementNotifications': enableAnnouncementNotifications,
      'enableEngagementNotifications': enableEngagementNotifications,
      'enableEmergencyOverride': enableEmergencyOverride,
      'enableBatching': enableBatching,
      'maxNotificationsPerHour': maxNotificationsPerHour,
      'quietHours': quietHours.toMap(),
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      enablePushNotifications: map['enablePushNotifications'] ?? true,
      enableInAppNotifications: map['enableInAppNotifications'] ?? true,
      enableSound: map['enableSound'] ?? true,
      enableVibration: map['enableVibration'] ?? true,
      enableEmergencyNotifications: map['enableEmergencyNotifications'] ?? true,
      enableCampaignNotifications: map['enableCampaignNotifications'] ?? true,
      enableSocialNotifications: map['enableSocialNotifications'] ?? true,
      enableReferralNotifications: map['enableReferralNotifications'] ?? true,
      enableAnnouncementNotifications: map['enableAnnouncementNotifications'] ?? true,
      enableEngagementNotifications: map['enableEngagementNotifications'] ?? true,
      enableEmergencyOverride: map['enableEmergencyOverride'] ?? true,
      enableBatching: map['enableBatching'] ?? true,
      maxNotificationsPerHour: map['maxNotificationsPerHour'] ?? 10,
      quietHours: QuietHours.fromMap(map['quietHours'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'NotificationPreferences(enablePushNotifications: $enablePushNotifications, enableInAppNotifications: $enableInAppNotifications, enableSound: $enableSound, enableVibration: $enableVibration, enableEmergencyNotifications: $enableEmergencyNotifications, enableCampaignNotifications: $enableCampaignNotifications, enableSocialNotifications: $enableSocialNotifications, enableReferralNotifications: $enableReferralNotifications, enableAnnouncementNotifications: $enableAnnouncementNotifications, enableEngagementNotifications: $enableEngagementNotifications, enableEmergencyOverride: $enableEmergencyOverride, enableBatching: $enableBatching, maxNotificationsPerHour: $maxNotificationsPerHour, quietHours: $quietHours)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is NotificationPreferences &&
      other.enablePushNotifications == enablePushNotifications &&
      other.enableInAppNotifications == enableInAppNotifications &&
      other.enableSound == enableSound &&
      other.enableVibration == enableVibration &&
      other.enableEmergencyNotifications == enableEmergencyNotifications &&
      other.enableCampaignNotifications == enableCampaignNotifications &&
      other.enableSocialNotifications == enableSocialNotifications &&
      other.enableReferralNotifications == enableReferralNotifications &&
      other.enableAnnouncementNotifications == enableAnnouncementNotifications &&
      other.enableEngagementNotifications == enableEngagementNotifications &&
      other.enableEmergencyOverride == enableEmergencyOverride &&
      other.enableBatching == enableBatching &&
      other.maxNotificationsPerHour == maxNotificationsPerHour &&
      other.quietHours == quietHours;
  }

  @override
  int get hashCode {
    return enablePushNotifications.hashCode ^
      enableInAppNotifications.hashCode ^
      enableSound.hashCode ^
      enableVibration.hashCode ^
      enableEmergencyNotifications.hashCode ^
      enableCampaignNotifications.hashCode ^
      enableSocialNotifications.hashCode ^
      enableReferralNotifications.hashCode ^
      enableAnnouncementNotifications.hashCode ^
      enableEngagementNotifications.hashCode ^
      enableEmergencyOverride.hashCode ^
      enableBatching.hashCode ^
      maxNotificationsPerHour.hashCode ^
      quietHours.hashCode;
  }
}

class QuietHours {
  final bool enabled;
  final String startTime;
  final String endTime;

  const QuietHours({
    this.enabled = false,
    this.startTime = '22:00',
    this.endTime = '08:00',
  });

  QuietHours copyWith({
    bool? enabled,
    String? startTime,
    String? endTime,
  }) {
    return QuietHours(
      enabled: enabled ?? this.enabled,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory QuietHours.fromMap(Map<String, dynamic> map) {
    return QuietHours(
      enabled: map['enabled'] ?? false,
      startTime: map['startTime'] ?? '22:00',
      endTime: map['endTime'] ?? '08:00',
    );
  }

  @override
  String toString() => 'QuietHours(enabled: $enabled, startTime: $startTime, endTime: $endTime)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is QuietHours &&
      other.enabled == enabled &&
      other.startTime == startTime &&
      other.endTime == endTime;
  }

  @override
  int get hashCode => enabled.hashCode ^ startTime.hashCode ^ endTime.hashCode;
}

// Notification types enum
enum NotificationType {
  emergency,
  campaign,
  social,
  engagement,
  announcement,
  referral,
  system,
}

// Notification priority enum
enum NotificationPriority {
  low,
  normal,
  high,
  critical,
}

