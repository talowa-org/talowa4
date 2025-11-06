// Messaging Database Initialization Service for TALOWA
// Requirements: 1.1, 1.2, 5.1, 5.2

import 'package:flutter/foundation.dart';
import 'database_integration_service.dart';
import 'database_connection_service.dart';
import 'user_discovery_service.dart';

class MessagingDatabaseInitService {
  static final MessagingDatabaseInitService _instance = MessagingDatabaseInitService._internal();
  factory MessagingDatabaseInitService() => _instance;
  MessagingDatabaseInitService._internal();

  bool _isInitialized = false;

  /// Initialize all messaging database services
  /// Requirements: 1.1, 1.2, 5.1, 5.2
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('MessagingDatabaseInitService: Already initialized');
      return;
    }

    try {
      debugPrint('MessagingDatabaseInitService: Starting initialization');

      // Initialize database connection service first
      await DatabaseConnectionService().initialize();
      debugPrint('MessagingDatabaseInitService: Database connection service initialized');

      // Initialize database integration service
      await DatabaseIntegrationService().initialize();
      debugPrint('MessagingDatabaseInitService: Database integration service initialized');

      // Initialize user discovery service
      await UserDiscoveryService().initialize();
      debugPrint('MessagingDatabaseInitService: User discovery service initialized');

      _isInitialized = true;
      debugPrint('MessagingDatabaseInitService: All services initialized successfully');

    } catch (e) {
      debugPrint('MessagingDatabaseInitService: Error during initialization: $e');
      rethrow;
    }
  }

  /// Check if services are initialized
  bool get isInitialized => _isInitialized;

  /// Get initialization status of all services
  Future<Map<String, dynamic>> getInitializationStatus() async {
    try {
      final connectionHealth = await DatabaseConnectionService().getConnectionHealth();
      final userCacheStats = UserDiscoveryService().getCacheStats();
      final connectionStats = DatabaseConnectionService().getOperationStats();

      return {
        'isInitialized': _isInitialized,
        'connectionHealth': connectionHealth.toMap(),
        'userCacheStats': userCacheStats,
        'connectionStats': connectionStats,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'isInitialized': _isInitialized,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Reset all services (for testing)
  Future<void> reset() async {
    try {
      debugPrint('MessagingDatabaseInitService: Resetting all services');

      // Clear caches
      UserDiscoveryService().clearCache();
      DatabaseConnectionService().clearStats();

      _isInitialized = false;
      debugPrint('MessagingDatabaseInitService: Reset completed');
    } catch (e) {
      debugPrint('MessagingDatabaseInitService: Error during reset: $e');
    }
  }
}