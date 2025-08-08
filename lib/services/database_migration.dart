import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Database migration service for scalability improvements
class DatabaseMigration {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Migrate existing users to new user_registry collection
  static Future<void> migrateToUserRegistry() async {
    try {
      debugPrint('Starting user registry migration...');
      
      // Get all existing users
      final usersSnapshot = await _firestore.collection('users').get();
      
      int migrated = 0;
      int errors = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final phoneNumber = userData['phone'] as String?;
          
          if (phoneNumber != null) {
            // Create registry entry
            await _firestore.collection('user_registry').doc(phoneNumber).set({
              'uid': userDoc.id,
              'email': '$phoneNumber@talowa.app',
              'phoneNumber': phoneNumber,
              'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
              'isActive': true,
              'lastLoginAt': userData['lastLoginAt'] ?? FieldValue.serverTimestamp(),
              'role': userData['role'] ?? 'Member',
              'state': userData['address']?['state'],
              'district': userData['address']?['district'],
            });
            
            migrated++;
            
            if (migrated % 100 == 0) {
              debugPrint('Migrated $migrated users...');
            }
          }
        } catch (e) {
          errors++;
          debugPrint('Error migrating user ${userDoc.id}: $e');
        }
      }
      
      debugPrint('Migration completed: $migrated users migrated, $errors errors');
      
      // Create indexes for performance
      await _createIndexes();
      
    } catch (e) {
      debugPrint('Migration failed: $e');
    }
  }
  
  /// Create database indexes for performance
  static Future<void> _createIndexes() async {
    try {
      debugPrint('Creating database indexes...');
      
      // Note: Firestore indexes are typically created through Firebase Console
      // or firestore.indexes.json file. This is a placeholder for documentation.
      
      final indexesToCreate = [
        {
          'collection': 'user_registry',
          'fields': ['phoneNumber', 'isActive'],
        },
        {
          'collection': 'user_registry', 
          'fields': ['state', 'district', 'createdAt'],
        },
        {
          'collection': 'users',
          'fields': ['role', 'createdAt'],
        },
        {
          'collection': 'performance_metrics',
          'fields': ['operation', 'timestamp'],
        },
      ];
      
      debugPrint('Indexes to create: ${indexesToCreate.length}');
      debugPrint('Please create these indexes in Firebase Console:');
      
      for (final index in indexesToCreate) {
        debugPrint('Collection: ${index['collection']}, Fields: ${index['fields']}');
      }
      
    } catch (e) {
      debugPrint('Error creating indexes: $e');
    }
  }
  
  /// Clean up old data and optimize storage
  static Future<void> optimizeDatabase() async {
    try {
      debugPrint('Starting database optimization...');
      
      // Clean up old performance metrics (keep only last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final oldMetrics = await _firestore
          .collection('performance_metrics')
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      final batch = _firestore.batch();
      int deleteCount = 0;
      
      for (final doc in oldMetrics.docs) {
        batch.delete(doc.reference);
        deleteCount++;
        
        // Firestore batch limit is 500 operations
        if (deleteCount >= 500) {
          await batch.commit();
          debugPrint('Deleted $deleteCount old metrics...');
          deleteCount = 0;
        }
      }
      
      if (deleteCount > 0) {
        await batch.commit();
        debugPrint('Deleted $deleteCount old metrics');
      }
      
      debugPrint('Database optimization completed');
      
    } catch (e) {
      debugPrint('Database optimization failed: $e');
    }
  }
  
  /// Validate data integrity
  static Future<Map<String, dynamic>> validateDataIntegrity() async {
    try {
      debugPrint('Validating data integrity...');
      
      // Count users in both collections
      final usersCount = await _firestore.collection('users').count().get();
      final registryCount = await _firestore.collection('user_registry').count().get();
      
      // Check for orphaned records
      final usersSnapshot = await _firestore.collection('users').limit(100).get();
      int orphanedUsers = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final phoneNumber = userData['phone'] as String?;
        
        if (phoneNumber != null) {
          final registryDoc = await _firestore
              .collection('user_registry')
              .doc(phoneNumber)
              .get();
          
          if (!registryDoc.exists) {
            orphanedUsers++;
          }
        }
      }
      
      final report = {
        'usersCount': usersCount.count,
        'registryCount': registryCount.count,
        'orphanedUsers': orphanedUsers,
        'integrityScore': orphanedUsers == 0 ? 100 : 90,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      debugPrint('Data integrity report: $report');
      return report;
      
    } catch (e) {
      debugPrint('Data integrity validation failed: $e');
      return {'error': e.toString()};
    }
  }
}