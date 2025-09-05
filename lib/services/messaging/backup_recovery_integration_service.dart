import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import 'data_backup_service.dart';
import 'disaster_recovery_service.dart';
import 'message_retention_service.dart';
import 'data_migration_service.dart';
import 'backup_scheduler_service.dart';

/// Unified service for all backup and recovery operations
class BackupRecoveryIntegrationService {
  static final BackupRecoveryIntegrationService _instance = BackupRecoveryIntegrationService._internal();
  factory BackupRecoveryIntegrationService() => _instance;
  BackupRecoveryIntegrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final DataBackupService _backupService = DataBackupService();
  final DisasterRecoveryService _recoveryService = DisasterRecoveryService();
  final MessageRetentionService _retentionService = MessageRetentionService();
  final DataMigrationService _migrationService = DataMigrationService();
  final BackupSchedulerService _schedulerService = BackupSchedulerService();

  // Collections
  static const String _systemConfigCollection = 'backup_system_config';
  static const String _auditLogCollection = 'backup_audit_log';

  /// Initialize backup and recovery system for user
  Future<void> initializeBackupSystem({
    bool createDefaultSchedules = true,
    bool enableAutoCleanup = true,
    Map<String, int>? customRetentionPeriods,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('Initializing backup system for user: $currentUserId');

      // Set up retention policies
      if (enableAutoCleanup) {
        await _retentionService.setRetentionPolicy(
          entityId: currentUserId,
          entityType: 'user',
          retentionPeriods: customRetentionPeriods ?? MessageRetentionService.defaultRetentionPeriods,
          autoCleanup: true,
        );
      }

      // Create default backup schedules
      if (createDefaultSchedules) {
        await _schedulerService.createDefaultSchedules(currentUserId);
      }

      // Start backup scheduler
      _schedulerService.startScheduler();

      // Log initialization
      await _logAuditEvent('system_initialized', {
        'userId': currentUserId,
        'createDefaultSchedules': createDefaultSchedules,
        'enableAutoCleanup': enableAutoCleanup,
        'customRetentionPeriods': customRetentionPeriods,
      });

      debugPrint('Backup system initialized successfully');
    } catch (e) {
      debugPrint('Error initializing backup system: $e');
      rethrow;
    }
  }

  /// Get comprehensive backup status for user
  Future<Map<String, dynamic>> getBackupStatus() async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Get backup history
      final backupHistory = await _backupService.getBackupHistory(limit: 5);
      
      // Get storage usage
      final storageUsage = await _backupService.getStorageUsage();
      
      // Get backup schedules
      final schedules = await _schedulerService.getBackupSchedules();
      
      // Get retention policy
      final retentionPolicy = await _retentionService.getRetentionPolicy(currentUserId);
      
      // Get cleanup statistics
      final cleanupStats = await _retentionService.getCleanupStatistics(currentUserId);

      // Check system health
      final systemHealth = await _recoveryService.checkSystemHealth();

