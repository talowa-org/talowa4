import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';

class PaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Process membership payment
  /// In a real implementation, this would integrate with payment gateways like Razorpay, Stripe, etc.
  static Future<PaymentResult> processMembershipPayment({
    required String userId,
    required String phoneNumber,
    required double amount,
  }) async {
    try {
      // Generate transaction ID
      final transactionId = _generateTransactionId();
      
      // In a real implementation, you would:
      // 1. Call payment gateway API (Razorpay, Stripe, etc.)
      // 2. Handle payment gateway response
      // 3. Verify payment status
      
      // For now, we'll simulate payment processing
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call
      
      // Create payment record
      final paymentData = {
        'transactionId': transactionId,
        'userId': userId,
        'phoneNumber': phoneNumber,
        'amount': amount,
        'currency': AppConfig.currency,
        'type': 'membership_fee',
        'status': 'completed', // In real implementation, this comes from payment gateway
        'paymentMethod': 'mock', // In real implementation, this would be actual method
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      };
      
      // Save payment record
      await _firestore
          .collection('payments')
          .doc(transactionId)
          .set(paymentData);
      
      // Update user's payment status
      await _firestore
          .collection('users')
          .doc(phoneNumber)
          .update({
        'paymentStatus': 'completed',
        'membershipPaid': true,
        'paymentTransactionId': transactionId,
        'paymentCompletedAt': FieldValue.serverTimestamp(),
      });
      
      return PaymentResult(
        success: true,
        transactionId: transactionId,
        message: 'Payment completed successfully!',
      );
      
    } catch (e) {
      debugPrint('Payment processing error: $e');
      return PaymentResult(
        success: false,
        message: 'Payment failed. Please try again.',
        error: e.toString(),
      );
    }
  }
  
  /// Check if user has completed payment
  static Future<bool> hasCompletedPayment(String phoneNumber) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(phoneNumber)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['membershipPaid'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking payment status: $e');
      return false;
    }
  }
  
  /// Get payment history for user
  static Future<List<Map<String, dynamic>>> getPaymentHistory(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('payments')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Error fetching payment history: $e');
      return [];
    }
  }
  
  /// Generate unique transaction ID
  static String _generateTransactionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'TXN-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-$random';
  }
}

class PaymentResult {
  final bool success;
  final String? transactionId;
  final String message;
  final String? error;
  
  PaymentResult({
    required this.success,
    this.transactionId,
    required this.message,
    this.error,
  });
}