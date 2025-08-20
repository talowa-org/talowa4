import 'package:cloud_firestore/cloud_firestore.dart';
import 'simplified_referral_service.dart';

/// Service to migrate existing users from two-step to simplified referral system
class ReferralMigrationService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Migrate all users to simplified referral system
  static Future<Map<String, dynamic>> migrateAllUsers() async {
    try {
      print('Starting migration to simplified referral system...');
      
      int totalUsers = 0;
      int migratedUsers = 0;
      int errorCount = 0;
      final errors = <String>[];
      
      // Get all users in batches
      QuerySnapshot? lastDoc;
      const batchSize = 100;
      
      do {
        Query query = _firestore.collection('users').limit(batchSize);
        
        if (lastDoc != null && lastDoc.docs.isNotEmpty) {
          query = query.startAfterDocument(lastDoc.docs.last);
        }
        
        final batch = await query.get();
        lastDoc = batch;
        
        if (batch.docs.isEmpty) break;
        
        totalUsers += batch.docs.length;
        
        // Process each user in the batch
        for (final doc in batch.docs) {
          try {
            await _migrateUser(doc.id, doc.data() as Map<String, dynamic>);
            migratedUsers++;
            
            if (migratedUsers % 50 == 0) {
              print('Migrated $migratedUsers users...');
            }
          } catch (e) {
            errorCount++;
            errors.add('User ${doc.id}: $e');
            print('Error migrating user ${doc.id}: $e');
          }
        }
        
      } while (lastDoc != null && lastDoc.docs.length == batchSize);
      
      print('Migration completed!');
      print('Total users: $totalUsers');
      print('Successfully migrated: $migratedUsers');
      print('Errors: $errorCount');
      
      return {
        'success': true,
        'totalUsers': totalUsers,
        'migratedUsers': migratedUsers,
        'errorCount': errorCount,
        'errors': errors.take(10).toList(), // Return first 10 errors
        'completedAt': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'completedAt': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// Migrate a single user to simplified system
  static Future<void> _migrateUser(String userId, Map<String, dynamic> userData) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(userId);
    
    // Prepare migration data
    final migrationData = <String, dynamic>{
      'membershipPaid': true, // Always true in simplified system
      'referralStatus': 'active', // Always active in simplified system
      'isActive': userData['isActive'] ?? true,
      'migratedToSimplifiedSystem': true,
      'migrationDate': FieldValue.serverTimestamp(),
    };
    
    // Handle referral statistics migration
    final pendingReferrals = List<String>.from(userData['pendingReferrals'] ?? []);
    final directReferrals = List<String>.from(userData['directReferrals'] ?? []);
    
    // In simplified system, all referrals are active
    final allReferrals = [...directReferrals, ...pendingReferrals].toSet().toList();
    
    migrationData['directReferrals'] = allReferrals;
    migrationData['activeDirectReferrals'] = allReferrals.length;
    migrationData['pendingReferrals'] = []; // Clear pending referrals
    
    // Calculate team size (all users in downline)
    final teamSize = await _calculateTeamSize(userId);
    migrationData['activeTeamSize'] = teamSize;
    migrationData['totalTeamSize'] = teamSize;
    
    // Ensure user has a referral code
    if (userData['referralCode'] == null || userData['referralCode'].toString().isEmpty) {
      // Generate a referral code if missing
      final referralCode = await _generateMigrationReferralCode(userId);
      migrationData['referralCode'] = referralCode;
      
      // Add to referral lookup
      await _firestore.collection('referralCodes').doc(referralCode).set({
        'code': referralCode,
        'uid': userId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'clickCount': 0,
        'conversionCount': allReferrals.length,
      });
    }
    
    // Update user document
    batch.update(userRef, migrationData);
    
    await batch.commit();
  }
  
  /// Calculate team size for a user
  static Future<int> _calculateTeamSize(String userId) async {
    try {
      final teamQuery = await _firestore
          .collection('users')
          .where('referralChain', arrayContains: userId)
          .get();
      
      return teamQuery.docs.length;
    } catch (e) {
      return 0;
    }
  }
  
  /// Generate a referral code for migration
  static Future<String> _generateMigrationReferralCode(String userId) async {
    // Use a simple approach for migration - TAL + first 6 chars of userId
    final baseCode = 'TAL${userId.substring(0, 6).toUpperCase()}';
    
    // Check if this code already exists
    final existingCode = await _firestore.collection('referralCodes').doc(baseCode).get();
    
    if (!existingCode.exists) {
      return baseCode;
    }
    
    // If exists, add a number suffix
    for (int i = 1; i <= 99; i++) {
      final codeWithSuffix = '$baseCode${i.toString().padLeft(2, '0')}';
      final existingWithSuffix = await _firestore.collection('referralCodes').doc(codeWithSuffix).get();
      
      if (!existingWithSuffix.exists) {
        return codeWithSuffix;
      }
    }
    
    // Fallback to timestamp-based code
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return 'TAL${timestamp.substring(timestamp.length - 6)}';
  }
  
  /// Verify migration results
  static Future<Map<String, dynamic>> verifyMigration() async {
    try {
      // Count users by migration status
      final totalUsersQuery = await _firestore.collection('users').get();
      final totalUsers = totalUsersQuery.docs.length;
      
      final migratedUsersQuery = await _firestore
          .collection('users')
          .where('migratedToSimplifiedSystem', isEqualTo: true)
          .get();
      final migratedUsers = migratedUsersQuery.docs.length;
      
      // Count users with pending referrals (should be 0 after migration)
      final pendingReferralsQuery = await _firestore
          .collection('users')
          .where('referralStatus', isEqualTo: 'pending_payment')
          .get();
      final pendingReferrals = pendingReferralsQuery.docs.length;
      
      // Count users without referral codes
      final noReferralCodeQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: null)
          .get();
      final noReferralCode = noReferralCodeQuery.docs.length;
      
      return {
        'totalUsers': totalUsers,
        'migratedUsers': migratedUsers,
        'migrationPercentage': totalUsers > 0 ? (migratedUsers / totalUsers * 100).round() : 0,
        'pendingReferrals': pendingReferrals,
        'usersWithoutReferralCode': noReferralCode,
        'migrationComplete': migratedUsers == totalUsers && pendingReferrals == 0,
        'verifiedAt': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      return {
        'error': e.toString(),
        'verifiedAt': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// Fix any migration issues
  static Future<Map<String, dynamic>> fixMigrationIssues() async {
    try {
      int fixedUsers = 0;
      final errors = <String>[];
      
      // Fix users without referral codes
      final noCodeQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: null)
          .get();
      
      for (final doc in noCodeQuery.docs) {
        try {
          final referralCode = await _generateMigrationReferralCode(doc.id);
          
          await _firestore.collection('users').doc(doc.id).update({
            'referralCode': referralCode,
          });
          
          await _firestore.collection('referralCodes').doc(referralCode).set({
            'code': referralCode,
            'uid': doc.id,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'clickCount': 0,
            'conversionCount': 0,
          });
          
          fixedUsers++;
        } catch (e) {
          errors.add('User ${doc.id}: $e');
        }
      }
      
      // Fix users with pending referral status
      final pendingQuery = await _firestore
          .collection('users')
          .where('referralStatus', isEqualTo: 'pending_payment')
          .get();
      
      for (final doc in pendingQuery.docs) {
        try {
          await _firestore.collection('users').doc(doc.id).update({
            'referralStatus': 'active',
            'membershipPaid': true,
          });
          
          fixedUsers++;
        } catch (e) {
          errors.add('User ${doc.id}: $e');
        }
      }
      
      return {
        'success': true,
        'fixedUsers': fixedUsers,
        'errors': errors,
        'fixedAt': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'fixedAt': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// Update all referral statistics after migration
  static Future<Map<String, dynamic>> updateAllStatistics() async {
    try {
      print('Updating all referral statistics...');
      
      int updatedUsers = 0;
      int errorCount = 0;
      
      final usersQuery = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .get();
      
      for (final doc in usersQuery.docs) {
        try {
          await SimplifiedReferralService.updateUserReferralStatistics(doc.id);
          updatedUsers++;
          
          if (updatedUsers % 50 == 0) {
            print('Updated statistics for $updatedUsers users...');
          }
        } catch (e) {
          errorCount++;
          print('Error updating statistics for user ${doc.id}: $e');
        }
      }
      
      return {
        'success': true,
        'updatedUsers': updatedUsers,
        'errorCount': errorCount,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
    }
  }
}