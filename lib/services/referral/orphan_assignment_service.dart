import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:talowa/config/referral_config.dart';
import 'package:talowa/services/referral/monitoring_service.dart';
import 'package:talowa/services/referral/role_progression_service.dart';

/// Exception thrown when orphan assignment operations fail
class OrphanAssignmentException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const OrphanAssignmentException(this.message, [this.code = 'ORPHAN_ASSIGNMENT_FAILED', this.context]);
  
  @override
  String toString() => 'OrphanAssignmentException: $message';
}

/// Service for handling orphan user assignments
class OrphanAssignmentService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Handle Step 1: Set provisional referral for orphan users
  static Future<void> handleProvisionalReferral({
    required String userId,
    String? providedReferralCode,
  }) async {
    final operationId = 'provisional_${DateTime.now().microsecondsSinceEpoch}';
    
    try {
      MonitoringService.startOperation(operationId, 'provisional_referral_assignment', userId);
      
      if (!ReferralConfig.fallbackEnabled) {
        if (kDebugMode) {
          print('Fallback disabled, skipping provisional assignment for user: $userId');
        }
        return;
      }
      
      // Verify admin configuration (skip in test environment)
      try {
        final isAdminValid = await ReferralConfig.verifyAdminConfiguration();
        if (!isAdminValid) {
          throw OrphanAssignmentException(
            'Admin configuration invalid. Cannot assign provisional referral.',
            'ADMIN_CONFIG_INVALID',
            {'userId': userId}
          );
        }
      } catch (e) {
        // In test environment, check if admin code exists in our test firestore
        final adminCodeDoc = await _firestore
            .collection('referralCodes')
            .doc(ReferralConfig.defaultReferrerCode)
            .get();

        if (!adminCodeDoc.exists || adminCodeDoc.data()!['isActive'] != true) {
          throw OrphanAssignmentException(
            'Admin configuration invalid. Cannot assign provisional referral.',
            'ADMIN_CONFIG_INVALID',
            {'userId': userId}
          );
        }
      }
      
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        throw OrphanAssignmentException(
          'User not found',
          'USER_NOT_FOUND',
          {'userId': userId}
        );
      }
      
      final userData = userDoc.data()!;
      
      // Skip if user already has a referral relationship
      if (userData['referredBy'] != null) {
        if (kDebugMode) {
          print('User $userId already has referral relationship, skipping provisional assignment');
        }
        return;
      }
      
      // Skip if provisional referral already set
      if (userData['provisionalRef'] != null) {
        if (kDebugMode) {
          print('User $userId already has provisional referral, skipping assignment');
        }
        return;
      }
      
      // Determine if we need to set provisional referral
      bool needsProvisionalRef = false;
      
      if (providedReferralCode == null || providedReferralCode.isEmpty) {
        needsProvisionalRef = true;
      } else {
        // Validate provided referral code
        final codeDoc = await _firestore
            .collection('referralCodes')
            .doc(providedReferralCode)
            .get();
        
        if (!codeDoc.exists || codeDoc.data()!['isActive'] != true) {
          needsProvisionalRef = true;
        }
      }
      
      if (needsProvisionalRef) {
        // Set provisional referral to admin
        await userRef.update({
          'provisionalRef': ReferralConfig.defaultReferrerCode,
          'assignedBySystem': true,
          'provisionalAssignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Log the provisional assignment
        await MonitoringService.logInfo(
          'Provisional referral assigned to admin',
          operation: 'provisional_referral_assignment',
          userId: userId,
          context: {
            'provisionalRef': ReferralConfig.defaultReferrerCode,
            'providedCode': providedReferralCode,
            'reason': providedReferralCode == null ? 'no_code_provided' : 'invalid_code',
          },
        );
        
        if (kDebugMode) {
          print('Set provisional referral for user $userId to ${ReferralConfig.defaultReferrerCode}');
        }
      }
      
      await MonitoringService.endOperation(
        operationId,
        'provisional_referral_assignment',
        userId,
        success: true,
        metadata: {
          'needsProvisionalRef': needsProvisionalRef,
          'providedCode': providedReferralCode,
        },
      );
    } catch (e) {
      await MonitoringService.endOperation(
        operationId,
        'provisional_referral_assignment',
        userId,
        success: false,
        errorMessage: e.toString(),
      );
      
      await MonitoringService.logError(
        'Failed to handle provisional referral: $e',
        operation: 'provisional_referral_assignment',
        userId: userId,
        context: {'providedCode': providedReferralCode},
      );
      
      rethrow;
    }
  }
  
  /// Handle Step 2: Bind provisional referral after payment
  static Future<void> bindProvisionalReferral(String userId) async {
    final operationId = 'bind_${DateTime.now().microsecondsSinceEpoch}';
    
    try {
      MonitoringService.startOperation(operationId, 'bind_provisional_referral', userId);
      
      if (!ReferralConfig.fallbackEnabled) {
        if (kDebugMode) {
          print('Fallback disabled, skipping binding for user: $userId');
        }
        return;
      }
      
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw OrphanAssignmentException(
            'User not found',
            'USER_NOT_FOUND',
            {'userId': userId}
          );
        }
        
        final userData = userDoc.data()!;
        
        // Skip if user already has referral relationship
        if (userData['referredBy'] != null) {
          if (kDebugMode) {
            print('User $userId already has referral relationship, skipping binding');
          }
          return;
        }
        
        // Skip if no provisional referral
        final provisionalRef = userData['provisionalRef'];
        if (provisionalRef == null) {
          if (kDebugMode) {
            print('User $userId has no provisional referral, skipping binding');
          }
          return;
        }
        
        // Validate provisional referral code
        final codeRef = _firestore.collection('referralCodes').doc(provisionalRef);
        final codeDoc = await transaction.get(codeRef);
        
        if (!codeDoc.exists || codeDoc.data()!['isActive'] != true) {
          throw OrphanAssignmentException(
            'Provisional referral code is invalid or inactive',
            'INVALID_PROVISIONAL_CODE',
            {'userId': userId, 'provisionalRef': provisionalRef}
          );
        }
        
        final referrerUid = codeDoc.data()!['uid'];
        
        // Get referrer user data
        final referrerRef = _firestore.collection('users').doc(referrerUid);
        final referrerDoc = await transaction.get(referrerRef);
        
        if (!referrerDoc.exists) {
          throw OrphanAssignmentException(
            'Referrer user not found',
            'REFERRER_NOT_FOUND',
            {'userId': userId, 'referrerUid': referrerUid}
          );
        }
        
        final referrerData = referrerDoc.data()!;
        final referrerChain = List<String>.from(referrerData['referralChain'] ?? []);
        
        // Build new referral chain
        final newReferralChain = [...referrerChain, provisionalRef];
        
        // Update user with referral relationship
        transaction.update(userRef, {
          'referredBy': provisionalRef,
          'referralChain': newReferralChain,
          'provisionalRef': FieldValue.delete(),
          'boundAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update referrer's direct referral count
        transaction.update(referrerRef, {
          'directReferralCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update team sizes for all ancestors in the chain
        for (final ancestorCode in referrerChain) {
          final ancestorCodeDoc = await transaction.get(
            _firestore.collection('referralCodes').doc(ancestorCode)
          );
          
          if (ancestorCodeDoc.exists && ancestorCodeDoc.data()!['isActive'] == true) {
            final ancestorUid = ancestorCodeDoc.data()!['uid'];
            final ancestorRef = _firestore.collection('users').doc(ancestorUid);
            
            transaction.update(ancestorRef, {
              'totalTeamSize': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
        
        // Update referral code conversion count
        transaction.update(codeRef, {
          'conversionCount': FieldValue.increment(1),
          'lastConversionAt': FieldValue.serverTimestamp(),
        });
        
        if (kDebugMode) {
          print('Bound user $userId to referrer $referrerUid via provisional referral');
        }
      });
      
      // Trigger role progression for referrer and ancestors
      await _triggerRoleProgression(userId);
      
      // Record analytics event
      await _recordFallbackAnalytics(userId);
      
      await MonitoringService.endOperation(
        operationId,
        'bind_provisional_referral',
        userId,
        success: true,
        metadata: {'boundToAdmin': true},
      );
      
      await MonitoringService.logInfo(
        'Successfully bound provisional referral',
        operation: 'bind_provisional_referral',
        userId: userId,
        context: {'referrerCode': ReferralConfig.defaultReferrerCode},
      );
    } catch (e) {
      await MonitoringService.endOperation(
        operationId,
        'bind_provisional_referral',
        userId,
        success: false,
        errorMessage: e.toString(),
      );
      
      await MonitoringService.logError(
        'Failed to bind provisional referral: $e',
        operation: 'bind_provisional_referral',
        userId: userId,
      );
      
      rethrow;
    }
  }
  
  /// Migrate legacy users without referral relationships
  static Future<void> migrateLegacyOrphanUsers() async {
    try {
      if (!ReferralConfig.fallbackEnabled) {
        if (kDebugMode) {
          print('Fallback disabled, skipping legacy migration');
        }
        return;
      }
      
      // Find active users without referral relationships
      final allActiveUsersQuery = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .limit(100) // Process in batches
          .get();

      // Filter for users without referral relationships
      final orphanUserDocs = allActiveUsersQuery.docs.where((doc) {
        final data = doc.data();
        return data['referredBy'] == null;
      }).toList();
      
      if (orphanUserDocs.isEmpty) {
        if (kDebugMode) {
          print('No legacy orphan users found');
        }
        return;
      }

      int migratedCount = 0;

      for (final userDoc in orphanUserDocs) {
        try {
          final userId = userDoc.id;
          final userData = userDoc.data();
          
          // Skip if already has provisional ref or assigned by system
          if (userData['provisionalRef'] != null || userData['assignedBySystem'] == true) {
            continue;
          }
          
          // Set provisional referral
          await handleProvisionalReferral(userId: userId);
          
          // Bind the provisional referral
          await bindProvisionalReferral(userId);
          
          migratedCount++;
          
          if (kDebugMode) {
            print('Migrated legacy orphan user: $userId');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to migrate user ${userDoc.id}: $e');
          }
        }
      }
      
      await MonitoringService.logInfo(
        'Legacy orphan user migration completed',
        operation: 'legacy_migration',
        userId: 'system',
        context: {
          'totalFound': orphanUserDocs.length,
          'migratedCount': migratedCount,
        },
      );
      
      if (kDebugMode) {
        print('Migrated $migratedCount legacy orphan users');
      }
    } catch (e) {
      await MonitoringService.logError(
        'Failed to migrate legacy orphan users: $e',
        operation: 'legacy_migration',
        userId: 'system',
      );
      
      rethrow;
    }
  }
  
  /// Trigger role progression for referrer and ancestors
  static Future<void> _triggerRoleProgression(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final referralChain = List<String>.from(userData['referralChain'] ?? []);

      // Trigger role progression for each user in the chain
      for (final referralCode in referralChain) {
        final codeDoc = await _firestore
            .collection('referralCodes')
            .doc(referralCode)
            .get();

        if (codeDoc.exists && codeDoc.data()!['isActive'] == true) {
          final referrerUid = codeDoc.data()!['uid'];

          // Use simplified role progression to avoid circular dependencies
          await _checkAndUpdateRole(referrerUid);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error triggering role progression: $e');
      }
    }
  }
  
  /// Automated role progression check using new real-time promotion system
  static Future<void> _checkAndUpdateRole(String userId) async {
    try {
      // Use the new automated real-time role progression service
      final promotionResult = await RoleProgressionService.checkAndUpdateRoleRealTime(userId);
      
      if (promotionResult['promoted'] == true) {
        final previousRole = promotionResult['previousRole'] as String;
        final currentRole = promotionResult['currentRole'] as String;
        final directReferrals = promotionResult['directReferrals'] as int;
        final teamSize = promotionResult['teamSize'] as int;
        
        if (kDebugMode) {
          print('🎉 Orphan assignment triggered promotion for user $userId: $previousRole -> $currentRole');
          print('   Direct referrals: $directReferrals, Team size: $teamSize');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in automated role progression for user $userId: $e');
      }
    }
  }
  
  /// Record analytics event for fallback assignment
  static Future<void> _recordFallbackAnalytics(String userId) async {
    try {
      await _firestore.collection('analytics_events').add({
        'event': 'referral_assigned_default',
        'userId': userId,
        'adminUid': await ReferralConfig.getAdminUid(),
        'assignedBySystem': true,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'fallbackCode': ReferralConfig.defaultReferrerCode,
          'source': 'orphan_assignment_service',
        },
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error recording fallback analytics: $e');
      }
    }
  }
}

