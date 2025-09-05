import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:talowa/config/referral_config.dart';
import 'package:talowa/services/referral/referral_code_generator.dart';
import 'package:talowa/services/referral/monitoring_service.dart';

/// Exception thrown when user registration operations fail
class UserRegistrationException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const UserRegistrationException(this.message, [this.code = 'REGISTRATION_FAILED', this.context]);
  
  @override
  String toString() => 'UserRegistrationException: $message';
}

/// Service for handling user registration with orphan assignment
class UserRegistrationService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Step 1: Create user profile with pending payment status and immediate referral code
  static Future<Map<String, dynamic>> createUserProfile({
    required String userId,
    required String fullName,
    required String email,
    String? phone,
    String? providedReferralCode,
    Map<String, dynamic>? additionalData,
  }) async {
    final operationId = 'create_profile_${DateTime.now().microsecondsSinceEpoch}';

    try {
      MonitoringService.startOperation(operationId, 'create_user_profile', userId);

      // Generate user's own TAL-prefixed referral code immediately
      final userReferralCode = await ReferralCodeGenerator.generateUniqueCode();

      // Determine provisional referral
      String provisionalRef = 'TALADMIN';
      bool assignedBySystem = true;

      if (providedReferralCode != null && providedReferralCode.isNotEmpty) {
        // Validate provided referral code
        final isValid = await _validateReferralCode(providedReferralCode);
        if (isValid) {
          provisionalRef = providedReferralCode;
          assignedBySystem = false;
        }
      }

      // Prepare user data
      final userData = {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'referralCode': userReferralCode,
        'status': 'pending_payment',
        'membershipPaid': false,
        'directReferralCount': 0,
        'totalTeamSize': 0,
        'role': 'member',
        'provisionalRef': provisionalRef,
        'assignedBySystem': assignedBySystem,
        'referredBy': null, // Will be set after payment
        'referralChain': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      // Create/update user profile in transaction
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final codeRef = _firestore.collection('referralCodes').doc(userReferralCode);

        // Check if user already exists
        final existingUser = await transaction.get(userRef);
        if (existingUser.exists) {
          // Update existing user with new data
          transaction.update(userRef, userData);
        } else {
          // Create new user profile
          transaction.set(userRef, userData);
        }

        // Ensure referral code is reserved
        transaction.set(codeRef, {
          'uid': userId,
          'active': true, // Active immediately for sharing
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      await MonitoringService.endOperation(
        operationId,
        'create_user_profile',
        userId,
        success: true,
        metadata: {
          'userReferralCode': userReferralCode,
          'providedReferralCode': providedReferralCode,
          'provisionalRef': provisionalRef,
          'assignedBySystem': assignedBySystem,
        },
      );

      await MonitoringService.logInfo(
        'User profile created successfully with immediate referral code',
        operation: 'create_user_profile',
        userId: userId,
        context: {
          'email': email,
          'referralCode': userReferralCode,
          'providedCode': providedReferralCode,
          'provisionalRef': provisionalRef,
        },
      );

      return {
        'success': true,
        'userId': userId,
        'referralCode': userReferralCode,
        'status': 'pending_payment',
        'provisionalRef': provisionalRef,
        'assignedBySystem': assignedBySystem,
      };
    } catch (e) {
      await MonitoringService.endOperation(
        operationId,
        'create_user_profile',
        userId,
        success: false,
        errorMessage: e.toString(),
      );
      
      await MonitoringService.logError(
        'Failed to create user profile: $e',
        operation: 'create_user_profile',
        userId: userId,
        context: {
          'email': email,
          'providedCode': providedReferralCode,
        },
      );
      
      rethrow;
    }
  }

  /// Validates if a referral code exists and is active
  static Future<bool> _validateReferralCode(String code) async {
    try {
      final codeDoc = await _firestore
          .collection('referralCodes')
          .doc(code)
          .get();

      if (!codeDoc.exists) return false;

      final codeData = codeDoc.data()!;
      return codeData['active'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Step 2: Activate user after payment confirmation
  static Future<Map<String, dynamic>> activateUserAfterPayment({
    required String userId,
    required String paymentId,
    required double amount,
    required String currency,
    Map<String, dynamic>? paymentMetadata,
  }) async {
    final operationId = 'activate_user_${DateTime.now().microsecondsSinceEpoch}';
    
    try {
      MonitoringService.startOperation(operationId, 'activate_user_payment', userId);
      
      Map<String, dynamic> result = {};
      
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw UserRegistrationException(
            'User not found',
            'USER_NOT_FOUND',
            {'userId': userId}
          );
        }
        
        final userData = userDoc.data()!;
        
        // Verify user is in pending payment status
        if (userData['status'] != 'pending_payment') {
          throw UserRegistrationException(
            'User is not in pending payment status',
            'INVALID_STATUS',
            {'userId': userId, 'currentStatus': userData['status']}
          );
        }
        
        // Handle referral binding if provisionalRef exists and referredBy is null
        final provisionalRef = userData['provisionalRef'] as String?;
        final referredBy = userData['referredBy'] as String?;

        Map<String, dynamic> updateData = {
          'status': 'active',
          'membershipPaid': true,
          'paidAt': FieldValue.serverTimestamp(),
          'paymentId': paymentId,
          'paymentAmount': amount,
          'paymentCurrency': currency,
          'paymentMetadata': paymentMetadata ?? {},
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Bind referral if conditions are met
        if (referredBy == null && provisionalRef != null) {
          // Get referrer data to build chain
          final referrerDoc = await _firestore
              .collection('users')
              .where('referralCode', isEqualTo: provisionalRef)
              .limit(1)
              .get();

          if (referrerDoc.docs.isNotEmpty) {
            final referrerData = referrerDoc.docs.first.data();
            final referrerChain = List<String>.from(referrerData['referralChain'] ?? []);

            // Update user with referral binding
            updateData.addAll({
              'referredBy': provisionalRef,
              'referralChain': [...referrerChain, provisionalRef],
            });

            // Increment referrer's direct referral count
            final referrerRef = referrerDoc.docs.first.reference;
            transaction.update(referrerRef, {
              'directReferralCount': FieldValue.increment(1),
              'totalTeamSize': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            // Increment ancestors' team sizes
            for (final ancestorCode in referrerChain) {
              final ancestorQuery = await _firestore
                  .collection('users')
                  .where('referralCode', isEqualTo: ancestorCode)
                  .limit(1)
                  .get();

              if (ancestorQuery.docs.isNotEmpty) {
                transaction.update(ancestorQuery.docs.first.reference, {
                  'totalTeamSize': FieldValue.increment(1),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }
        }

        // Apply all updates to user
        transaction.update(userRef, updateData);

        // User's referral code is already active from registration
        final userReferralCode = userData['referralCode'];

        result = {
          'success': true,
          'userId': userId,
          'status': 'active',
          'referralCode': userReferralCode,
          'paymentId': paymentId,
          'referredBy': updateData['referredBy'],
        };
      });
      
      // Record payment activation analytics
      await _recordPaymentActivationAnalytics(userId, paymentId, amount, currency);
      
      await MonitoringService.endOperation(
        operationId,
        'activate_user_payment',
        userId,
        success: true,
        metadata: {
          'paymentId': paymentId,
          'amount': amount,
          'currency': currency,
        },
      );
      
      await MonitoringService.logInfo(
        'User activated after payment',
        operation: 'activate_user_payment',
        userId: userId,
        context: {
          'paymentId': paymentId,
          'amount': amount,
          'currency': currency,
        },
      );
      
      return result;
    } catch (e) {
      await MonitoringService.endOperation(
        operationId,
        'activate_user_payment',
        userId,
        success: false,
        errorMessage: e.toString(),
      );
      
      await MonitoringService.logError(
        'Failed to activate user after payment: $e',
        operation: 'activate_user_payment',
        userId: userId,
        context: {
          'paymentId': paymentId,
          'amount': amount,
          'currency': currency,
        },
      );
      
      rethrow;
    }
  }
  
  /// Get user registration status
  static Future<Map<String, dynamic>> getUserRegistrationStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return {
          'exists': false,
          'status': null,
        };
      }
      
      final userData = userDoc.data()!;
      
      return {
        'exists': true,
        'status': userData['status'],
        'membershipPaid': userData['membershipPaid'] ?? false,
        'referralCode': userData['referralCode'],
        'createdAt': userData['createdAt'],
        'paidAt': userData['paidAt'],
        'provisionalRef': userData['provisionalRef'],
        'assignedBySystem': userData['assignedBySystem'] ?? false,
        'referredBy': userData['referredBy'],
      };
    } catch (e) {
      await MonitoringService.logError(
        'Failed to get user registration status: $e',
        operation: 'get_registration_status',
        userId: userId,
      );
      
      rethrow;
    }
  }
  
  /// Initialize the registration system
  static Future<void> initializeRegistrationSystem() async {
    try {
      // Bootstrap admin user and configuration
      await ReferralConfig.bootstrapAdminUser();
      
      // Verify admin configuration
      final isValid = await ReferralConfig.verifyAdminConfiguration();
      if (!isValid) {
        throw const UserRegistrationException(
          'Failed to initialize admin configuration',
          'ADMIN_INIT_FAILED'
        );
      }
      
      if (kDebugMode) {
        print('User registration system initialized successfully');
      }
    } catch (e) {
      await MonitoringService.logError(
        'Failed to initialize registration system: $e',
        operation: 'initialize_registration_system',
        userId: 'system',
      );
      
      rethrow;
    }
  }
  
  /// Record payment activation analytics
  static Future<void> _recordPaymentActivationAnalytics(
    String userId,
    String paymentId,
    double amount,
    String currency,
  ) async {
    try {
      await _firestore.collection('analytics_events').add({
        'event': 'user_payment_activation',
        'userId': userId,
        'paymentId': paymentId,
        'amount': amount,
        'currency': currency,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'source': 'user_registration_service',
        },
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error recording payment activation analytics: $e');
      }
    }
  }
}

