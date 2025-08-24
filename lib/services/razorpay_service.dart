import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RazorpayService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static late Razorpay _razorpay;
  static Function(PaymentSuccessResponse)? _onSuccess;
  static Function(PaymentFailureResponse)? _onError;
  static Function(ExternalWalletResponse)? _onExternalWallet;

  /// Initialize Razorpay
  static void initialize() {
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  /// Dispose Razorpay
  static void dispose() {
    if (!kIsWeb) {
      _razorpay.clear();
    }
  }

  /// Process membership payment
  static Future<void> processMembershipPayment({
    required BuildContext context,
    required String phoneNumber,
    required String fullName,
    required String email,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    Function(ExternalWalletResponse)? onExternalWallet,
  }) async {
    if (kIsWeb) {
      // For web, show a message that payment is not supported
      _showWebPaymentDialog(context);
      return;
    }

    _onSuccess = onSuccess;
    _onError = onError;
    _onExternalWallet = onExternalWallet;

    final options = {
      'key': 'rzp_test_1DP5mmOlF5G5ag', // Replace with your Razorpay key
      'amount': 10000, // ₹100 in paise
      'name': 'TALOWA',
      'description': 'Membership Fee',
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {
        'contact': phoneNumber,
        'email': email,
      },
      'external': {
        'wallets': ['paytm']
      },
      'theme': {
        'color': '#4CAF50'
      },
      'notes': {
        'phoneNumber': phoneNumber,
        'fullName': fullName,
        'purpose': 'membership_fee'
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      onError(PaymentFailureResponse(
        1, // Generic error code
        'Failed to open payment gateway',
        null,
      ));
    }
  }

  static void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Payment Success: ${response.paymentId}');
    _savePaymentRecord(response);
    _onSuccess?.call(response);
  }

  static void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error: ${response.code} - ${response.message}');
    _onError?.call(response);
  }

  static void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet: ${response.walletName}');
    _onExternalWallet?.call(response);
  }

  /// Save payment record to Firestore
  static Future<void> _savePaymentRecord(PaymentSuccessResponse response) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final paymentData = {
        'paymentId': response.paymentId,
        'orderId': response.orderId,
        'signature': response.signature,
        'userId': user.uid,
        'phoneNumber': user.phoneNumber,
        'amount': 100.0,
        'currency': 'INR',
        'status': 'completed',
        'provider': 'razorpay',
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      };

      // Save to payments collection
      await _firestore
          .collection('payments')
          .doc(response.paymentId)
          .set(paymentData);

      // Update user's membership status
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'membershipPaid': true,
        'paymentTransactionId': response.paymentId,
        'paymentCompletedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      debugPrint('Payment record saved successfully');
    } catch (e) {
      debugPrint('Error saving payment record: $e');
    }
  }

  /// Show web payment dialog (since Razorpay doesn't work on web)
  static void _showWebPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info, size: 48, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Payment integration is available on mobile app only.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'For now, your registration is complete. Payment can be done later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Simulate successful payment for web
              _simulateWebPayment(context);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// Simulate payment for web platform
  static void _simulateWebPayment(BuildContext context) {
    // For web, we'll just mark the payment as completed
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firestore.collection('users').doc(user.uid).update({
        'membershipPaid': true,
        'paymentTransactionId': 'web_simulation_${DateTime.now().millisecondsSinceEpoch}',
        'paymentCompletedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    }
  }
}

/// Payment result class
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
