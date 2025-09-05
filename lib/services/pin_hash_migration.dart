import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_policy.dart';

/// Migration service to backfill PIN hashes for existing users
class PinHashMigration {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Backfill PIN hash for a specific user
  /// This should be called manually for test users who registered before the fix
  static Future<void> backfillPinHashForUser({
    required String phoneNumber,
    required String pin,
  }) async {
    try {
      debugPrint('ðŸ”„ Backfilling PIN hash for: $phoneNumber');
      
      final normalizedPhone = normalizeE164(phoneNumber);
      final hashedPin = passwordFromPin(pin);
      
      // Get user registry to find UID
      final registryDoc = await _firestore
          .collection('user_registry')
          .doc(normalizedPhone)
          .get();
      
      if (!registryDoc.exists) {
        debugPrint('âŒ User registry not found for: $normalizedPhone');
        return;
      }
      
      final uid = registryDoc.data()!['uid'] as String;
      
      // Update user registry with PIN hash
      await _firestore.collection('user_registry').doc(normalizedPhone).update({
        'pinHash': hashedPin,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update user profile with PIN hash
      await _firestore.collection('users').doc(uid).update({
        'pinHash': hashedPin,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('âœ… PIN hash backfilled successfully for: $normalizedPhone');
    } catch (e) {
      debugPrint('âŒ Failed to backfill PIN hash for $phoneNumber: $e');
      throw Exception('Failed to backfill PIN hash: $e');
    }
  }

  /// Backfill PIN hashes for multiple users
  static Future<void> backfillPinHashForUsers(
    Map<String, String> phoneNumberToPinMap,
  ) async {
    debugPrint('ðŸ”„ Starting bulk PIN hash backfill for ${phoneNumberToPinMap.length} users');
    
    int successCount = 0;
    int failureCount = 0;
    
    for (final entry in phoneNumberToPinMap.entries) {
      try {
        await backfillPinHashForUser(
          phoneNumber: entry.key,
          pin: entry.value,
        );
        successCount++;
      } catch (e) {
        debugPrint('âŒ Failed to backfill for ${entry.key}: $e');
        failureCount++;
      }
    }
    
    debugPrint('âœ… Bulk backfill completed: $successCount success, $failureCount failures');
  }

  /// Check if a user needs PIN hash migration
  static Future<bool> needsPinHashMigration(String phoneNumber) async {
    try {
      final normalizedPhone = normalizeE164(phoneNumber);
      final registryDoc = await _firestore
          .collection('user_registry')
          .doc(normalizedPhone)
          .get();
      
      if (!registryDoc.exists) {
        return false; // User doesn't exist
      }
      
      final data = registryDoc.data()!;
      final pinHash = data['pinHash'] as String?;
      
      return pinHash == null || pinHash.isEmpty;
    } catch (e) {
      debugPrint('Error checking PIN hash migration need: $e');
      return false;
    }
  }

  /// Find all users who need PIN hash migration
  static Future<List<String>> findUsersNeedingMigration() async {
    try {
      final usersNeedingMigration = <String>[];
      
      final registryQuery = await _firestore
          .collection('user_registry')
          .get();
      
      for (final doc in registryQuery.docs) {
        final data = doc.data();
        final phoneNumber = data['phoneNumber'] as String?;
        final pinHash = data['pinHash'] as String?;
        
        if (phoneNumber != null && (pinHash == null || pinHash.isEmpty)) {
          usersNeedingMigration.add(phoneNumber);
        }
      }
      
      debugPrint('Found ${usersNeedingMigration.length} users needing PIN hash migration');
      return usersNeedingMigration;
    } catch (e) {
      debugPrint('Error finding users needing migration: $e');
      return [];
    }
  }
}
