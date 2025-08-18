import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/referral/referral_models.dart';
import 'referral_tracking_service.dart';
import 'orphan_assignment_service.dart';

/// Exception thrown when payment integration fails
class PaymentIntegrationException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const PaymentIntegrationException(this.message, [this.code = 'PAYMENT_INTEGRATION_FAILED', this.context]);
  
  @override
  String toString() => 'PaymentIntegrationException: $message';
}

/// Service for handling payment integration and referral activation
class PaymentIntegrationService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String WEBHOOK_SECRET = 'talowa_webhook_secret_key'; // Should be from environment
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Handle payment webhook from payment provider
  static Future<Map<String, dynamic>> handlePaymentWebhook({
    required Map<String, dynamic> webhookData,
    required String signature,
    required String provider,
  }) async {
    try {
      // Verify webhook signature
      if (!_verifyWebhookSignature(webhookData, signature)) {
        throw PaymentIntegrationException(
          'Invalid webhook signature',
          'INVALID_SIGNATURE',
          {'provider': provider}
        );
      }
      
      // Parse payment data based on provider
      final paymentData = await _parsePaymentData(webhookData, provider);
      
      // Validate payment
      final validationResult = await _validatePayment(paymentData);
      if (!validationResult['isValid']) {
        throw PaymentIntegrationException(
          'Payment validation failed: ${validationResult['error']}',
          'PAYMENT_VALIDATION_FAILED',
          {'paymentData': paymentData}
        );
      }
      
      // Process payment and activate referrals
      final result = await _processPaymentAndActivateReferrals(paymentData);
      
      return {
        'success': true,
        'paymentId': paymentData['paymentId'],
        'userId': paymentData['userId'],
        'referralsActivated': result['referralsActivated'],
        'rolePromotions': result['rolePromotions'],
      };
      
    } catch (e) {
      await _logPaymentError('webhook_processing', e, {
        'provider': provider,
        'webhookData': webhookData,
      });
      
      if (e is PaymentIntegrationException) {
        rethrow;
      }
      
      throw PaymentIntegrationException(
        'Failed to process payment webhook: $e',
        'WEBHOOK_PROCESSING_FAILED',
        {'provider': provider}
      );
    }
  }
  
  /// Manually verify and activate payment (for testing/admin)
  static Future<Map<String, dynamic>> manualPaymentActivation({
    required String userId,
    required String paymentId,
    required double amount,
    required String currency,
    String? adminUserId,
  }) async {
    try {
      final paymentData = {
        'paymentId': paymentId,
        'userId': userId,
        'amount': amount,
        'currency': currency,
        'status': 'completed',
        'provider': 'manual',
        'timestamp': DateTime.now().toIso8601String(),
        'adminUserId': adminUserId,
      };
      
      // Validate user exists
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw PaymentIntegrationException(
          'User not found: $userId',
          'USER_NOT_FOUND',
          {'userId': userId}
        );
      }
      
      // Process payment
      final result = await _processPaymentAndActivateReferrals(paymentData);
      
      return {
        'success': true,
        'paymentId': paymentId,
        'userId': userId,
        'referralsActivated': result['referralsActivated'],
        'rolePromotions': result['rolePromotions'],
        'processedBy': adminUserId ?? 'system',
      };
      
    } catch (e) {
      await _logPaymentError('manual_activation', e, {
        'userId': userId,
        'paymentId': paymentId,
        'adminUserId': adminUserId,
      });
      rethrow;
    }
  }
  
  /// Process payment and activate referral chain
  static Future<Map<String, dynamic>> _processPaymentAndActivateReferrals(
    Map<String, dynamic> paymentData
  ) async {
    final batch = _firestore.batch();
    final userId = paymentData['userId'] as String;
    final paymentId = paymentData['paymentId'] as String;
    
    try {
      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw PaymentIntegrationException(
          'User not found: $userId',
          'USER_NOT_FOUND',
          {'userId': userId}
        );
      }
      
      final userData = userDoc.data()!;
      
      // Check if payment already processed
      if (userData['membershipPaid'] == true) {
        return {
          'referralsActivated': false,
          'rolePromotions': [],
          'message': 'Payment already processed',
        };
      }
      
      // Update user payment status
      batch.update(userDoc.reference, {
        'membershipPaid': true,
        'paymentTransactionId': paymentId,
        'paymentCompletedAt': FieldValue.serverTimestamp(),
        'paymentAmount': paymentData['amount'],
        'paymentCurrency': paymentData['currency'] ?? 'INR',
        'paymentProvider': paymentData['provider'] ?? 'unknown',
        'status': 'active',
      });

      // Activate user's referral code
      final userReferralCode = userData['referralCode'];
      if (userReferralCode != null) {
        final codeRef = _firestore.collection('referralCodes').doc(userReferralCode);
        batch.update(codeRef, {
          'isActive': true,
          'activatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Record payment transaction
      final paymentRef = _firestore.collection('payments').doc(paymentId);
      batch.set(paymentRef, {
        'paymentId': paymentId,
        'userId': userId,
        'amount': paymentData['amount'],
        'currency': paymentData['currency'] ?? 'INR',
        'status': 'completed',
        'provider': paymentData['provider'] ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'webhookData': paymentData,
      });
      
      await batch.commit();

      // Handle orphan assignment binding after payment
      await OrphanAssignmentService.bindProvisionalReferral(userId);

      // Activate referral chain
      await ReferralTrackingService.activateReferralChain(userId);
      
      // Get updated user data for role promotions
      final updatedUserDoc = await _firestore.collection('users').doc(userId).get();
      final updatedUserData = updatedUserDoc.data()!;
      
      return {
        'referralsActivated': true,
        'rolePromotions': await _getRolePromotions(updatedUserData['referralChain'] ?? []),
        'message': 'Payment processed and referrals activated successfully',
      };
      
    } catch (e) {
      throw PaymentIntegrationException(
        'Failed to process payment and activate referrals: $e',
        'PROCESSING_FAILED',
        {'userId': userId, 'paymentId': paymentId}
      );
    }
  }
  
  /// Verify webhook signature
  static bool _verifyWebhookSignature(Map<String, dynamic> data, String signature) {
    try {
      final payload = json.encode(data);
      final expectedSignature = _generateSignature(payload);
      return expectedSignature == signature;
    } catch (e) {
      return false;
    }
  }
  
  /// Generate HMAC signature for webhook verification
  static String _generateSignature(String payload) {
    final key = utf8.encode(WEBHOOK_SECRET);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }
  
  /// Parse payment data from different providers
  static Future<Map<String, dynamic>> _parsePaymentData(
    Map<String, dynamic> webhookData,
    String provider,
  ) async {
    switch (provider.toLowerCase()) {
      case 'razorpay':
        return _parseRazorpayData(webhookData);
      case 'stripe':
        return _parseStripeData(webhookData);
      case 'paytm':
        return _parsePaytmData(webhookData);
      case 'phonepe':
        return _parsePhonePeData(webhookData);
      case 'manual':
        return webhookData;
      default:
        throw PaymentIntegrationException(
          'Unsupported payment provider: $provider',
          'UNSUPPORTED_PROVIDER',
          {'provider': provider}
        );
    }
  }
  
  /// Parse Razorpay webhook data
  static Map<String, dynamic> _parseRazorpayData(Map<String, dynamic> data) {
    final payment = data['payload']['payment']['entity'];
    return {
      'paymentId': payment['id'],
      'userId': payment['notes']['userId'],
      'amount': payment['amount'] / 100, // Razorpay uses paise
      'currency': payment['currency'],
      'status': payment['status'],
      'provider': 'razorpay',
      'timestamp': DateTime.fromMillisecondsSinceEpoch(payment['created_at'] * 1000).toIso8601String(),
      'rawData': data,
    };
  }
  
  /// Parse Stripe webhook data
  static Map<String, dynamic> _parseStripeData(Map<String, dynamic> data) {
    final payment = data['data']['object'];
    return {
      'paymentId': payment['id'],
      'userId': payment['metadata']['userId'],
      'amount': payment['amount'] / 100, // Stripe uses cents
      'currency': payment['currency'],
      'status': payment['status'],
      'provider': 'stripe',
      'timestamp': DateTime.fromMillisecondsSinceEpoch(payment['created'] * 1000).toIso8601String(),
      'rawData': data,
    };
  }
  
  /// Parse Paytm webhook data
  static Map<String, dynamic> _parsePaytmData(Map<String, dynamic> data) {
    return {
      'paymentId': data['TXNID'],
      'userId': data['CUST_ID'],
      'amount': double.parse(data['TXNAMOUNT']),
      'currency': data['CURRENCY'] ?? 'INR',
      'status': data['STATUS'],
      'provider': 'paytm',
      'timestamp': data['TXNDATE'],
      'rawData': data,
    };
  }
  
  /// Parse PhonePe webhook data
  static Map<String, dynamic> _parsePhonePeData(Map<String, dynamic> data) {
    final response = data['response'];
    return {
      'paymentId': response['transactionId'],
      'userId': response['merchantUserId'],
      'amount': response['amount'] / 100, // PhonePe uses paise
      'currency': 'INR',
      'status': response['state'],
      'provider': 'phonepe',
      'timestamp': DateTime.now().toIso8601String(),
      'rawData': data,
    };
  }
  
  /// Validate payment data
  static Future<Map<String, dynamic>> _validatePayment(Map<String, dynamic> paymentData) async {
    try {
      // Check required fields
      final requiredFields = ['paymentId', 'userId', 'amount', 'status'];
      for (final field in requiredFields) {
        if (!paymentData.containsKey(field) || paymentData[field] == null) {
          return {
            'isValid': false,
            'error': 'Missing required field: $field',
          };
        }
      }
      
      // Validate payment status
      final validStatuses = ['completed', 'captured', 'success', 'TXN_SUCCESS'];
      if (!validStatuses.contains(paymentData['status'])) {
        return {
          'isValid': false,
          'error': 'Invalid payment status: ${paymentData['status']}',
        };
      }
      
      // Validate amount
      final amount = paymentData['amount'];
      if (amount is! num || amount <= 0) {
        return {
          'isValid': false,
          'error': 'Invalid payment amount: $amount',
        };
      }
      
      // Check for duplicate payment
      final existingPayment = await _firestore
          .collection('payments')
          .doc(paymentData['paymentId'])
          .get();
      
      if (existingPayment.exists) {
        return {
          'isValid': false,
          'error': 'Payment already processed: ${paymentData['paymentId']}',
        };
      }
      
      return {'isValid': true};
      
    } catch (e) {
      return {
        'isValid': false,
        'error': 'Validation error: $e',
      };
    }
  }
  
  /// Get role promotions from referral chain
  static Future<List<Map<String, dynamic>>> _getRolePromotions(List<dynamic> referralChain) async {
    final promotions = <Map<String, dynamic>>[];
    
    for (final userId in referralChain) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final currentRole = userData['currentRole'] ?? 'member';
          final previousRole = userData['previousRole'];
          
          if (previousRole != null && currentRole != previousRole) {
            promotions.add({
              'userId': userId,
              'userName': userData['fullName'],
              'previousRole': previousRole,
              'currentRole': currentRole,
              'promotedAt': userData['rolePromotedAt'],
            });
          }
        }
      } catch (e) {
        // Continue processing other users
        continue;
      }
    }
    
    return promotions;
  }
  
  /// Log payment error
  static Future<void> _logPaymentError(String operation, dynamic error, Map<String, dynamic> context) async {
    try {
      await _firestore.collection('paymentErrors').add({
        'operation': operation,
        'error': error.toString(),
        'context': context,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to log payment error: $e');
    }
  }
  
  /// Get payment status
  static Future<Map<String, dynamic>?> getPaymentStatus(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw PaymentIntegrationException(
        'Failed to get payment status: $e',
        'STATUS_RETRIEVAL_FAILED',
        {'paymentId': paymentId}
      );
    }
  }
  
  /// Get user payment history
  static Future<List<Map<String, dynamic>>> getUserPaymentHistory(String userId) async {
    try {
      final query = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
      
      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw PaymentIntegrationException(
        'Failed to get payment history: $e',
        'HISTORY_RETRIEVAL_FAILED',
        {'userId': userId}
      );
    }
  }
}
