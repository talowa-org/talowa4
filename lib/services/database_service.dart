// Database Service for TALOWA
// Reference: TECHNICAL_ARCHITECTURE.md - Database Structure

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/land_record_model.dart';
import 'referral/referral_code_generator.dart';
import '../models/message_model.dart';
import 'referral/referral_chain_service.dart';

class DatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User Registry Operations (Lightweight lookups)
  static Future<bool> isPhoneRegistered(String phoneNumber) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.collectionUserRegistry)
          .doc(phoneNumber)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking phone registration: $e');
      return false;
    }
  }

  static Future<void> createUserRegistry({
    required String phoneNumber,
    required String uid,
    required String email,
    required String role,
    required String state,
    required String district,
    String? mandal,
    String? village,
    String? pinHash, // Add PIN hash parameter for login verification
    String? referralCode, // Use existing referral code instead of generating new one
  }) async {
    try {
      // Check if registry already exists to prevent duplicates
      final existingDoc = await _firestore
          .collection(AppConstants.collectionUserRegistry)
          .doc(phoneNumber)
          .get();

      if (existingDoc.exists) {
        debugPrint('User registry already exists for phone: $phoneNumber');
        return;
      }

      // Use provided referral code or generate new one if not provided
      final finalReferralCode = referralCode ?? await ReferralCodeGenerator.generateUniqueCode();
      debugPrint('Using referral code for registry: $finalReferralCode');

      await _firestore
          .collection(AppConstants.collectionUserRegistry)
          .doc(phoneNumber)
          .set({
            'uid': uid,
            'email': email,
            'phoneNumber': phoneNumber,
            'role': role,
            'state': state,
            'district': district,
            'mandal': mandal,
            'village': village,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'referralCode': finalReferralCode,
            'directReferrals': 0,
            'teamSize': 0,
            'membershipPaid': false,
            'pinHash': pinHash, // Store PIN hash for login verification
          });
    } catch (e) {
      debugPrint('Error creating user registry: $e');
      throw Exception('Failed to create user registry');
    }
  }

  // User Profile Operations
  static Future<void> createUserProfile(UserModel user) async {
    try {
      // Check if user profile already exists to prevent duplicates
      final existingDoc = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(user.id)
          .get();

      if (existingDoc.exists) {
        debugPrint('User profile already exists for UID: ${user.id}');
        return;
      }

      // Create the user profile
      await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(user.id)
          .set(user.toFirestore());

      // Process referral chain after user creation (BSS integration)
      try {
        await ReferralChainService.processNewUserReferral(
          newUserId: user.id,
          referralCode: user.referredBy,
        );
        debugPrint('✅ Referral chain processed for user: ${user.fullName}');
      } catch (e) {
        debugPrint('⚠️ Referral chain processing failed (non-critical): $e');
        // Don't throw - user creation should succeed even if referral processing fails
      }

    } catch (e) {
      debugPrint('Error creating user profile: $e');
      throw Exception('Failed to create user profile');
    }
  }

  static Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  static Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(user.id)
          .update(user.toFirestore());
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      throw Exception('Failed to update user profile');
    }
  }

  // Land Records Operations
  static Future<String> createLandRecord(LandRecordModel landRecord) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.collectionLandRecords)
          .add(landRecord.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating land record: $e');
      throw Exception('Failed to create land record');
    }
  }

  static Future<List<LandRecordModel>> getUserLandRecords(
    String ownerId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.collectionLandRecords)
          .where('ownerId', isEqualTo: ownerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => LandRecordModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting user land records: $e');
      return [];
    }
  }

  static Future<void> updateLandRecord(LandRecordModel landRecord) async {
    try {
      await _firestore
          .collection(AppConstants.collectionLandRecords)
          .doc(landRecord.id)
          .update(landRecord.toFirestore());
    } catch (e) {
      debugPrint('Error updating land record: $e');
      throw Exception('Failed to update land record');
    }
  }

  // Message Operations
  static Future<String> sendMessage(MessageModel message) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.collectionMessages)
          .add(message.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('Error sending message: $e');
      throw Exception('Failed to send message');
    }
  }

  static Stream<List<MessageModel>> getConversationMessages({
    String? recipientId,
    String? groupId,
    int limit = 50,
  }) {
    try {
      Query query = _firestore.collection(AppConstants.collectionMessages);

      if (recipientId != null) {
        // Direct conversation
        query = query.where('recipientId', isEqualTo: recipientId);
      } else if (groupId != null) {
        // Group conversation
        query = query.where('groupId', isEqualTo: groupId);
      }

      return query
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => MessageModel.fromFirestore(doc))
                .toList(),
          );
    } catch (e) {
      debugPrint('Error getting conversation messages: $e');
      return Stream.value([]);
    }
  }

  static Future<void> markMessageAsRead(String messageId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.collectionMessages)
          .doc(messageId)
          .update({
            'status': 'read',
            'readAt': FieldValue.serverTimestamp(),
            'readBy': FieldValue.arrayUnion([userId]),
          });
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  // Geographic Hierarchy Operations
  static Future<void> createGeographicHierarchy() async {
    try {
      // Create Telangana state structure
      await _createStateStructure();
    } catch (e) {
      debugPrint('Error creating geographic hierarchy: $e');
    }
  }

  static Future<void> _createStateStructure() async {
    // Create Telangana state
    await _firestore
        .collection(AppConstants.collectionStates)
        .doc('telangana')
        .set({
          'id': 'telangana',
          'name': 'Telangana',
          'coordinator': null,
          'totalMembers': 0,
          'activeCoordinators': 0,
          'activeCampaigns': 0,
          'landRecords': 0,
          'districts': ['hyderabad', 'warangal', 'nizamabad', 'karimnagar'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // Create sample districts
    final districts = [
      {'id': 'hyderabad', 'name': 'Hyderabad'},
      {'id': 'warangal', 'name': 'Warangal'},
      {'id': 'nizamabad', 'name': 'Nizamabad'},
      {'id': 'karimnagar', 'name': 'Karimnagar'},
    ];

    for (final district in districts) {
      await _firestore
          .collection(AppConstants.collectionStates)
          .doc('telangana')
          .collection('districts')
          .doc(district['id'])
          .set({
            'id': district['id'],
            'name': district['name'],
            'stateId': 'telangana',
            'coordinator': null,
            'totalMembers': 0,
            'activeCoordinators': 0,
            'activeCampaigns': 0,
            'landRecords': 0,
            'mandals': [],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    }
  }

  // Referral Operations
  static Future<void> addReferral({
    required String referrerId,
    required String referredUserId,
    required String referralCode,
  }) async {
    try {
      // Update referrer's stats
      await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(referrerId)
          .update({
            'directReferrals': FieldValue.increment(1),
            'teamSize': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update user registry
      final userRegistryQuery = await _firestore
          .collection(AppConstants.collectionUserRegistry)
          .where('uid', isEqualTo: referrerId)
          .limit(1)
          .get();

      if (userRegistryQuery.docs.isNotEmpty) {
        await userRegistryQuery.docs.first.reference.update({
          'directReferrals': FieldValue.increment(1),
          'teamSize': FieldValue.increment(1),
        });
      }

      // Create referral relationship record
      await _firestore.collection('referral_relationships').add({
        'referrerId': referrerId,
        'referredUserId': referredUserId,
        'referralCode': referralCode,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (e) {
      debugPrint('Error adding referral: $e');
      throw Exception('Failed to add referral');
    }
  }

  // Utility Methods
  // Note: Referral code generation is now handled by ReferralCodeGenerator service
  // All referral codes follow TAL + 6 Crockford base32 format

  // Performance Monitoring
  static Future<void> logDatabaseOperation(
    String operation,
    int duration,
  ) async {
    try {
      await _firestore.collection('performance_metrics').add({
        'operation': operation,
        'responseTime': duration,
        'success': true,
        'platform': 'mobile',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging database operation: $e');
    }
  }

  // Batch Operations for Performance
  static Future<void> batchCreateUsers(List<UserModel> users) async {
    try {
      final batch = _firestore.batch();

      for (final user in users) {
        final docRef = _firestore
            .collection(AppConstants.collectionUsers)
            .doc(user.id);
        batch.set(docRef, user.toFirestore());
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error batch creating users: $e');
      throw Exception('Failed to batch create users');
    }
  }

  // Search Operations
  static Future<List<UserModel>> searchUsers({
    required String query,
    String? role,
    String? state,
    String? district,
    int limit = 20,
  }) async {
    try {
      Query firestoreQuery = _firestore.collection(
        AppConstants.collectionUsers,
      );

      if (role != null) {
        firestoreQuery = firestoreQuery.where('role', isEqualTo: role);
      }

      if (state != null) {
        firestoreQuery = firestoreQuery.where(
          'address.state',
          isEqualTo: state,
        );
      }

      if (district != null) {
        firestoreQuery = firestoreQuery.where(
          'address.district',
          isEqualTo: district,
        );
      }

      final querySnapshot = await firestoreQuery.limit(limit).get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where(
            (user) =>
                user.fullName.toLowerCase().contains(query.toLowerCase()) ||
                user.phoneNumber.contains(query),
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // Get users by geographic location
  static Future<List<UserModel>> getUsersByLocation({
    required String level,
    required String locationId,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection(AppConstants.collectionUsers);

      switch (level) {
        case AppConstants.levelVillage:
          query = query.where('address.villageCity', isEqualTo: locationId);
          break;
        case AppConstants.levelMandal:
          query = query.where('address.mandal', isEqualTo: locationId);
          break;
        case AppConstants.levelDistrict:
          query = query.where('address.district', isEqualTo: locationId);
          break;
        case AppConstants.levelState:
          query = query.where('address.state', isEqualTo: locationId);
          break;
      }

      final querySnapshot = await query
          .where('isActive', isEqualTo: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting users by location: $e');
      return [];
    }
  }

  // Get user by ID
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }
}
