// Analytics Service for TALOWA
// Track user interactions and app performance
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool _isInitialized = false;
  final List<AnalyticsEvent> _eventQueue = [];

  /// Initialize analytics service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // TODO: Initialize actual analytics SDK (Firebase Analytics, etc.)
      _isInitialized = true;
      debugPrint('✅ Analytics Service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Analytics Service: $e');
    }
  }

  /// Track an event
  void trackEvent(String eventName, [Map<String, dynamic>? parameters]) {
    if (!_isInitialized) {
      // Queue events until initialized
      _eventQueue.add(AnalyticsEvent(eventName, parameters));
      return;
    }

    try {
      // TODO: Send to actual analytics service
      debugPrint('📊 Analytics Event: $eventName ${parameters ?? ''}');
      
      // Process queued events if any
      if (_eventQueue.isNotEmpty) {
        for (final event in _eventQueue) {
          debugPrint('📊 Queued Analytics Event: ${event.name} ${event.parameters ?? ''}');
        }
        _eventQueue.clear();
      }
    } catch (e) {
      debugPrint('❌ Failed to track event $eventName: $e');
    }
  }

  /// Track screen view
  void trackScreenView(String screenName, [Map<String, dynamic>? parameters]) {
    trackEvent('screen_view', {
      'screen_name': screenName,
      ...?parameters,
    });
  }

  /// Track user action
  void trackUserAction(String action, [Map<String, dynamic>? parameters]) {
    trackEvent('user_action', {
      'action': action,
      ...?parameters,
    });
  }

  /// Track performance metric
  void trackPerformance(String metric, double value, [Map<String, dynamic>? parameters]) {
    trackEvent('performance_metric', {
      'metric': metric,
      'value': value,
      ...?parameters,
    });
  }

  /// Track error
  void trackError(String error, [Map<String, dynamic>? parameters]) {
    trackEvent('error', {
      'error': error,
      ...?parameters,
    });
  }

  /// Set user properties
  void setUserProperties(Map<String, dynamic> properties) {
    try {
      // TODO: Set user properties in actual analytics service
      debugPrint('👤 User Properties: $properties');
    } catch (e) {
      debugPrint('❌ Failed to set user properties: $e');
    }
  }

  /// Set user ID
  void setUserId(String userId) {
    try {
      // TODO: Set user ID in actual analytics service
      debugPrint('👤 User ID: $userId');
    } catch (e) {
      debugPrint('❌ Failed to set user ID: $e');
    }
  }
}

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic>? parameters;

  AnalyticsEvent(this.name, this.parameters);
}