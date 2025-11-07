// Database Migration Service for TALOWA Social Feed System
// Handles schema migrations with rollback capabilities

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Database Migration Service with rollback capabilities
class DatabaseMigrationService {
  static DatabaseMigrationService? _instance;
  static DatabaseMigrationService get instance => _instance ??= DatabaseMigrationService._internal();
  
  DatabaseMigrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Migration tracking
  final Map<String, int> _currentVersions = {};
  final List<Migration> _availableMigrations = [];
  final List<Migration> _appliedMigrations = [];
  
  bool _isInitialized = false;

  /// Initialize migration service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Initializing Database Migration Service...');
      
      // Load current schema versions
      await _loadCurrentVersions();
      
      // Register available migrations
      _registerMigrations();
      
      _isInitialized = true;
      debugPrint('✅ Database Migration Service initialized');
      
    } catch (error) {
      debugPrint('❌ Failed to initialize Database Migration Service: $error');
      rethrow;
    }
  }

  /// Load current schema versions from database
  Future<void> _loadCurrentVersions() async {
    try {
      final doc = await _firestore.collection('system').doc('schema_versions').get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data.forEach((collection, version) {
          _currentVersions[collection] = version as int;
        });
      }
      
      debugPrint('📊 Loaded schema versions: $_currentVersions');
      
    } catch (error) {
      debugPrint('❌ Error loading schema versions: $error');
    }
  }

  /// Register all available migrations
  void _registerMigrations() {
    // Social Feed System Migrations
    _availableMigrations.addAll([
      // Posts collection migrations
      Migration(
        id: 'posts_v1_to_v2',
        collection: 'posts',
        fromVersion: 1,
        toVersion: 2,
        description: 'Add advanced multimedia support to posts',
        migrate: _migratePostsV1ToV2,
        rollback: _rollbackPostsV2ToV1,
      ),
      
      Migration(
        id: 'posts_v2_to_v3',
        collection: 'posts',
        fromVersion: 2,
        toVersion: 3,
        description: 'Add AI-powered content analysis fields',
        migrate: _migratePostsV2ToV3,
        rollback: _rollbackPostsV3ToV2,
      ),
      
      // Users collection migrations
      Migration(
        id: 'users_v1_to_v2',
        collection: 'users',
        fromVersion: 1,
        toVersion: 2,
        description: 'Add advanced user preferences and analytics',
        migrate: _migrateUsersV1ToV2,
        rollback: _rollbackUsersV2ToV1,
      ),
    ]);
    
    debugPrint('📋 Registered ${_availableMigrations.length} migrations');
  }

  /// Execute a single migration
  Future<void> executeMigration(Migration migration) async {
    if (!_isInitialized) await initialize();

    debugPrint('🔄 Executing migration: ${migration.id}');
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Execute migration
      await migration.migrate(_firestore);
      
      // Update schema version
      await _updateSchemaVersion(migration.collection, migration.toVersion);
      _currentVersions[migration.collection] = migration.toVersion;
      
      _appliedMigrations.add(migration);
      
      debugPrint('✅ Migration completed: ${migration.id} (${stopwatch.elapsedMilliseconds}ms)');
      
    } catch (error) {
      debugPrint('❌ Migration failed: ${migration.id} - $error');
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Update schema version in database
  Future<void> _updateSchemaVersion(String collection, int version) async {
    await _firestore.collection('system').doc('schema_versions').set({
      collection: version,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Migrate posts from v1 to v2 (add multimedia support)
  Future<void> _migratePostsV1ToV2(FirebaseFirestore firestore) async {
    final batch = firestore.batch();
    int batchCount = 0;
    
    final snapshot = await firestore.collection('posts').get();
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      
      // Add new multimedia fields
      data['mediaAssets'] = [];
      data['hasVideo'] = false;
      data['hasAudio'] = false;
      data['mediaCount'] = 0;
      
      batch.update(doc.reference, data);
      batchCount++;
      
      // Commit batch every 500 operations
      if (batchCount >= 500) {
        await batch.commit();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0) {
      await batch.commit();
    }
  }

  /// Rollback posts from v2 to v1
  Future<void> _rollbackPostsV2ToV1(FirebaseFirestore firestore) async {
    final batch = firestore.batch();
    int batchCount = 0;
    
    final snapshot = await firestore.collection('posts').get();
    
    for (final doc in snapshot.docs) {
      // Remove multimedia fields
      batch.update(doc.reference, {
        'mediaAssets': FieldValue.delete(),
        'hasVideo': FieldValue.delete(),
        'hasAudio': FieldValue.delete(),
        'mediaCount': FieldValue.delete(),
      });
      batchCount++;
      
      if (batchCount >= 500) {
        await batch.commit();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0) {
      await batch.commit();
    }
  }

  /// Migrate posts from v2 to v3 (add AI analysis)
  Future<void> _migratePostsV2ToV3(FirebaseFirestore firestore) async {
    final batch = firestore.batch();
    int batchCount = 0;
    
    final snapshot = await firestore.collection('posts').get();
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      
      // Add AI analysis fields
      data['aiGeneratedTags'] = [];
      data['aiEngagementPrediction'] = 0.0;
      data['sentiment'] = 'neutral';
      data['toxicityScore'] = 0.0;
      
      batch.update(doc.reference, data);
      batchCount++;
      
      if (batchCount >= 500) {
        await batch.commit();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0) {
      await batch.commit();
    }
  }

  /// Rollback posts from v3 to v2
  Future<void> _rollbackPostsV3ToV2(FirebaseFirestore firestore) async {
    final batch = firestore.batch();
    int batchCount = 0;
    
    final snapshot = await firestore.collection('posts').get();
    
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'aiGeneratedTags': FieldValue.delete(),
        'aiEngagementPrediction': FieldValue.delete(),
        'sentiment': FieldValue.delete(),
        'toxicityScore': FieldValue.delete(),
      });
      batchCount++;
      
      if (batchCount >= 500) {
        await batch.commit();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0) {
      await batch.commit();
    }
  }

  /// Migrate users from v1 to v2 (add preferences)
  Future<void> _migrateUsersV1ToV2(FirebaseFirestore firestore) async {
    final batch = firestore.batch();
    int batchCount = 0;
    
    final snapshot = await firestore.collection('users').get();
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      
      // Add user preference fields
      data['preferences'] = {
        'feedAlgorithm': 'chronological',
        'notificationSettings': {
          'posts': true,
          'comments': true,
          'likes': true,
        },
      };
      data['analyticsEnabled'] = true;
      
      batch.update(doc.reference, data);
      batchCount++;
      
      if (batchCount >= 500) {
        await batch.commit();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0) {
      await batch.commit();
    }
  }

  /// Rollback users from v2 to v1
  Future<void> _rollbackUsersV2ToV1(FirebaseFirestore firestore) async {
    final batch = firestore.batch();
    int batchCount = 0;
    
    final snapshot = await firestore.collection('users').get();
    
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'preferences': FieldValue.delete(),
        'analyticsEnabled': FieldValue.delete(),
      });
      batchCount++;
      
      if (batchCount >= 500) {
        await batch.commit();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0) {
      await batch.commit();
    }
  }
}

/// Migration model
class Migration {
  final String id;
  final String collection;
  final int fromVersion;
  final int toVersion;
  final String description;
  final Future<void> Function(FirebaseFirestore) migrate;
  final Future<void> Function(FirebaseFirestore)? rollback;

  Migration({
    required this.id,
    required this.collection,
    required this.fromVersion,
    required this.toVersion,
    required this.description,
    required this.migrate,
    this.rollback,
  });
}