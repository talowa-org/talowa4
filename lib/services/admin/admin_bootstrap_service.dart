import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for bootstrapping admin user and ensuring system integrity
class AdminBootstrapService {
  static const String ADMIN_EMAIL = '+917981828388@talowa.app';
  static const String ADMIN_PHONE = '+917981828388';
  static const String ADMIN_REFERRAL_CODE = 'TALADMIN';
  
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// For testing purposes
  static void setFirebaseInstances(FirebaseFirestore firestore, FirebaseAuth auth) {
    _firestore = firestore;
    _auth = auth;
  }
  
  /// Bootstrap admin user - idempotent operation
  /// Returns admin UID if successful
  static Future<String> bootstrapAdmin() async {
    try {
      // Try to find existing admin user by email
      String? adminUid = await _findAdminByEmail();
      
      // If not found, create admin user
      adminUid ??= await _createAdminUser();
      
      // Ensure admin user document exists with correct data
      await _ensureAdminUserDocument(adminUid);
      
      // Ensure TALADMIN referral code is reserved
      await _ensureAdminReferralCode(adminUid);
      
      return adminUid;
    } catch (e) {
      throw AdminBootstrapException(
        'Failed to bootstrap admin: $e',
        'BOOTSTRAP_FAILED',
        {'error': e.toString()}
      );
    }
  }
  
  /// Find admin user by email
  static Future<String?> _findAdminByEmail() async {
    try {
      // Query users collection for admin email
      final usersQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: ADMIN_EMAIL)
          .limit(1)
          .get();
      
      if (usersQuery.docs.isNotEmpty) {
        return usersQuery.docs.first.id;
      }
      
      return null;
    } catch (e) {
      // If query fails, admin doesn't exist
      return null;
    }
  }
  
  /// Create admin user in Firebase Auth
  static Future<String> _createAdminUser() async {
    try {
      // Note: In production, admin should be created manually
      // This is for development/testing purposes
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: ADMIN_EMAIL,
        password: 'AdminPassword123!', // Should be changed immediately
      );
      
      return userCredential.user!.uid;
    } catch (e) {
      throw AdminBootstrapException(
        'Failed to create admin user: $e',
        'ADMIN_CREATION_FAILED',
        {'error': e.toString()}
      );
    }
  }
  
  /// Ensure admin user document exists with correct data
  static Future<void> _ensureAdminUserDocument(String adminUid) async {
    final userRef = _firestore.collection('users').doc(adminUid);
    
    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      
      final adminData = {
        'email': ADMIN_EMAIL,
        'phoneNumber': ADMIN_PHONE,
        'referralCode': ADMIN_REFERRAL_CODE,
        'membershipPaid': true,
        'status': 'active',
        'role': 'admin',
        'directReferralCount': 0,
        'totalTeamSize': 0,
        'referralChain': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (userDoc.exists) {
        // Update existing document with admin data
        transaction.update(userRef, {
          ...adminData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new admin document
        transaction.set(userRef, adminData);
      }
    });
  }
  
  /// Ensure TALADMIN referral code is reserved for admin
  static Future<void> _ensureAdminReferralCode(String adminUid) async {
    final codeRef = _firestore.collection('referralCodes').doc(ADMIN_REFERRAL_CODE);
    
    await _firestore.runTransaction((transaction) async {
      final codeDoc = await transaction.get(codeRef);
      
      final codeData = {
        'uid': adminUid,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'isAdmin': true,
      };
      
      if (codeDoc.exists) {
        // Update existing code reservation
        transaction.update(codeRef, {
          ...codeData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new code reservation
        transaction.set(codeRef, codeData);
      }
    });
  }
  
  /// Check if admin is properly bootstrapped
  static Future<bool> isAdminBootstrapped() async {
    try {
      // Check if admin user exists
      final adminUid = await _findAdminByEmail();
      if (adminUid == null) return false;
      
      // Check if admin user document is correct
      final userDoc = await _firestore.collection('users').doc(adminUid).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      if (userData['referralCode'] != ADMIN_REFERRAL_CODE ||
          userData['membershipPaid'] != true) {
        return false;
      }
      
      // Check if TALADMIN code is reserved
      final codeDoc = await _firestore
          .collection('referralCodes')
          .doc(ADMIN_REFERRAL_CODE)
          .get();
      
      if (!codeDoc.exists) return false;
      
      final codeData = codeDoc.data()!;
      return codeData['uid'] == adminUid && codeData['active'] == true;
    } catch (e) {
      return false;
    }
  }
}

/// Exception thrown when admin bootstrap fails
class AdminBootstrapException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const AdminBootstrapException(this.message, [this.code = 'ADMIN_BOOTSTRAP_FAILED', this.context]);
  
  @override
  String toString() => 'AdminBootstrapException: $message';
}
