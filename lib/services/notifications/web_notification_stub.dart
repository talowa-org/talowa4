// Web stub for flutter_local_notifications
// This file provides empty implementations for web platform

class FlutterLocalNotificationsPlugin {
  Future<void> initialize(
    dynamic initializationSettings, {
    dynamic onDidReceiveNotificationResponse,
  }) async {
    // No-op on web
  }

  Future<void> show(
    int id,
    String? title,
    String? body,
    dynamic notificationDetails, {
    String? payload,
  }) async {
    // No-op on web - could implement web notifications here
  }

  T? resolvePlatformSpecificImplementation<T>() => null;
}

class AndroidFlutterLocalNotificationsPlugin {
  Future<void> createNotificationChannel(dynamic channel) async {
    // No-op on web
  }
}

class InitializationSettings {
  const InitializationSettings({
    dynamic android,
    dynamic iOS,
  });
}

class AndroidInitializationSettings {
  const AndroidInitializationSettings(String icon);
}

class DarwinInitializationSettings {
  const DarwinInitializationSettings({
    bool? requestAlertPermission,
    bool? requestBadgePermission,
    bool? requestSoundPermission,
  });
}

class AndroidNotificationChannel {
  const AndroidNotificationChannel(
    String id,
    String name, {
    String? description,
    dynamic importance,
    dynamic sound,
  });
}

class AndroidNotificationDetails {
  const AndroidNotificationDetails(
    String channelId,
    String channelName, {
    String? channelDescription,
    dynamic importance,
    dynamic priority,
    bool? playSound,
    bool? enableVibration,
    dynamic sound,
  });
}

class DarwinNotificationDetails {
  const DarwinNotificationDetails({
    bool? presentAlert,
    bool? presentBadge,
    bool? presentSound,
    String? sound,
    dynamic interruptionLevel,
  });
}

class NotificationDetails {
  const NotificationDetails({
    dynamic android,
    dynamic iOS,
  });
}

class NotificationResponse {
  final String? payload;
  const NotificationResponse({this.payload});
}

class RawResourceAndroidNotificationSound {
  const RawResourceAndroidNotificationSound(String sound);
}

// Enums
enum Importance { defaultImportance, low, high, max }
enum Priority { defaultPriority, low, high, max }
enum InterruptionLevel { active, critical }
