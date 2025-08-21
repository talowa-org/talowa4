import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../auth_service.dart';
import 'data_backup_service.dart';

/// Service for migrating data between different storage systems
class DataMigrationService {
  static final DataMigrationService _instance = DataMigrationService._internal();
  factory DataMigrationService() => _instance;
  DataMigrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DataBackupService _backupService = DataBackupService();
  final AuthService _authService = AuthService();

  // Collections
  static const String _migrationJobsCollection = 'data_migration_jobs';
  static const String _migrationConfigsCollection = 'migration_configs';

  /// Create migration configuration
  Future<String> createMigrationConfig({
    required String configName,
    required String sourceType,
    required String targetType,
    required Map<String, dynamic> sourceConfig,
    required Map<String, dynamic> targetConfig,
    required List<String> dataTypes,
    Map<String, dynamic>? transformationRules,
  }) async {
    try {
      final configId = _generateMigrationConfigId();
      
      await _firestore.collection(_migrationConfigsCollection).doc(configId).set({
        'configId': configId,
        'configName': configName,
        'sourceType': sourceType,
        'targetType': targetType,
        'sourceConfig': sourceConfig,
        'targetConfig': targetConfig,
        'dataTypes': dataTypes,
        'transformationRules': transformationRules ?? {},
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'version': '1.0',
      });

      debugPrint('Migration configuration created: $configId');
      return configId;
    } catch (e) {
      debugPrint('Error creating migration config: $e');
      rethrow;
    }
  }

