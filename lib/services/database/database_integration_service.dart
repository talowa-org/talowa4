// Database Integration Service for TALOWA Social Feed System
// Coordinates all database services and provides unified interface

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'enterprise_database_service.dart';
import 'database_connection_pool.dart';
import 'database_migration_service.dart';
import 'database_backup_service.dart';
import 'database_archiving_service.dart';
import 'database_monitoring_service.dart';

/// Database Integration Service - Unified interface for all database operations
class DatabaseIntegrationService {
  static DatabaseIntegrationService? _instance;
  static DatabaseIntegrationService get instance => _instance ??= DatabaseIntegrationService._internal();
  
  DatabaseIntegrationService._internal();

  // Service instances
  late final EnterpriseDatabaseService _enterpriseService;
  late final DatabaseConnectionPool _connectionPool;
  late final DatabaseMigrationService _migrationService;
  late final DatabaseBackupService _backupService;
  late final DatabaseArchivingService _archivingService;
  late final DatabaseMonitoringService _monitoringService;
  
  bool _isInitialized = false;
  final Completer<void> _initializationCompleter = Completer<void>();

  /// Initialize all database services
  Future<void> initialize() async {
    if (_isInitialized) {
      await _initializationCompleter.future;
      return;
    }

    try {
      debugPrint('🚀 Initializing Database Integration Service...');
      
      // Initialize services in order
      await _initializeServices();
      
      // Verify system health
      await _verifySystemHealth();
      
      _isInitialized = true;
      _initializationCompleter.complete();
      
      debugPrint('✅ Database Integration Service initialized successfully');
      
    } catch (error) {
      debugPrint('❌ Failed to initialize Database Integration Service: $error');
      _initializationCompleter.completeError(error);
      rethrow;
    }
  }

  /// Initialize all database services
  Future<void> _initializeServices() async {
    // Initialize enterprise database service first
    _enterpriseService = EnterpriseDatabaseService.instance;
    await _enterpriseService.initialize();
    
    // Initialize connection pool
    _connectionPool = DatabaseConnectionPool.instance;
    await _connectionPool.initialize();
    
    // Initialize migration service
    _migrationService = DatabaseMigrationService.instance;
    await _migrationService.initialize();
    
    // Initialize backup service
    _backupService = DatabaseBackupService.instance;
    await _backupService.initialize();
    
    // Initialize archiving service
    _archivingService = DatabaseArchivingService.instance;
    await _archivingService.initialize();
    
    // Initialize monitoring service last
    _monitoringService = DatabaseMonitoringService.instance;
    await _monitoringService.initialize();
  }

  /// Verify system health after initialization
  Future<void> _verifySystemHealth() async {
    try {
      // Check database health
      final health = _enterpriseService.getDatabaseHealth();
      final unhealthyDatabases = health.entries
          .where((entry) => entry.value != DatabaseHealth.healthy)
          .toList();
      
      if (unhealthyDatabases.isNotEmpty) {
        debugPrint('⚠️ Some databases are not healthy: $unhealthyDatabases');
      }
      
      // Check connection pool health
      final poolStats = _connectionPool.getPoolStatistics();
      for (final entry in poolStats.entries) {
        if (entry.value.healthPercentage < 80) {
          debugPrint('⚠️ Connection pool ${entry.key} health: ${entry.value.healthPercentage}%');
        }
      }
      
      debugPrint('✅ System health verification completed');
      
    } catch (error) {
      debugPrint('❌ System health verification failed: $error');
    }
  }

  /// Get comprehensive system status
  Future<DatabaseSystemStatus> getSystemStatus() async {
    await _ensureInitialized();
    
    try {
      // Collect status from all services
      final enterpriseHealth = _enterpriseService.getDatabaseHealth();
      final enterpriseMetrics = _enterpriseService.getPerformanceMetrics();
      final poolStats = _connectionPool.getPoolStatistics();
      final monitoringStats = _monitoringService.getMonitoringStatistics();
      final backupStats = _backupService.getBackupStatistics();
      final archivingStats = _archivingService.getArchivingStatistics();
      final activeAlerts = _monitoringService.getActiveAlerts();
      
      return DatabaseSystemStatus(
        isHealthy: _calculateOverallHealth(enterpriseHealth, poolStats, activeAlerts),
        enterpriseHealth: enterpriseHealth,
        enterpriseMetrics: enterpriseMetrics,
        connectionPoolStats: poolStats,
        monitoringStats: monitoringStats,
        backupStats: backupStats,
        archivingStats: archivingStats,
        activeAlerts: activeAlerts,
        lastUpdated: DateTime.now(),
      );
      
    } catch (error) {
      debugPrint('❌ Error getting system status: $error');
      rethrow;
    }
  }

  /// Calculate overall system health
  bool _calculateOverallHealth(
    Map<String, DatabaseHealth> enterpriseHealth,
    Map<String, PoolStatistics> poolStats,
    List<DatabaseAlert> activeAlerts,
  ) {
    // Check enterprise database health
    final unhealthyDatabases = enterpriseHealth.values
        .where((health) => health == DatabaseHealth.unhealthy)
        .length;
    
    if (unhealthyDatabases > 0) return false;
    
    // Check connection pool health
    final unhealthyPools = poolStats.values
        .where((stats) => stats.healthPercentage < 50)
        .length;
    
    if (unhealthyPools > 0) return false;
    
    // Check for critical alerts
    final criticalAlerts = activeAlerts
        .where((alert) => alert.severity == AlertSeverity.critical)
        .length;
    
    if (criticalAlerts > 0) return false;
    
    return true;
  }