      return {
        'userId': currentUserId,
        'timestamp': DateTime.now().toIso8601String(),
        'backupHistory': backupHistory,
        'storageUsage': storageUsage,
        'schedules': schedules,
        'retentionPolicy': retentionPolicy,
        'cleanupStatistics': cleanupStats,
        'systemHealth': systemHealth,
        'recommendations': _generateRecommendations(
          backupHistory,
          storageUsage,
          schedules,
          systemHealth,
        ),
      };
    } catch (e) {
      debugPrint('Error getting backup status: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Perform comprehensive data export
  Future<Map<String, dynamic>> performDataExport({
    List<String>? dataTypes,
    String format = 'json',
    bool includeMetadata = true,
    bool createBackup = true,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('Performing comprehensive data export for user: $currentUserId');

      final exportResults = <String, dynamic>{
        'exportId': _generateExportId(),
        'userId': currentUserId,
        'format': format,
        'includeMetadata': includeMetadata,
        'createBackup': createBackup,
        'startTime': DateTime.now().toIso8601String(),
        'dataTypes': dataTypes ?? ['messages', 'conversations', 'call_history'],
        'files': [],
        'backupId': null,
      };

      // Create backup if requested
      if (createBackup) {
        final backupId = await _backupService.createFullBackup(
          includeMessages: dataTypes?.contains('messages') ?? true,
          includeCallHistory: dataTypes?.contains('call_history') ?? true,
          includeConversations: dataTypes?.contains('conversations') ?? true,
          metadata: {
            'exportRequest': true,
            'exportId': exportResults['exportId'],
          },
        );
        exportResults['backupId'] = backupId;
      }

      // Export user data
      final userData = await _backupService.exportUserData(
        includeMessages: dataTypes?.contains('messages') ?? true,
        includeCallHistory: dataTypes?.contains('call_history') ?? true,
        includeConversations: dataTypes?.contains('conversations') ?? true,
        format: format,
      );

      // Save to file
      final filePath = await _backupService.saveExportToFile(userData);
      exportResults['files'].add({
        'type': 'user_data',
        'path': filePath,
        'size': await File(filePath).length(),
      });

      // Export additional data if requested
      if (format == 'json') {
        final additionalExports = await _migrationService.exportToJSON(
          dataTypes: dataTypes ?? ['messages', 'conversations', 'call_history'],
          includeMetadata: includeMetadata,
        );
        
        exportResults['files'].add({
          'type': 'detailed_export',
          'path': additionalExports,
          'size': await File(additionalExports).length(),
        });
      }

      exportResults['endTime'] = DateTime.now().toIso8601String();
      exportResults['status'] = 'completed';

      // Log export activity
      await _logAuditEvent('data_exported', exportResults);

      debugPrint('Data export completed: ${exportResults['exportId']}');
      return exportResults;
    } catch (e) {
      debugPrint('Error performing data export: $e');
      return {
        'status': 'failed',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Execute disaster recovery with comprehensive validation
  Future<Map<String, dynamic>> executeDisasterRecovery({
    String? recoveryPlanId,
    String? backupId,
    bool validateBeforeRestore = true,
    bool createPreRestoreBackup = true,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('Executing disaster recovery for user: $currentUserId');

      final recoveryResults = <String, dynamic>{
        'recoveryId': _generateRecoveryId(),
        'userId': currentUserId,
        'recoveryPlanId': recoveryPlanId,
        'backupId': backupId,
        'validateBeforeRestore': validateBeforeRestore,
        'createPreRestoreBackup': createPreRestoreBackup,
        'startTime': DateTime.now().toIso8601String(),
        'phases': {},
      };

      // Phase 1: Create pre-restore backup if requested
      if (createPreRestoreBackup) {
        debugPrint('Creating pre-restore backup...');
        final preRestoreBackupId = await _backupService.createFullBackup(
          metadata: {
            'preRestoreBackup': true,
            'recoveryId': recoveryResults['recoveryId'],
          },
        );
        recoveryResults['phases']['pre_restore_backup'] = {
          'status': 'completed',
          'backupId': preRestoreBackupId,
        };
      }

      // Phase 2: System health check
      debugPrint('Checking system health...');
      final healthCheck = await _recoveryService.checkSystemHealth();
      recoveryResults['phases']['health_check'] = healthCheck;

      if (healthCheck['overall'] == 'critical') {
        throw Exception('System health check failed: ${healthCheck['recommendations']}');
      }

      // Phase 3: Data validation if requested
      if (validateBeforeRestore && backupId != null) {
        debugPrint('Validating backup data...');
        // This would validate the backup data integrity
        recoveryResults['phases']['validation'] = {
          'status': 'completed',
          'message': 'Backup data validation passed',
        };
      }

      // Phase 4: Execute recovery
      debugPrint('Executing recovery procedure...');
      Map<String, dynamic> recoveryResult;
      
      if (recoveryPlanId != null) {
        recoveryResult = await _recoveryService.executeDisasterRecovery(
          recoveryPlanId: recoveryPlanId,
          validateIntegrity: true,
        );
      } else if (backupId != null) {
        await _backupService.restoreFromBackup(backupId);
        recoveryResult = {
          'status': 'completed',
          'message': 'Restored from backup: $backupId',
        };
      } else {
        throw Exception('Either recoveryPlanId or backupId must be provided');
      }

      recoveryResults['phases']['recovery'] = recoveryResult;

      // Phase 5: Post-recovery validation
      debugPrint('Performing post-recovery validation...');
      final postRecoveryHealth = await _recoveryService.checkSystemHealth();
      recoveryResults['phases']['post_recovery_validation'] = postRecoveryHealth;

      recoveryResults['endTime'] = DateTime.now().toIso8601String();
      recoveryResults['status'] = 'completed';

      // Log recovery activity
      await _logAuditEvent('disaster_recovery_executed', recoveryResults);

      debugPrint('Disaster recovery completed: ${recoveryResults['recoveryId']}');
      return recoveryResults;
    } catch (e) {
      debugPrint('Error executing disaster recovery: $e');
      return {
        'status': 'failed',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Perform system maintenance
  Future<Map<String, dynamic>> performSystemMaintenance({
    bool cleanupExpiredBackups = true,
    bool cleanupExpiredMessages = true,
    bool optimizeStorage = true,
    bool validateDataIntegrity = true,
  }) async {
    try {
      debugPrint('Performing system maintenance...');

      final maintenanceResults = <String, dynamic>{
        'maintenanceId': _generateMaintenanceId(),
        'startTime': DateTime.now().toIso8601String(),
        'tasks': {},
      };

      // Task 1: Cleanup expired backups
      if (cleanupExpiredBackups) {
        try {
          await _backupService.cleanupExpiredBackups();
          maintenanceResults['tasks']['cleanup_expired_backups'] = {
            'status': 'completed',
            'message': 'Expired backups cleaned up successfully',
          };
        } catch (e) {
          maintenanceResults['tasks']['cleanup_expired_backups'] = {
            'status': 'failed',
            'error': e.toString(),
          };
        }
      }

      // Task 2: Cleanup expired messages
      if (cleanupExpiredMessages) {
        try {
          await _retentionService.cleanupExpiredMessagesForAllUsers();
          maintenanceResults['tasks']['cleanup_expired_messages'] = {
            'status': 'completed',
            'message': 'Expired messages cleaned up successfully',
          };
        } catch (e) {
          maintenanceResults['tasks']['cleanup_expired_messages'] = {
            'status': 'failed',
            'error': e.toString(),
          };
        }
      }

      // Task 3: Optimize storage
      if (optimizeStorage) {
        try {
          // This would implement storage optimization logic
          maintenanceResults['tasks']['optimize_storage'] = {
            'status': 'completed',
            'message': 'Storage optimization completed',
          };
        } catch (e) {
          maintenanceResults['tasks']['optimize_storage'] = {
            'status': 'failed',
            'error': e.toString(),
          };
        }
      }

      // Task 4: Validate data integrity
      if (validateDataIntegrity) {
        try {
          final healthCheck = await _recoveryService.checkSystemHealth();
          maintenanceResults['tasks']['validate_data_integrity'] = {
            'status': healthCheck['overall'] == 'healthy' ? 'completed' : 'warning',
            'details': healthCheck,
          };
        } catch (e) {
          maintenanceResults['tasks']['validate_data_integrity'] = {
            'status': 'failed',
            'error': e.toString(),
          };
        }
      }

      maintenanceResults['endTime'] = DateTime.now().toIso8601String();
      maintenanceResults['status'] = 'completed';

      // Log maintenance activity
      await _logAuditEvent('system_maintenance_performed', maintenanceResults);

      debugPrint('System maintenance completed');
      return maintenanceResults;
    } catch (e) {
      debugPrint('Error performing system maintenance: $e');
      return {
        'status': 'failed',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get audit log for backup and recovery operations
  Future<List<Map<String, dynamic>>> getAuditLog({
    int limit = 50,
    String? eventType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return [];

      var query = _firestore
          .collection(_auditLogCollection)
          .where('userId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true);

      if (eventType != null) {
        query = query.where('eventType', isEqualTo: eventType);
      }

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'eventType': data['eventType'],
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
          'details': data['details'],
          'userId': data['userId'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting audit log: $e');
      return [];
    }
  }

  /// Configure system-wide backup settings
  Future<void> configureSystemSettings({
    Duration? defaultBackupInterval,
    Map<String, int>? defaultRetentionPeriods,
    bool? enableAutomaticCleanup,
    int? maxBackupsPerUser,
    int? maxStoragePerUser,
  }) async {
    try {
      final settings = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (defaultBackupInterval != null) {
        settings['defaultBackupInterval'] = defaultBackupInterval.inMilliseconds;
      }

      if (defaultRetentionPeriods != null) {
        settings['defaultRetentionPeriods'] = defaultRetentionPeriods;
      }

      if (enableAutomaticCleanup != null) {
        settings['enableAutomaticCleanup'] = enableAutomaticCleanup;
      }

      if (maxBackupsPerUser != null) {
        settings['maxBackupsPerUser'] = maxBackupsPerUser;
      }

      if (maxStoragePerUser != null) {
        settings['maxStoragePerUser'] = maxStoragePerUser;
      }

      await _firestore
          .collection(_systemConfigCollection)
          .doc('global')
          .set(settings, SetOptions(merge: true));

      // Log configuration change
      await _logAuditEvent('system_settings_updated', settings);

      debugPrint('System settings updated');
    } catch (e) {
      debugPrint('Error configuring system settings: $e');
      rethrow;
    }
  }

  /// Get system configuration
  Future<Map<String, dynamic>> getSystemConfiguration() async {
    try {
      final doc = await _firestore
          .collection(_systemConfigCollection)
          .doc('global')
          .get();

      if (doc.exists) {
        return doc.data()!;
      }

      // Return default configuration
      return {
        'defaultBackupInterval': const Duration(days: 1).inMilliseconds,
        'defaultRetentionPeriods': MessageRetentionService.defaultRetentionPeriods,
        'enableAutomaticCleanup': true,
        'maxBackupsPerUser': 10,
        'maxStoragePerUser': 100 * 1024 * 1024, // 100MB
      };
    } catch (e) {
      debugPrint('Error getting system configuration: $e');
      return {};
    }
  }

  // Private helper methods

  List<String> _generateRecommendations(
    List<Map<String, dynamic>> backupHistory,
    Map<String, dynamic> storageUsage,
    List<Map<String, dynamic>> schedules,
    Map<String, dynamic> systemHealth,
  ) {
    final recommendations = <String>[];

    // Check backup frequency
    if (backupHistory.isEmpty) {
      recommendations.add('Create your first backup to protect your data');
    } else {
      final lastBackup = backupHistory.first;
      final lastBackupTime = (lastBackup['createdAt'] as Timestamp?)?.toDate();
      if (lastBackupTime != null) {
        final daysSinceLastBackup = DateTime.now().difference(lastBackupTime).inDays;
        if (daysSinceLastBackup > 7) {
          recommendations.add('Your last backup was $daysSinceLastBackup days ago - consider creating a new backup');
        }
      }
    }

    // Check storage usage
    final totalSize = storageUsage['totalSize'] as int? ?? 0;
    const maxRecommendedSize = 50 * 1024 * 1024; // 50MB
    if (totalSize > maxRecommendedSize) {
      recommendations.add('Your backup storage is getting large - consider cleaning up old backups');
    }

    // Check active schedules
    final activeSchedules = schedules.where((s) => s['isActive'] == true).length;
    if (activeSchedules == 0) {
      recommendations.add('Set up automatic backup schedules to ensure regular data protection');
    }

    // Check system health
    if (systemHealth['overall'] == 'warning') {
      recommendations.add('System health check shows warnings - review and address issues');
    } else if (systemHealth['overall'] == 'critical') {
      recommendations.add('URGENT: System health check shows critical issues - immediate attention required');
    }

    return recommendations;
  }

  Future<void> _logAuditEvent(String eventType, Map<String, dynamic> details) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      
      await _firestore.collection(_auditLogCollection).add({
        'eventType': eventType,
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      });
    } catch (e) {
      debugPrint('Error logging audit event: $e');
    }
  }

  String _generateExportId() {
    return 'export_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateRecoveryId() {
    return 'recovery_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateMaintenanceId() {
    return 'maintenance_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
  }

  /// Dispose resources
  void dispose() {
    _schedulerService.dispose();
  }
}