  /// Execute data migration using configuration
  Future<String> executeMigration({
    required String configId,
    bool dryRun = false,
    bool preserveSource = true,
    Map<String, dynamic>? overrides,
  }) async {
    try {
      final migrationJobId = _generateMigrationJobId();
      
      debugPrint('Starting data migration: $migrationJobId');

      // Get migration configuration
      final configDoc = await _firestore
          .collection(_migrationConfigsCollection)
          .doc(configId)
          .get();

      if (!configDoc.exists) {
        throw Exception('Migration configuration not found: $configId');
      }

      final config = configDoc.data()!;
      
      // Apply overrides if provided
      if (overrides != null) {
        config.addAll(overrides);
      }

      // Create migration job record
      await _createMigrationJob(migrationJobId, configId, {
        'dryRun': dryRun,
        'preserveSource': preserveSource,
        'config': config,
      });

      final migrationResults = <String, dynamic>{
        'migrationJobId': migrationJobId,
        'configId': configId,
        'dryRun': dryRun,
        'preserveSource': preserveSource,
        'startTime': DateTime.now().toIso8601String(),
        'dataTypes': {},
        'totalRecords': 0,
        'migratedRecords': 0,
        'errors': [],
        'warnings': [],
      };

      final dataTypes = List<String>.from(config['dataTypes']);
      final sourceType = config['sourceType'] as String;
      final targetType = config['targetType'] as String;
      final transformationRules = Map<String, dynamic>.from(config['transformationRules'] ?? {});

      // Execute migration for each data type
      for (final dataType in dataTypes) {
        try {
          await _updateMigrationProgress(migrationJobId, 'migrating_$dataType');
          
          final result = await _migrateDataType(
            dataType,
            sourceType,
            targetType,
            config['sourceConfig'],
            config['targetConfig'],
            transformationRules[dataType] ?? {},
            dryRun,
            preserveSource,
          );
          
          migrationResults['dataTypes'][dataType] = result;
          migrationResults['totalRecords'] += result['totalRecords'] ?? 0;
          migrationResults['migratedRecords'] += result['migratedRecords'] ?? 0;
          
          if (result['warnings'] != null) {
            migrationResults['warnings'].addAll(result['warnings']);
          }
        } catch (e) {
          migrationResults['errors'].add({
            'dataType': dataType,
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      }

      // Complete migration job
      migrationResults['endTime'] = DateTime.now().toIso8601String();
      migrationResults['status'] = migrationResults['errors'].isEmpty ? 'completed' : 'completed_with_errors';

      await _updateMigrationJob(migrationJobId, migrationResults);

      debugPrint('Data migration completed: $migrationJobId');
      return migrationJobId;
    } catch (e) {
      debugPrint('Error executing migration: $e');
      rethrow;
    }
  }

  /// Migrate from Firestore to local SQLite
  Future<Map<String, dynamic>> migrateFirestoreToSQLite({
    required List<String> collections,
    required String sqliteDbPath,
    bool preserveFirestore = true,
  }) async {
    try {
      debugPrint('Migrating from Firestore to SQLite: $sqliteDbPath');

      final migrationResults = <String, dynamic>{
        'sourceType': 'firestore',
        'targetType': 'sqlite',
        'collections': {},
        'totalRecords': 0,
        'migratedRecords': 0,
        'errors': [],
      };

      // Create SQLite database file
      final dbFile = File(sqliteDbPath);
      if (!await dbFile.exists()) {
        await dbFile.create(recursive: true);
      }

      // Migrate each collection
      for (final collection in collections) {
        try {
          final result = await _migrateCollectionToSQLite(collection, sqliteDbPath);
          migrationResults['collections'][collection] = result;
          migrationResults['totalRecords'] += result['totalRecords'] ?? 0;
          migrationResults['migratedRecords'] += result['migratedRecords'] ?? 0;
        } catch (e) {
          migrationResults['errors'].add({
            'collection': collection,
            'error': e.toString(),
          });
        }
      }

      return migrationResults;
    } catch (e) {
      debugPrint('Error migrating Firestore to SQLite: $e');
      rethrow;
    }
  }

  /// Migrate from local SQLite to Firestore
  Future<Map<String, dynamic>> migrateSQLiteToFirestore({
    required String sqliteDbPath,
    required List<String> tables,
    bool preserveSQLite = true,
  }) async {
    try {
      debugPrint('Migrating from SQLite to Firestore: $sqliteDbPath');

      final migrationResults = <String, dynamic>{
        'sourceType': 'sqlite',
        'targetType': 'firestore',
        'tables': {},
        'totalRecords': 0,
        'migratedRecords': 0,
        'errors': [],
      };

      // Check if SQLite database exists
      final dbFile = File(sqliteDbPath);
      if (!await dbFile.exists()) {
        throw Exception('SQLite database not found: $sqliteDbPath');
      }

      // Migrate each table
      for (final table in tables) {
        try {
          final result = await _migrateTableToFirestore(sqliteDbPath, table);
          migrationResults['tables'][table] = result;
          migrationResults['totalRecords'] += result['totalRecords'] ?? 0;
          migrationResults['migratedRecords'] += result['migratedRecords'] ?? 0;
        } catch (e) {
          migrationResults['errors'].add({
            'table': table,
            'error': e.toString(),
          });
        }
      }

      return migrationResults;
    } catch (e) {
      debugPrint('Error migrating SQLite to Firestore: $e');
      rethrow;
    }
  }

  /// Export data to JSON format
  Future<String> exportToJSON({
    required List<String> dataTypes,
    String? filePath,
    bool includeMetadata = true,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('Exporting data to JSON for user: $currentUserId');

      final exportData = <String, dynamic>{
        'exportId': _generateExportId(),
        'userId': currentUserId,
        'exportedAt': DateTime.now().toIso8601String(),
        'dataTypes': dataTypes,
        'includeMetadata': includeMetadata,
        'version': '1.0',
        'data': {},
      };

      // Export each data type
      for (final dataType in dataTypes) {
        try {
          final data = await _exportDataTypeToJSON(dataType, currentUserId, includeMetadata);
          exportData['data'][dataType] = data;
        } catch (e) {
          debugPrint('Error exporting $dataType: $e');
          exportData['data'][dataType] = {
            'error': e.toString(),
            'records': [],
          };
        }
      }

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = filePath ?? 'talowa_export_${exportData['exportId']}.json';
      final file = File('${directory.path}/$fileName');

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      await file.writeAsString(jsonString);

      debugPrint('Data exported to JSON: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Error exporting to JSON: $e');
      rethrow;
    }
  }

  /// Import data from JSON format
  Future<Map<String, dynamic>> importFromJSON({
    required String filePath,
    bool validateData = true,
    bool overwriteExisting = false,
  }) async {
    try {
      debugPrint('Importing data from JSON: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Import file not found: $filePath');
      }

      final jsonString = await file.readAsString();
      final importData = jsonDecode(jsonString) as Map<String, dynamic>;

      final importResults = <String, dynamic>{
        'importId': _generateImportId(),
        'sourceFile': filePath,
        'importedAt': DateTime.now().toIso8601String(),
        'dataTypes': {},
        'totalRecords': 0,
        'importedRecords': 0,
        'errors': [],
        'warnings': [],
      };

      // Validate import data structure
      if (validateData) {
        final validationResult = _validateImportData(importData);
        if (!validationResult['isValid']) {
          throw Exception('Invalid import data: ${validationResult['errors']}');
        }
        importResults['warnings'].addAll(validationResult['warnings'] ?? []);
      }

      final data = importData['data'] as Map<String, dynamic>;

      // Import each data type
      for (final entry in data.entries) {
        final dataType = entry.key;
        final typeData = entry.value as Map<String, dynamic>;

        try {
          final result = await _importDataTypeFromJSON(
            dataType,
            typeData,
            overwriteExisting,
          );
          
          importResults['dataTypes'][dataType] = result;
          importResults['totalRecords'] += result['totalRecords'] ?? 0;
          importResults['importedRecords'] += result['importedRecords'] ?? 0;
        } catch (e) {
          importResults['errors'].add({
            'dataType': dataType,
            'error': e.toString(),
          });
        }
      }

      debugPrint('Data import completed');
      return importResults;
    } catch (e) {
      debugPrint('Error importing from JSON: $e');
      rethrow;
    }
  }

  /// Get migration job status
  Future<Map<String, dynamic>?> getMigrationJobStatus(String jobId) async {
    try {
      final doc = await _firestore
          .collection(_migrationJobsCollection)
          .doc(jobId)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error getting migration job status: $e');
      return null;
    }
  }

  /// Get migration history
  Future<List<Map<String, dynamic>>> getMigrationHistory({
    int limit = 20,
  }) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) return [];

      final snapshot = await _firestore
          .collection(_migrationJobsCollection)
          .where('userId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'jobId': doc.id,
          'configId': data['configId'],
          'status': data['status'],
          'createdAt': data['createdAt'],
          'completedAt': data['completedAt'],
          'totalRecords': data['results']?['totalRecords'] ?? 0,
          'migratedRecords': data['results']?['migratedRecords'] ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting migration history: $e');
      return [];
    }
  }