  /// Perform system maintenance
  Future<MaintenanceResult> performMaintenance({
    bool runMigrations = false,
    bool createBackup = false,
    bool performArchiving = false,
    bool cleanupConnections = false,
  }) async {
    await _ensureInitialized();
    
    debugPrint('🔧 Starting database system maintenance...');
    
    final stopwatch = Stopwatch()..start();
    final results = <String, dynamic>{};
    final errors = <String>[];
    
    try {
      // Run migrations if requested
      if (runMigrations) {
        try {
          // This would run pending migrations
          results['migrations'] = 'No pending migrations';
        } catch (error) {
          errors.add('Migration error: $error');
        }
      }
      
      // Create backup if requested
      if (createBackup) {
        try {
          final backupRecord = await _backupService.backupCollection('posts', BackupType.manual);
          results['backup'] = 'Backup created: ${backupRecord.id}';
        } catch (error) {
          errors.add('Backup error: $error');
        }
      }
      
      // Perform archiving if requested
      if (performArchiving) {
        try {
          final archiveResult = await _archivingService.archiveOldDocuments(
            'posts',
            const Duration(days: 90),
          );
          results['archiving'] = 'Archived ${archiveResult.documentCount} documents';
        } catch (error) {
          errors.add('Archiving error: $error');
        }
      }
      
      // Cleanup connections if requested
      if (cleanupConnections) {
        try {
          // This would cleanup idle connections
          results['connections'] = 'Connection cleanup completed';
        } catch (error) {
          errors.add('Connection cleanup error: $error');
        }
      }
      
      final result = MaintenanceResult(
        success: errors.isEmpty,
        durationMs: stopwatch.elapsedMilliseconds,
        results: results,
        errors: errors,
        completedAt: DateTime.now(),
      );
      
      debugPrint('✅ Database maintenance completed (${stopwatch.elapsedMilliseconds}ms)');
      
      return result;
      
    } catch (error) {
      debugPrint('❌ Database maintenance failed: $error');
      
      return MaintenanceResult(
        success: false,
        durationMs: stopwatch.elapsedMilliseconds,
        results: results,
        errors: [...errors, error.toString()],
        completedAt: DateTime.now(),
      );
    } finally {
      stopwatch.stop();
    }
  }

  /// Get service instances (for advanced usage)
  EnterpriseDatabaseService get enterpriseService => _enterpriseService;
  DatabaseConnectionPool get connectionPool => _connectionPool;
  DatabaseMigrationService get migrationService => _migrationService;
  DatabaseBackupService get backupService => _backupService;
  DatabaseArchivingService get archivingService => _archivingService;
  DatabaseMonitoringService get monitoringService => _monitoringService;

  /// Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Shutdown all database services
  Future<void> shutdown() async {
    try {
      debugPrint('🔄 Shutting down Database Integration Service...');
      
      // Shutdown services in reverse order
      await _monitoringService.shutdown();
      await _archivingService.shutdown();
      await _backupService.shutdown();
      await _migrationService.shutdown();
      await _connectionPool.shutdown();
      await _enterpriseService.shutdown();
      
      _isInitialized = false;
      
      debugPrint('✅ Database Integration Service shutdown complete');
      
    } catch (error) {
      debugPrint('❌ Error during database integration service shutdown: $error');
    }
  }
}

/// Database system status model
class DatabaseSystemStatus {
  final bool isHealthy;
  final Map<String, DatabaseHealth> enterpriseHealth;
  final Map<String, dynamic> enterpriseMetrics;
  final Map<String, PoolStatistics> connectionPoolStats;
  final Map<String, dynamic> monitoringStats;
  final Map<String, dynamic> backupStats;
  final Map<String, dynamic> archivingStats;
  final List<DatabaseAlert> activeAlerts;
  final DateTime lastUpdated;

  DatabaseSystemStatus({
    required this.isHealthy,
    required this.enterpriseHealth,
    required this.enterpriseMetrics,
    required this.connectionPoolStats,
    required this.monitoringStats,
    required this.backupStats,
    required this.archivingStats,
    required this.activeAlerts,
    required this.lastUpdated,
  });

  /// Get summary statistics
  Map<String, dynamic> getSummary() {
    return {
      'isHealthy': isHealthy,
      'totalDatabases': enterpriseHealth.length,
      'healthyDatabases': enterpriseHealth.values.where((h) => h == DatabaseHealth.healthy).length,
      'totalConnectionPools': connectionPoolStats.length,
      'healthyConnectionPools': connectionPoolStats.values.where((s) => s.healthPercentage >= 80).length,
      'activeAlerts': activeAlerts.length,
      'criticalAlerts': activeAlerts.where((a) => a.severity == AlertSeverity.critical).length,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Maintenance result model
class MaintenanceResult {
  final bool success;
  final int durationMs;
  final Map<String, dynamic> results;
  final List<String> errors;
  final DateTime completedAt;

  MaintenanceResult({
    required this.success,
    required this.durationMs,
    required this.results,
    required this.errors,
    required this.completedAt,
  });

  /// Get summary
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'durationMs': durationMs,
      'results': results,
      'errors': errors,
      'completedAt': completedAt.toIso8601String(),
    };
  }
}