import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_integration_service.dart';

/// Exception thrown when membership payment operations fail
class MembershipPaymentException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const MembershipPaymentException(this.message, [this.code = 'MEMBERSHIP_PAYMENT_FAILED', this.context]);
  
  @override
  String toString() => 'MembershipPaymentException: $message';
}

/// Service for handling membership payments and validation
class MembershipPaymentService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Membership pricing (in INR)
  static const double MEMBERSHIP_FEE_INR = 100.0;
  static const String DEFAULT_CURRENCY = 'INR';
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Initiate membership payment
  static Future<Map<String, dynamic>> initiateMembershipPayment({
    required String userId,
    required String paymentProvider,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Validate user
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw MembershipPaymentException(
          'User not found: $userId',
          'USER_NOT_FOUND',
          {'userId': userId}
        );
      }
      
      final userData = userDoc.data()!;
      
      // Check if already paid
      if (userData['membershipPaid'] == true) {
        throw MembershipPaymentException(
          'Membership already paid for user: $userId',
          'ALREADY_PAID',
          {'userId': userId}
        );
      }
      
      // Generate payment order
      final paymentOrder = await _createPaymentOrder(
        userId: userId,
        amount: MEMBERSHIP_FEE_INR,
        currency: DEFAULT_CURRENCY,
        provider: paymentProvider,
        userData: userData,
        additionalData: additionalData,
      );
      
      // Record payment initiation
      await _recordPaymentInitiation(userId, paymentOrder);
      
      return {
        'success': true,
        'paymentOrder': paymentOrder,
        'amount': MEMBERSHIP_FEE_INR,
        'currency': DEFAULT_CURRENCY,
        'userId': userId,
      };
      
    } catch (e) {
      await _logPaymentError('initiate_payment', e, {
        'userId': userId,
        'provider': paymentProvider,
      });
      
      if (e is MembershipPaymentException) {
        rethrow;
      }
      
      throw MembershipPaymentException(
        'Failed to initiate membership payment: $e',
        'INITIATION_FAILED',
        {'userId': userId, 'provider': paymentProvider}
      );
    }
  }
  
  /// Create payment order based on provider
  static Future<Map<String, dynamic>> _createPaymentOrder({
    required String userId,
    required double amount,
    required String currency,
    required String provider,
    required Map<String, dynamic> userData,
    Map<String, dynamic>? additionalData,
  }) async {
    final orderId = _generateOrderId(userId);
    
    switch (provider.toLowerCase()) {
      case 'razorpay':
        return _createRazorpayOrder(orderId, userId, amount, currency, userData);
      case 'stripe':
        return _createStripeOrder(orderId, userId, amount, currency, userData);
      case 'paytm':
        return _createPaytmOrder(orderId, userId, amount, currency, userData);
      case 'phonepe':
        return _createPhonePeOrder(orderId, userId, amount, currency, userData);
      default:
        throw MembershipPaymentException(
          'Unsupported payment provider: $provider',
          'UNSUPPORTED_PROVIDER',
          {'provider': provider}
        );
    }
  }
  
  /// Create Razorpay payment order
  static Future<Map<String, dynamic>> _createRazorpayOrder(
    String orderId,
    String userId,
    double amount,
    String currency,
    Map<String, dynamic> userData,
  ) async {
    return {
      'orderId': orderId,
      'amount': (amount * 100).toInt(), // Razorpay uses paise
      'currency': currency,
      'receipt': orderId,
      'notes': {
        'userId': userId,
        'membershipPayment': true,
        'userName': userData['fullName'],
        'userEmail': userData['email'],
      },
      'provider': 'razorpay',
      'key': 'rzp_test_key', // Should be from environment
      'name': 'TALOWA Membership',
      'description': 'TALOWA Movement Membership Fee',
      'image': 'https://talowa.web.app/logo.png',
      'prefill': {
        'name': userData['fullName'],
        'email': userData['email'],
        'contact': userData['phoneNumber'],
      },
      'theme': {
        'color': '#2E7D32',
      },
    };
  }
  
  /// Create Stripe payment order
  static Future<Map<String, dynamic>> _createStripeOrder(
    String orderId,
    String userId,
    double amount,
    String currency,
    Map<String, dynamic> userData,
  ) async {
    return {
      'orderId': orderId,
      'amount': (amount * 100).toInt(), // Stripe uses cents
      'currency': currency.toLowerCase(),
      'metadata': {
        'userId': userId,
        'membershipPayment': 'true',
        'userName': userData['fullName'],
      },
      'provider': 'stripe',
      'publicKey': 'pk_test_key', // Should be from environment
      'description': 'TALOWA Movement Membership Fee',
      'customerEmail': userData['email'],
    };
  }
  
  /// Create Paytm payment order
  static Future<Map<String, dynamic>> _createPaytmOrder(
    String orderId,
    String userId,
    double amount,
    String currency,
    Map<String, dynamic> userData,
  ) async {
    return {
      'orderId': orderId,
      'amount': amount.toString(),
      'currency': currency,
      'customerId': userId,
      'provider': 'paytm',
      'merchantId': 'TALOWA_MID', // Should be from environment
      'website': 'WEBSTAGING', // Should be from environment
      'industryType': 'Retail',
      'channelId': 'WAP',
      'callbackUrl': 'https://talowa.web.app/payment/callback',
      'customerInfo': {
        'custId': userId,
        'mobile': userData['phoneNumber'],
        'email': userData['email'],
      },
    };
  }
  
  /// Create PhonePe payment order
  static Future<Map<String, dynamic>> _createPhonePeOrder(
    String orderId,
    String userId,
    double amount,
    String currency,
    Map<String, dynamic> userData,
  ) async {
    return {
      'orderId': orderId,
      'amount': (amount * 100).toInt(), // PhonePe uses paise
      'currency': currency,
      'merchantUserId': userId,
      'provider': 'phonepe',
      'merchantId': 'TALOWA_PHONEPE', // Should be from environment
      'redirectUrl': 'https://talowa.web.app/payment/success',
      'redirectMode': 'POST',
      'callbackUrl': 'https://talowa.web.app/payment/callback',
      'paymentInstrument': {
        'type': 'PAY_PAGE',
      },
    };
  }
  
  /// Generate unique order ID
  static String _generateOrderId(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userSuffix = userId.length > 6 ? userId.substring(0, 6) : userId;
    return 'TALOWA_${timestamp}_$userSuffix';
  }
  
  /// Record payment initiation
  static Future<void> _recordPaymentInitiation(String userId, Map<String, dynamic> paymentOrder) async {
    try {
      await _firestore.collection('paymentInitiations').add({
        'userId': userId,
        'orderId': paymentOrder['orderId'],
        'amount': paymentOrder['amount'],
        'currency': paymentOrder['currency'],
        'provider': paymentOrder['provider'],
        'status': 'initiated',
        'createdAt': FieldValue.serverTimestamp(),
        'paymentOrder': paymentOrder,
      });
    } catch (e) {
      // Don't fail the main flow for logging errors
      print('Warning: Failed to record payment initiation: $e');
    }
  }
  
  /// Verify payment completion
  static Future<Map<String, dynamic>> verifyPaymentCompletion({
    required String paymentId,
    required String orderId,
    required String provider,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Get payment initiation record
      final initiationQuery = await _firestore
          .collection('paymentInitiations')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      
      if (initiationQuery.docs.isEmpty) {
        throw MembershipPaymentException(
          'Payment initiation not found for order: $orderId',
          'INITIATION_NOT_FOUND',
          {'orderId': orderId}
        );
      }
      
      final initiationData = initiationQuery.docs.first.data();
      final userId = initiationData['userId'];
      
      // Verify payment with provider
      final verificationResult = await _verifyWithProvider(
        paymentId: paymentId,
        orderId: orderId,
        provider: provider,
        additionalData: additionalData,
      );
      
      if (!verificationResult['isValid']) {
        throw MembershipPaymentException(
          'Payment verification failed: ${verificationResult['error']}',
          'VERIFICATION_FAILED',
          {'paymentId': paymentId, 'orderId': orderId}
        );
      }
      
      // Process payment through integration service
      final paymentData = {
        'paymentId': paymentId,
        'userId': userId,
        'amount': verificationResult['amount'],
        'currency': verificationResult['currency'],
        'status': 'completed',
        'provider': provider,
        'orderId': orderId,
        'timestamp': DateTime.now().toIso8601String(),
        'verificationData': verificationResult,
      };
      
      final result = await PaymentIntegrationService.manualPaymentActivation(
        userId: userId,
        paymentId: paymentId,
        amount: verificationResult['amount'],
        currency: verificationResult['currency'],
      );
      
      return {
        'success': true,
        'verified': true,
        'userId': userId,
        'paymentId': paymentId,
        'orderId': orderId,
        'referralsActivated': result['referralsActivated'],
        'rolePromotions': result['rolePromotions'],
      };
      
    } catch (e) {
      await _logPaymentError('verify_payment', e, {
        'paymentId': paymentId,
        'orderId': orderId,
        'provider': provider,
      });
      
      if (e is MembershipPaymentException) {
        rethrow;
      }
      
      throw MembershipPaymentException(
        'Failed to verify payment completion: $e',
        'VERIFICATION_FAILED',
        {'paymentId': paymentId, 'orderId': orderId}
      );
    }
  }
  
  /// Verify payment with provider
  static Future<Map<String, dynamic>> _verifyWithProvider({
    required String paymentId,
    required String orderId,
    required String provider,
    Map<String, dynamic>? additionalData,
  }) async {
    switch (provider.toLowerCase()) {
      case 'razorpay':
        return _verifyRazorpayPayment(paymentId, orderId, additionalData);
      case 'stripe':
        return _verifyStripePayment(paymentId, orderId, additionalData);
      case 'paytm':
        return _verifyPaytmPayment(paymentId, orderId, additionalData);
      case 'phonepe':
        return _verifyPhonePePayment(paymentId, orderId, additionalData);
      default:
        return {
          'isValid': false,
          'error': 'Unsupported provider for verification: $provider',
        };
    }
  }
  
  /// Verify Razorpay payment
  static Future<Map<String, dynamic>> _verifyRazorpayPayment(
    String paymentId,
    String orderId,
    Map<String, dynamic>? additionalData,
  ) async {
    // In a real implementation, this would call Razorpay API
    // For now, return a mock verification
    return {
      'isValid': true,
      'amount': MEMBERSHIP_FEE_INR,
      'currency': DEFAULT_CURRENCY,
      'status': 'captured',
      'provider': 'razorpay',
    };
  }
  
  /// Verify Stripe payment
  static Future<Map<String, dynamic>> _verifyStripePayment(
    String paymentId,
    String orderId,
    Map<String, dynamic>? additionalData,
  ) async {
    // In a real implementation, this would call Stripe API
    return {
      'isValid': true,
      'amount': MEMBERSHIP_FEE_INR,
      'currency': DEFAULT_CURRENCY,
      'status': 'succeeded',
      'provider': 'stripe',
    };
  }
  
  /// Verify Paytm payment
  static Future<Map<String, dynamic>> _verifyPaytmPayment(
    String paymentId,
    String orderId,
    Map<String, dynamic>? additionalData,
  ) async {
    // In a real implementation, this would call Paytm API
    return {
      'isValid': true,
      'amount': MEMBERSHIP_FEE_INR,
      'currency': DEFAULT_CURRENCY,
      'status': 'TXN_SUCCESS',
      'provider': 'paytm',
    };
  }
  
  /// Verify PhonePe payment
  static Future<Map<String, dynamic>> _verifyPhonePePayment(
    String paymentId,
    String orderId,
    Map<String, dynamic>? additionalData,
  ) async {
    // In a real implementation, this would call PhonePe API
    return {
      'isValid': true,
      'amount': MEMBERSHIP_FEE_INR,
      'currency': DEFAULT_CURRENCY,
      'status': 'COMPLETED',
      'provider': 'phonepe',
    };
  }
  
  /// Get membership payment status for user
  static Future<Map<String, dynamic>> getMembershipStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw MembershipPaymentException(
          'User not found: $userId',
          'USER_NOT_FOUND',
          {'userId': userId}
        );
      }
      
      final userData = userDoc.data()!;
      
      return {
        'userId': userId,
        'membershipPaid': userData['membershipPaid'] ?? false,
        'paymentTransactionId': userData['paymentTransactionId'],
        'paymentCompletedAt': userData['paymentCompletedAt'],
        'paymentAmount': userData['paymentAmount'],
        'paymentCurrency': userData['paymentCurrency'],
        'paymentProvider': userData['paymentProvider'],
      };
      
    } catch (e) {
      if (e is MembershipPaymentException) {
        rethrow;
      }
      
      throw MembershipPaymentException(
        'Failed to get membership status: $e',
        'STATUS_RETRIEVAL_FAILED',
        {'userId': userId}
      );
    }
  }
  
  /// Log payment error
  static Future<void> _logPaymentError(String operation, dynamic error, Map<String, dynamic> context) async {
    try {
      await _firestore.collection('membershipPaymentErrors').add({
        'operation': operation,
        'error': error.toString(),
        'context': context,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to log membership payment error: $e');
    }
  }
}
