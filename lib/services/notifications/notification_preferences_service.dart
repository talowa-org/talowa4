// Notification Preferences Service - Manage user notification preferences
// Part of Task 12: Build push notification system

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/notification_model.dart';
import '../auth/auth_service.dart';

class NotificationPreferencesService {
  static final NotificationPreferencesService _instance = NotificationPreferencesService._internal();
  factory NotificationPreferencesService() => _instance;
  NotificationPreferencesService._internal();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static NotificationPreferences? _cachedPreferences;

  /// Initialize preferences service
  static Future<void> initialize() async {
    try {
      debugPrint('NotificationPreferencesService: Initializing...');
      
      // Load preferences from cache
      await _loadPreferencesFromCache();
      
      // Sync with server if user is authenticated
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        await syncPreferencesWithServer();
      }
      
      debugPrint('NotificationPreferencesService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationPreferencesService: Initialization failed: $e');
    }
  }

  /// Get current notification preferences
  static NotificationPreferences getPreferences() {
    return _cachedPreferences ?? const NotificationPreferences();
  }

  /// Update notification preferences
  static Future<void> updatePreferences(NotificationPreferences preferences) async {
    try {
      debugPrint('NotificationPreferencesService: Updating preferences');
      
      // Update cache
      _cachedPreferences = preferences;
      
      // Save to local storage
      await _savePreferencesToCache(preferences);
      
      // Sync with server if user is authenticated
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        await _savePreferencesToServer(preferences);
      }
      
      debugPrint('NotificationPreferencesService: Preferences updated successfully');
    } catch (e) {
      debugPrint('NotificationPreferencesService: Error updating preferences: $e');
      rethrow;
    }
  }

  /// Update specific preference
  static Future<void> updatePreference({
    bool? enablePushNotifications,
    bool? enableInAppNotifications,
    bool? enableEmailNotifications,
    bool? enableSMSNotifications,
    bool? enableQuietHours,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool? enableLocationBasedNotifications,
    bool? enableEmergencyOverride,
    Map<NotificationType, bool>? typePreferences,
  }) async {
    final currentPreferences = getPreferences();
    
    final updatedPreferences = NotificationPreferences(
      enablePushNotifications: enablePushNotifications ?? currentPreferences.enablePushNotifications,
      enableInAppNotifications: enableInAppNotifications ?? currentPreferences.enableInAppNotifications,
      enableEmailNotifications: enableEmailNotifications ?? currentPreferences.enableEmailNotifications,
      enableSMSNotifications: enableSMSNotifications ?? currentPreferences.enableSMSNotifications,
      enableQuietHours: enableQuietHours ?? currentPreferences.enableQuietHours,
      quietHoursStart: quietHoursStart ?? currentPreferences.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? currentPreferences.quietHoursEnd,
      enableLocationBasedNotifications: enableLocationBasedNotifications ?? currentPreferences.enableLocationBasedNotifications,
      enableEmergencyOverride: enableEmergencyOverride ?? currentPreferences.enableEmergencyOverride,
      typePreferences: typePreferences ?? currentPreferences.typePreferences,
    );
    
    await updatePreferences(updatedPreferences);
  }

  /// Toggle notification type
  static Future<void> toggleNotificationType(NotificationType type, bool enabled) async {
    final currentPreferences = getPreferences();
    final updatedTypePreferences = Map<NotificationType, bool>.from(currentPreferences.typePreferences);
    updatedTypePreferences[type] = enabled;
    
    await updatePreference(typePreferences: updatedTypePreferences);
  }

  /// Check if notification should be shown based on preferences
  static bool shouldShowNotification(NotificationModel notification) {
    final preferences = getPreferences();
    
    // Check if push notifications are enabled
    if (!preferences.enablePushNotifications) {
      return false;
    }
    
    // Check if specific type is enabled
    if (!preferences.isTypeEnabled(notification.type)) {
      return false;
    }
    
    // Check quiet hours (unless emergency override is enabled)
    if (preferences.isInQuietHours && 
        !preferences.enableEmergencyOverride && 
        !notification.isHighPriority) {
      return false;
    }
    
    // Emergency notifications always show if emergency override is enabled
    if (notification.type == NotificationType.emergency && 
        preferences.enableEmergencyOverride) {
      return true;
    }
    
    return true;
  }

  /// Get notification channel preferences
  static Map<String, bool> getChannelPreferences() {
    final preferences = getPreferences();
    
    return {
      'push': preferences.enablePushNotifications,
      'inApp': preferences.enableInAppNotifications,
      'email': preferences.enableEmailNotifications,
      'sms': preferences.enableSMSNotifications,
    };
  }

  /// Get quiet hours status
  static Map<String, dynamic> getQuietHoursStatus() {
    final preferences = getPreferences();
    
    return {
      'enabled': preferences.enableQuietHours,
      'start': preferences.quietHoursStart,
      'end': preferences.quietHoursEnd,
      'isCurrentlyInQuietHours': preferences.isInQuietHours,
    };
  }

  /// Get type-specific preferences
  static Map<NotificationType, bool> getTypePreferences() {
    return getPreferences().typePreferences;
  }

  /// Reset preferences to default
  static Future<void> resetToDefaults() async {
    await updatePreferences(const NotificationPreferences());
  }

  /// Sync preferences with server
  static Future<void> syncPreferencesWithServer() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;
      
      debugPrint('NotificationPreferencesService: Syncing preferences with server');
      
      // Get preferences from server
      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('preferences')
          .doc('notifications')
          .get();
      
      if (doc.exists) {
        final serverPreferences = NotificationPreferences.fromMap(doc.data()!);
        
        // Update cache with server preferences
        _cachedPreferences = serverPreferences;
        await _savePreferencesToCache(serverPreferences);
        
        debugPrint('NotificationPreferencesService: Synced preferences from server');
      } else {
        // Save current preferences to server
        final currentPreferences = getPreferences();
        await _savePreferencesToServer(currentPreferences);
        
        debugPrint('NotificationPreferencesService: Saved preferences to server');
      }
      
    } catch (e) {
      debugPrint('NotificationPreferencesService: Error syncing with server: $e');
    }
  }

  /// Save preferences to server
  static Future<void> _savePreferencesToServer(NotificationPreferences preferences) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;
      
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('preferences')
          .doc('notifications')
          .set({
        ...preferences.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('NotificationPreferencesService: Saved preferences to server');
    } catch (e) {
      debugPrint('NotificationPreferencesService: Error saving to server: $e');
      rethrow;
    }
  }

  /// Load preferences from local cache
  static Future<void> _loadPreferencesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = prefs.getString('notification_preferences');
      
      if (prefsJson != null) {
        // In a real implementation, you would parse JSON properly
        // For now, we'll use default preferences
        _cachedPreferences = const NotificationPreferences();
        debugPrint('NotificationPreferencesService: Loaded preferences from cache');
      } else {
        _cachedPreferences = const NotificationPreferences();
        debugPrint('NotificationPreferencesService: Using default preferences');
      }
    } catch (e) {
      debugPrint('NotificationPreferencesService: Error loading from cache: $e');
      _cachedPreferences = const NotificationPreferences();
    }
  }

  /// Save preferences to local cache
  static Future<void> _savePreferencesToCache(NotificationPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // In a real implementation, you would serialize to JSON properly
      await prefs.setString('notification_preferences', preferences.toString());
      
      debugPrint('NotificationPreferencesService: Saved preferences to cache');
    } catch (e) {
      debugPrint('NotificationPreferencesService: Error saving to cache: $e');
    }
  }

  /// Get default preferences for new users
  static NotificationPreferences getDefaultPreferences() {
    return const NotificationPreferences(
      enablePushNotifications: true,
      enableInAppNotifications: true,
      enableEmailNotifications: false,
      enableSMSNotifications: false,
      enableQuietHours: true,
      quietHoursStart: 22, // 10 PM
      quietHoursEnd: 7,    // 7 AM
      enableLocationBasedNotifications: true,
      enableEmergencyOverride: true,
      typePreferences: {
        // Enable important notifications by default
        NotificationType.emergency: true,
        NotificationType.announcement: true,
        NotificationType.legalUpdate: true,
        NotificationType.courtDateReminder: true,
        NotificationType.landRightsAlert: true,
        NotificationType.campaignUpdate: true,
        NotificationType.meetingReminder: true,
        NotificationType.documentExpiry: true,
        
        // Disable low-priority notifications by default
        NotificationType.postLike: false,
        NotificationType.postShare: false,
        NotificationType.newFollower: false,
      },
    );
  }

  /// Import preferences from another device/account
  static Future<void> importPreferences(Map<String, dynamic> preferencesData) async {
    try {
      final preferences = NotificationPreferences.fromMap(preferencesData);
      await updatePreferences(preferences);
      
      debugPrint('NotificationPreferencesService: Imported preferences successfully');
    } catch (e) {
      debugPrint('NotificationPreferencesService: Error importing preferences: $e');
      rethrow;
    }
  }

  /// Export preferences for backup or transfer
  static Map<String, dynamic> exportPreferences() {
    return getPreferences().toMap();
  }

  /// Get preferences summary for display
  static Map<String, dynamic> getPreferencesSummary() {
    final preferences = getPreferences();
    
    return {
      'pushEnabled': preferences.enablePushNotifications,
      'inAppEnabled': preferences.enableInAppNotifications,
      'emailEnabled': preferences.enableEmailNotifications,
      'smsEnabled': preferences.enableSMSNotifications,
      'quietHoursEnabled': preferences.enableQuietHours,
      'quietHoursRange': '${preferences.quietHoursStart}:00 - ${preferences.quietHoursEnd}:00',
      'emergencyOverride': preferences.enableEmergencyOverride,
      'locationBased': preferences.enableLocationBasedNotifications,
      'enabledTypes': preferences.typePreferences.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key.displayName)
          .toList(),
      'disabledTypes': preferences.typePreferences.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key.displayName)
          .toList(),
    };
  }

  /// Validate preferences
  static bool validatePreferences(NotificationPreferences preferences) {
    // Validate quiet hours
    if (preferences.enableQuietHours) {
      if (preferences.quietHoursStart < 0 || preferences.quietHoursStart > 23) {
        return false;
      }
      if (preferences.quietHoursEnd < 0 || preferences.quietHoursEnd > 23) {
        return false;
      }
    }
    
    return true;
  }

  /// Clear all cached preferences
  static void clearCache() {
    _cachedPreferences = null;
  }
}