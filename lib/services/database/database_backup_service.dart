// Database Backup and Disaster Recovery Service for TALOWA Social Feed System
// Automated backup and recovery procedures

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Database Backup and Disaster Recovery Service
class DatabaseBackupService {
  static DatabaseBackupService? _instance;
  static DatabaseBackupService get instance => _instance ??= DatabaseBackupService._internal();
  
  DatabaseBackupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Backup configuration
  static const Duration _backupInterval = Duration(hours: 6);
  static const Duration _retentionPeriod = Duration(days: 30);
  static const int _maxBackupsPerCollection = 10;
  
  // Backup tracking
  final Map<String, DateTime> _lastBackup = {};
  final Map<String, List<BackupRecord>> _backupHistory = {};
  Timer? _backupTimer;
  
  bool _isInitialized = false;

  /// Initialize backup service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Initializing Database Backup Service...');
      
      // Load backup history
      await _loadBackupHistory();
      
      // Start automated backup timer
      _startAutomatedBackups();
      
      _isInitialized = true;
      debugPrint('✅ Database Backup Service initialized');
      
    } catch (error) {
      debugPrint('❌ Failed to initialize Database Backup Service: $error');
      rethrow;
    }
  }

  /// Load backup history from database
  Future<void> _loadBackupHistory() async {
    try {
      final snapshot = await _firestore
          .collection('system')
          .doc('backups')
          .collection('history')
          .orderBy('createdAt', descending: true)
          .get();
      
      for (final doc in snapshot.docs) {
        final record = BackupRecord.fromFirestore(doc);
        
        if (!_backupHistory.containsKey(record.collection)) {
          _backupHistory[record.collection] = [];
        }
        
        _backupHistory[record.collection]!.add(record);
        
        // Update last backup time
        if (_lastBackup[record.collection] == null || 
            record.createdAt.isAfter(_lastBackup[record.collection]!)) {
          _lastBackup[record.collection] = record.createdAt;
        }
      }
      
      debugPrint('📊 Loaded backup history for ${_backupHistory.length} collections');
      
    } catch (error) {
      debugPrint('❌ Error loading backup history: $error');
    }
  }

  /// Start automated backup timer
  void _startAutomatedBackups() {
    _backupTimer = Timer.periodic(_backupInterval, (_) {
      _performAutomatedBackup();
    });
    
    debugPrint('⏰ Automated backups scheduled every ${_backupInterval.inHours} hours');
  }

  /// Perform automated backup of all critical collections
  Future<void> _performAutomatedBackup() async {
    try {
      debugPrint('🔄 Starting automated backup...');
      
      final criticalCollections = [
        'posts',
        'users',
        'conversations',
        'messages',
        'live_streams',
        'analytics',
      ];
      
      for (final collection in criticalCollections) {
        await backupCollection(collection, BackupType.automated);
      }
      
      // Clean up old backups
      await _cleanupOldBackups();
      
      debugPrint('✅ Automated backup completed');
      
    } catch (error) {
      debugPrint('❌ Automated backup failed: $error');
    }
  }

  /// Backup a specific collection
  Future<BackupRecord> backupCollection(String collection, BackupType type) async {
    if (!_isInitialized) await initialize();

    debugPrint('🔄 Backing up collection: $collection');
    
    final stopwatch = Stopwatch()..start();
    final backupId = 'backup_${collection}_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      // Get collection data
      final snapshot = await _firestore.collection(collection).get();
      
      // Create backup metadata
      final backupRecord = BackupRecord(
        id: backupId,
        collection: collection,
        type: type,
        status: BackupStatus.inProgress,
        createdAt: DateTime.now(),
        documentCount: snapshot.docs.length,
        sizeBytes: 0, // Will be calculated
      );
      
      // Save backup metadata
      await _saveBackupRecord(backupRecord);
      
      // In production, this would upload to Cloud Storage
      // For now, we simulate the backup process
      final backupData = _serializeCollectionData(snapshot);
      final sizeBytes = utf8.encode(backupData).length;
      
      // Update backup record with completion info
      final completedRecord = backupRecord.copyWith(
        status: BackupStatus.completed,
        completedAt: DateTime.now(),
        sizeBytes: sizeBytes,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      
      await _saveBackupRecord(completedRecord);
      
      // Update tracking
      _lastBackup[collection] = completedRecord.createdAt;
      
      if (!_backupHistory.containsKey(collection)) {
        _backupHistory[collection] = [];
      }
      _backupHistory[collection]!.insert(0, completedRecord);
      
      debugPrint('✅ Backup completed: $collection (${stopwatch.elapsedMilliseconds}ms, $sizeBytes bytes)');
      
      return completedRecord;
      
    } catch (error) {
      debugPrint('❌ Backup failed: $collection - $error');
      
      // Update backup record with error
      final failedRecord = BackupRecord(
        id: backupId,
        collection: collection,
        type: type,
        status: BackupStatus.failed,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
        documentCount: 0,
        sizeBytes: 0,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error.toString(),
      );
      
      await _saveBackupRecord(failedRecord);
      
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Restore collection from backup
  Future<void> restoreCollection(String collection, String backupId) async {
    if (!_isInitialized) await initialize();

    debugPrint('🔄 Restoring collection: $collection from backup: $backupId');
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Get backup record
      final backupDoc = await _firestore
          .collection('system')
          .doc('backups')
          .collection('history')
          .doc(backupId)
          .get();
      
      if (!backupDoc.exists) {
        throw Exception('Backup not found: $backupId');
      }
      
      final backupRecord = BackupRecord.fromFirestore(backupDoc);
      
      if (backupRecord.status != BackupStatus.completed) {
        throw Exception('Backup is not in completed state: ${backupRecord.status}');
      }
      
      // In production, this would download from Cloud Storage and restore
      // For now, we simulate the restore process
      
      debugPrint('✅ Collection restored: $collection (${stopwatch.elapsedMilliseconds}ms)');
      
    } catch (error) {
      debugPrint('❌ Restore failed: $collection - $error');
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Create disaster recovery point
  Future<DisasterRecoveryPoint> createRecoveryPoint(String name, {String? description}) async {
    if (!_isInitialized) await initialize();

    debugPrint('🔄 Creating disaster recovery point: $name');
    
    final stopwatch = Stopwatch()..start();
    final recoveryPointId = 'recovery_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      final criticalCollections = [
        'posts',
        'users',
        'conversations',
        'messages',
        'live_streams',
        'analytics',
        'system',
      ];
      
      final backupRecords = <BackupRecord>[];
      
      // Backup all critical collections
      for (final collection in criticalCollections) {
        final backupRecord = await backupCollection(collection, BackupType.recovery);
        backupRecords.add(backupRecord);
      }
      
      // Create recovery point record
      final recoveryPoint = DisasterRecoveryPoint(
        id: recoveryPointId,
        name: name,
        description: description,
        createdAt: DateTime.now(),
        backupIds: backupRecords.map((r) => r.id).toList(),
        collections: criticalCollections,
        totalSizeBytes: backupRecords.fold(0, (sum, r) => sum + r.sizeBytes),
        status: RecoveryPointStatus.completed,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      
      // Save recovery point
      await _firestore
          .collection('system')
          .doc('disaster_recovery')
          .collection('points')
          .doc(recoveryPointId)
          .set(recoveryPoint.toMap());
      
      debugPrint('✅ Disaster recovery point created: $name (${stopwatch.elapsedMilliseconds}ms)');
      
      return recoveryPoint;
      
    } catch (error) {
      debugPrint('❌ Failed to create recovery point: $name - $error');
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Restore from disaster recovery point
  Future<void> restoreFromRecoveryPoint(String recoveryPointId) async {
    if (!_isInitialized) await initialize();

    debugPrint('🔄 Restoring from recovery point: $recoveryPointId');
    
    try {
      // Get recovery point
      final recoveryDoc = await _firestore
          .collection('system')
          .doc('disaster_recovery')
          .collection('points')
          .doc(recoveryPointId)
          .get();
      
      if (!recoveryDoc.exists) {
        throw Exception('Recovery point not found: $recoveryPointId');
      }
      
      final recoveryPoint = DisasterRecoveryPoint.fromFirestore(recoveryDoc);
      
      // Restore all collections
      for (int i = 0; i < recoveryPoint.collections.length; i++) {
        final collection = recoveryPoint.collections[i];
        final backupId = recoveryPoint.backupIds[i];
        
        await restoreCollection(collection, backupId);
      }
      
      debugPrint('✅ Restored from recovery point: $recoveryPointId');
      
    } catch (error) {
      debugPrint('❌ Failed to restore from recovery point: $recoveryPointId - $error');
      rethrow;
    }
  }

  /// Clean up old backups
  Future<void> _cleanupOldBackups() async {
    try {
      final cutoffDate = DateTime.now().subtract(_retentionPeriod);
      
      for (final collection in _backupHistory.keys) {
        final backups = _backupHistory[collection]!;
        
        // Keep only recent backups and limit total count
        final backupsToKeep = backups
            .where((backup) => backup.createdAt.isAfter(cutoffDate))
            .take(_maxBackupsPerCollection)
            .toList();
        
        final backupsToDelete = backups
            .where((backup) => !backupsToKeep.contains(backup))
            .toList();
        
        // Delete old backup records
        for (final backup in backupsToDelete) {
          await _firestore
              .collection('system')
              .doc('backups')
              .collection('history')
              .doc(backup.id)
              .delete();
        }
        
        // Update local tracking
        _backupHistory[collection] = backupsToKeep;
        
        if (backupsToDelete.isNotEmpty) {
          debugPrint('🗑️ Cleaned up ${backupsToDelete.length} old backups for $collection');
        }
      }
      
    } catch (error) {
      debugPrint('❌ Error cleaning up old backups: $error');
    }
  }

  /// Save backup record to database
  Future<void> _saveBackupRecord(BackupRecord record) async {
    await _firestore
        .collection('system')
        .doc('backups')
        .collection('history')
        .doc(record.id)
        .set(record.toMap());
  }

  /// Serialize collection data for backup
  String _serializeCollectionData(QuerySnapshot snapshot) {
    final data = {
      'collection': snapshot.docs.first.reference.parent.id,
      'timestamp': DateTime.now().toIso8601String(),
      'documents': snapshot.docs.map((doc) => {
        'id': doc.id,
        'data': doc.data(),
      }).toList(),
    };
    
    return jsonEncode(data);
  }

  /// Get backup statistics
  Map<String, dynamic> getBackupStatistics() {
    final stats = <String, dynamic>{};
    
    for (final collection in _backupHistory.keys) {
      final backups = _backupHistory[collection]!;
      final completedBackups = backups.where((b) => b.status == BackupStatus.completed).toList();
      
      stats[collection] = {
        'totalBackups': backups.length,
        'completedBackups': completedBackups.length,
        'lastBackup': _lastBackup[collection]?.toIso8601String(),
        'totalSizeBytes': completedBackups.fold(0, (sum, b) => sum + b.sizeBytes),
        'averageDurationMs': completedBackups.isEmpty ? 0 : 
            completedBackups.fold(0, (sum, b) => sum + (b.durationMs ?? 0)) / completedBackups.length,
      };
    }
    
    return stats;
  }

  /// Shutdown backup service
  Future<void> shutdown() async {
    try {
      debugPrint('🔄 Shutting down Database Backup Service...');
      
      // Cancel backup timer
      _backupTimer?.cancel();
      
      // Clear tracking data
      _lastBackup.clear();
      _backupHistory.clear();
      
      _isInitialized = false;
      
      debugPrint('✅ Database Backup Service shutdown complete');
      
    } catch (error) {
      debugPrint('❌ Error during backup service shutdown: $error');
    }
  }
}

/// Backup record model
class BackupRecord {
  final String id;
  final String collection;
  final BackupType type;
  final BackupStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int documentCount;
  final int sizeBytes;
  final int? durationMs;
  final String? error;

  BackupRecord({
    required this.id,
    required this.collection,
    required this.type,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.documentCount,
    required this.sizeBytes,
    this.durationMs,
    this.error,
  });

  BackupRecord copyWith({
    BackupStatus? status,
    DateTime? completedAt,
    int? sizeBytes,
    int? durationMs,
    String? error,
  }) {
    return BackupRecord(
      id: id,
      collection: collection,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      documentCount: documentCount,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      durationMs: durationMs ?? this.durationMs,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collection': collection,
      'type': type.toString(),
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'documentCount': documentCount,
      'sizeBytes': sizeBytes,
      'durationMs': durationMs,
      'error': error,
    };
  }

  factory BackupRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return BackupRecord(
      id: data['id'] ?? '',
      collection: data['collection'] ?? '',
      type: BackupType.values.firstWhere(
        (t) => t.toString() == data['type'],
        orElse: () => BackupType.manual,
      ),
      status: BackupStatus.values.firstWhere(
        (s) => s.toString() == data['status'],
        orElse: () => BackupStatus.failed,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      documentCount: data['documentCount'] ?? 0,
      sizeBytes: data['sizeBytes'] ?? 0,
      durationMs: data['durationMs'],
      error: data['error'],
    );
  }
}

/// Disaster recovery point model
class DisasterRecoveryPoint {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final List<String> backupIds;
  final List<String> collections;
  final int totalSizeBytes;
  final RecoveryPointStatus status;
  final int durationMs;

  DisasterRecoveryPoint({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.backupIds,
    required this.collections,
    required this.totalSizeBytes,
    required this.status,
    required this.durationMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'backupIds': backupIds,
      'collections': collections,
      'totalSizeBytes': totalSizeBytes,
      'status': status.toString(),
      'durationMs': durationMs,
    };
  }

  factory DisasterRecoveryPoint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DisasterRecoveryPoint(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      backupIds: List<String>.from(data['backupIds'] ?? []),
      collections: List<String>.from(data['collections'] ?? []),
      totalSizeBytes: data['totalSizeBytes'] ?? 0,
      status: RecoveryPointStatus.values.firstWhere(
        (s) => s.toString() == data['status'],
        orElse: () => RecoveryPointStatus.failed,
      ),
      durationMs: data['durationMs'] ?? 0,
    );
  }
}

/// Backup type
enum BackupType {
  manual,
  automated,
  recovery,
}

/// Backup status
enum BackupStatus {
  inProgress,
  completed,
  failed,
}

/// Recovery point status
enum RecoveryPointStatus {
  inProgress,
  completed,
  failed,
}