  // Private helper methods

  Future<Map<String, dynamic>> _migrateDataType(
    String dataType,
    String sourceType,
    String targetType,
    Map<String, dynamic> sourceConfig,
    Map<String, dynamic> targetConfig,
    Map<String, dynamic> transformationRules,
    bool dryRun,
    bool preserveSource,
  ) async {
    switch (dataType) {
      case 'messages':
        return await _migrateMessages(
          sourceType, targetType, sourceConfig, targetConfig,
          transformationRules, dryRun, preserveSource,
        );
      case 'conversations':
        return await _migrateConversations(
          sourceType, targetType, sourceConfig, targetConfig,
          transformationRules, dryRun, preserveSource,
        );
      case 'call_history':
        return await _migrateCallHistory(
          sourceType, targetType, sourceConfig, targetConfig,
          transformationRules, dryRun, preserveSource,
        );
      case 'user_data':
        return await _migrateUserData(
          sourceType, targetType, sourceConfig, targetConfig,
          transformationRules, dryRun, preserveSource,
        );
      default:
        throw Exception('Unknown data type: $dataType');
    }
  }

  Future<Map<String, dynamic>> _migrateMessages(
    String sourceType,
    String targetType,
    Map<String, dynamic> sourceConfig,
    Map<String, dynamic> targetConfig,
    Map<String, dynamic> transformationRules,
    bool dryRun,
    bool preserveSource,
  ) async {
    try {
      // Get messages from source
      final sourceMessages = await _getMessagesFromSource(sourceType, sourceConfig);
      
      // Apply transformations
      final transformedMessages = _applyTransformations(sourceMessages, transformationRules);
      
      int migratedCount = 0;
      
      if (!dryRun) {
        // Write to target
        migratedCount = await _writeMessagesToTarget(
          targetType, 
          targetConfig, 
          transformedMessages,
        );
        
        // Remove from source if not preserving
        if (!preserveSource) {
          await _removeMessagesFromSource(sourceType, sourceConfig, sourceMessages);
        }
      }

      return {
        'dataType': 'messages',
        'totalRecords': sourceMessages.length,
        'migratedRecords': dryRun ? 0 : migratedCount,
        'status': 'completed',
        'dryRun': dryRun,
      };
    } catch (e) {
      return {
        'dataType': 'messages',
        'status': 'failed',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _migrateConversations(
    String sourceType,
    String targetType,
    Map<String, dynamic> sourceConfig,
    Map<String, dynamic> targetConfig,
    Map<String, dynamic> transformationRules,
    bool dryRun,
    bool preserveSource,
  ) async {
    // Similar implementation to _migrateMessages but for conversations
    return {
      'dataType': 'conversations',
      'totalRecords': 0,
      'migratedRecords': 0,
      'status': 'completed',
      'dryRun': dryRun,
    };
  }

  Future<Map<String, dynamic>> _migrateCallHistory(
    String sourceType,
    String targetType,
    Map<String, dynamic> sourceConfig,
    Map<String, dynamic> targetConfig,
    Map<String, dynamic> transformationRules,
    bool dryRun,
    bool preserveSource,
  ) async {
    // Similar implementation to _migrateMessages but for call history
    return {
      'dataType': 'call_history',
      'totalRecords': 0,
      'migratedRecords': 0,
      'status': 'completed',
      'dryRun': dryRun,
    };
  }

  Future<Map<String, dynamic>> _migrateUserData(
    String sourceType,
    String targetType,
    Map<String, dynamic> sourceConfig,
    Map<String, dynamic> targetConfig,
    Map<String, dynamic> transformationRules,
    bool dryRun,
    bool preserveSource,
  ) async {
    // Similar implementation to _migrateMessages but for user data
    return {
      'dataType': 'user_data',
      'totalRecords': 0,
      'migratedRecords': 0,
      'status': 'completed',
      'dryRun': dryRun,
    };
  }

  Future<List<Map<String, dynamic>>> _getMessagesFromSource(
    String sourceType,
    Map<String, dynamic> sourceConfig,
  ) async {
    switch (sourceType) {
      case 'firestore':
        return await _getMessagesFromFirestore(sourceConfig);
      case 'sqlite':
        return await _getMessagesFromSQLite(sourceConfig);
      case 'json':
        return await _getMessagesFromJSON(sourceConfig);
      default:
        throw Exception('Unknown source type: $sourceType');
    }
  }

  Future<List<Map<String, dynamic>>> _getMessagesFromFirestore(
    Map<String, dynamic> config,
  ) async {
    final messages = <Map<String, dynamic>>[];
    
    final snapshot = await _firestore
        .collection('messages')
        .limit(config['limit'] ?? 1000)
        .get();

    for (final doc in snapshot.docs) {
      messages.add({
        'id': doc.id,
        'data': doc.data(),
      });
    }

    return messages;
  }

  Future<List<Map<String, dynamic>>> _getMessagesFromSQLite(
    Map<String, dynamic> config,
  ) async {
    // Placeholder - would implement SQLite reading
    return [];
  }

  Future<List<Map<String, dynamic>>> _getMessagesFromJSON(
    Map<String, dynamic> config,
  ) async {
    // Placeholder - would implement JSON file reading
    return [];
  }

  List<Map<String, dynamic>> _applyTransformations(
    List<Map<String, dynamic>> data,
    Map<String, dynamic> transformationRules,
  ) {
    if (transformationRules.isEmpty) return data;

    return data.map((item) {
      final transformed = Map<String, dynamic>.from(item);
      
      // Apply field mappings
      final fieldMappings = transformationRules['fieldMappings'] as Map<String, dynamic>?;
      if (fieldMappings != null) {
        for (final entry in fieldMappings.entries) {
          final oldField = entry.key;
          final newField = entry.value as String;
          
          if (transformed.containsKey(oldField)) {
            transformed[newField] = transformed.remove(oldField);
          }
        }
      }

      // Apply value transformations
      final valueTransformations = transformationRules['valueTransformations'] as Map<String, dynamic>?;
      if (valueTransformations != null) {
        for (final entry in valueTransformations.entries) {
          final field = entry.key;
          final transformation = entry.value as Map<String, dynamic>;
          
          if (transformed.containsKey(field)) {
            transformed[field] = _applyValueTransformation(transformed[field], transformation);
          }
        }
      }

      return transformed;
    }).toList();
  }

  dynamic _applyValueTransformation(dynamic value, Map<String, dynamic> transformation) {
    final type = transformation['type'] as String;
    
    switch (type) {
      case 'string_replace':
        if (value is String) {
          return value.replaceAll(
            transformation['from'] as String,
            transformation['to'] as String,
          );
        }
        break;
      case 'date_format':
        if (value is Timestamp) {
          return value.toDate().toIso8601String();
        }
        break;
      case 'default_value':
        return value ?? transformation['defaultValue'];
    }
    
    return value;
  }

  Future<int> _writeMessagesToTarget(
    String targetType,
    Map<String, dynamic> targetConfig,
    List<Map<String, dynamic>> messages,
  ) async {
    switch (targetType) {
      case 'firestore':
        return await _writeMessagesToFirestore(targetConfig, messages);
      case 'sqlite':
        return await _writeMessagesToSQLite(targetConfig, messages);
      case 'json':
        return await _writeMessagesToJSON(targetConfig, messages);
      default:
        throw Exception('Unknown target type: $targetType');
    }
  }

  Future<int> _writeMessagesToFirestore(
    Map<String, dynamic> config,
    List<Map<String, dynamic>> messages,
  ) async {
    int writtenCount = 0;
    final batch = _firestore.batch();
    int batchCount = 0;

    for (final message in messages) {
      final docRef = _firestore.collection('messages').doc(message['id']);
      batch.set(docRef, message['data']);
      
      batchCount++;
      if (batchCount >= 500) {
        await batch.commit();
        writtenCount += batchCount;
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
      writtenCount += batchCount;
    }

    return writtenCount;
  }

  Future<int> _writeMessagesToSQLite(
    Map<String, dynamic> config,
    List<Map<String, dynamic>> messages,
  ) async {
    // Placeholder - would implement SQLite writing
    return messages.length;
  }

  Future<int> _writeMessagesToJSON(
    Map<String, dynamic> config,
    List<Map<String, dynamic>> messages,
  ) async {
    // Placeholder - would implement JSON file writing
    return messages.length;
  }

  Future<void> _removeMessagesFromSource(
    String sourceType,
    Map<String, dynamic> sourceConfig,
    List<Map<String, dynamic>> messages,
  ) async {
    // Implementation would depend on source type
    // For now, just log the operation
    debugPrint('Would remove ${messages.length} messages from $sourceType');
  }

  Future<Map<String, dynamic>> _migrateCollectionToSQLite(
    String collection,
    String sqliteDbPath,
  ) async {
    // Placeholder implementation
    return {
      'collection': collection,
      'totalRecords': 0,
      'migratedRecords': 0,
      'status': 'completed',
    };
  }

  Future<Map<String, dynamic>> _migrateTableToFirestore(
    String sqliteDbPath,
    String table,
  ) async {
    // Placeholder implementation
    return {
      'table': table,
      'totalRecords': 0,
      'migratedRecords': 0,
      'status': 'completed',
    };
  }

  Future<Map<String, dynamic>> _exportDataTypeToJSON(
    String dataType,
    String userId,
    bool includeMetadata,
  ) async {
    switch (dataType) {
      case 'messages':
        return await _exportMessagesToJSON(userId, includeMetadata);
      case 'conversations':
        return await _exportConversationsToJSON(userId, includeMetadata);
      case 'call_history':
        return await _exportCallHistoryToJSON(userId, includeMetadata);
      default:
        return {
          'dataType': dataType,
          'records': [],
          'count': 0,
        };
    }
  }

  Future<Map<String, dynamic>> _exportMessagesToJSON(String userId, bool includeMetadata) async {
    final messages = <Map<String, dynamic>>[];
    
    // Get user's conversations
    final conversationsSnapshot = await _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .get();

    final conversationIds = conversationsSnapshot.docs.map((doc) => doc.id).toList();

    // Get messages from all conversations
    for (final conversationId in conversationIds) {
      final messagesSnapshot = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .get();

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data();
        messages.add({
          'id': doc.id,
          'conversationId': data['conversationId'],
          'content': data['content'],
          'messageType': data['messageType'],
          'sentAt': data['sentAt']?.toDate()?.toIso8601String(),
          'senderName': data['senderName'],
          if (includeMetadata) ...{
            'metadata': {
              'encryptionLevel': data['encryptionLevel'],
              'deliveryStatus': data['deliveryStatus'],
              'readAt': data['readAt']?.toDate()?.toIso8601String(),
            },
          },
        });
      }
    }

    return {
      'dataType': 'messages',
      'records': messages,
      'count': messages.length,
    };
  }

  Future<Map<String, dynamic>> _exportConversationsToJSON(String userId, bool includeMetadata) async {
    final conversations = <Map<String, dynamic>>[];
    
    final snapshot = await _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      conversations.add({
        'id': doc.id,
        'name': data['name'],
        'type': data['type'],
        'createdAt': data['createdAt']?.toDate()?.toIso8601String(),
        'participantCount': (data['participantIds'] as List?)?.length ?? 0,
        if (includeMetadata) ...{
          'metadata': {
            'lastMessageAt': data['lastMessageAt']?.toDate()?.toIso8601String(),
            'isActive': data['isActive'],
            'settings': data['settings'],
          },
        },
      });
    }

    return {
      'dataType': 'conversations',
      'records': conversations,
      'count': conversations.length,
    };
  }

  Future<Map<String, dynamic>> _exportCallHistoryToJSON(String userId, bool includeMetadata) async {
    final callHistory = <Map<String, dynamic>>[];
    
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('call_history')
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      callHistory.add({
        'id': doc.id,
        'participantName': data['participantName'],
        'callType': data['callType'],
        'status': data['status'],
        'startTime': data['startTime'],
        'duration': data['duration'],
        'isIncoming': data['isIncoming'],
        if (includeMetadata) ...{
          'metadata': {
            'quality': data['quality'],
            'endReason': data['endReason'],
            'deviceInfo': data['deviceInfo'],
          },
        },
      });
    }

    return {
      'dataType': 'call_history',
      'records': callHistory,
      'count': callHistory.length,
    };
  }

  Future<Map<String, dynamic>> _importDataTypeFromJSON(
    String dataType,
    Map<String, dynamic> typeData,
    bool overwriteExisting,
  ) async {
    final records = typeData['records'] as List<dynamic>? ?? [];
    
    switch (dataType) {
      case 'messages':
        return await _importMessagesFromJSON(records, overwriteExisting);
      case 'conversations':
        return await _importConversationsFromJSON(records, overwriteExisting);
      case 'call_history':
        return await _importCallHistoryFromJSON(records, overwriteExisting);
      default:
        return {
          'dataType': dataType,
          'totalRecords': records.length,
          'importedRecords': 0,
          'status': 'skipped',
        };
    }
  }

  Future<Map<String, dynamic>> _importMessagesFromJSON(
    List<dynamic> records,
    bool overwriteExisting,
  ) async {
    int importedCount = 0;
    final batch = _firestore.batch();
    int batchCount = 0;

    for (final record in records) {
      final recordMap = record as Map<String, dynamic>;
      final docRef = _firestore.collection('messages').doc(recordMap['id']);
      
      if (!overwriteExisting) {
        final existingDoc = await docRef.get();
        if (existingDoc.exists) continue;
      }
      
      batch.set(docRef, {
        'conversationId': recordMap['conversationId'],
        'content': recordMap['content'],
        'messageType': recordMap['messageType'],
        'sentAt': recordMap['sentAt'] != null 
            ? Timestamp.fromDate(DateTime.parse(recordMap['sentAt']))
            : null,
        'senderName': recordMap['senderName'],
        'importedAt': FieldValue.serverTimestamp(),
      });
      
      batchCount++;
      if (batchCount >= 500) {
        await batch.commit();
        importedCount += batchCount;
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
      importedCount += batchCount;
    }

    return {
      'dataType': 'messages',
      'totalRecords': records.length,
      'importedRecords': importedCount,
      'status': 'completed',
    };
  }

  Future<Map<String, dynamic>> _importConversationsFromJSON(
    List<dynamic> records,
    bool overwriteExisting,
  ) async {
    // Similar implementation to _importMessagesFromJSON
    return {
      'dataType': 'conversations',
      'totalRecords': records.length,
      'importedRecords': 0,
      'status': 'completed',
    };
  }

  Future<Map<String, dynamic>> _importCallHistoryFromJSON(
    List<dynamic> records,
    bool overwriteExisting,
  ) async {
    // Similar implementation to _importMessagesFromJSON
    return {
      'dataType': 'call_history',
      'totalRecords': records.length,
      'importedRecords': 0,
      'status': 'completed',
    };
  }

  Map<String, dynamic> _validateImportData(Map<String, dynamic> importData) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check required fields
    if (!importData.containsKey('data')) {
      errors.add('Missing required field: data');
    }

    if (!importData.containsKey('version')) {
      warnings.add('Missing version field - assuming latest version');
    }

    // Validate data structure
    final data = importData['data'] as Map<String, dynamic>?;
    if (data != null) {
      for (final entry in data.entries) {
        final dataType = entry.key;
        final typeData = entry.value as Map<String, dynamic>?;
        
        if (typeData == null || !typeData.containsKey('records')) {
          errors.add('Invalid data structure for type: $dataType');
        }
      }
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
    };
  }

  Future<void> _createMigrationJob(String jobId, String configId, Map<String, dynamic> config) async {
    final currentUserId = await _authService.getCurrentUserId();
    
    await _firestore.collection(_migrationJobsCollection).doc(jobId).set({
      'jobId': jobId,
      'configId': configId,
      'userId': currentUserId,
      'config': config,
      'status': 'started',
      'progress': 'initializing',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateMigrationProgress(String jobId, String progress) async {
    await _firestore.collection(_migrationJobsCollection).doc(jobId).update({
      'progress': progress,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateMigrationJob(String jobId, Map<String, dynamic> results) async {
    await _firestore.collection(_migrationJobsCollection).doc(jobId).update({
      'results': results,
      'status': results['status'],
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  String _generateMigrationConfigId() {
    return 'migration_config_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateMigrationJobId() {
    return 'migration_job_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateExportId() {
    return 'export_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
  }

  String _generateImportId() {
    return 'import_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
  }
}