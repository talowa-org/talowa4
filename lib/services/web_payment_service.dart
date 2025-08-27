import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Web Payment Service for TALOWA
/// Provides fallback payment flow for web users since razorpay_flutter doesn't work on web
class WebPaymentService {
  /// Check if running on web
  static bool get isWeb => kIsWeb;
  
  /// Simulate payment success for web users (development)
  static Future<bool> simulatePaymentSuccess({
    required String phoneNumber,
    required String amount,
    required BuildContext context,
  }) async {
    if (!isWeb) {
      throw UnsupportedError('This method is only for web platform');
    }
    
    // Show payment simulation dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment Simulation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.payment,
                size: 48,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              Text('Phone: $phoneNumber'),
              Text('Amount: ₹$amount'),
              const SizedBox(height: 16),
              const Text(
                'This is a payment simulation for web development.\n'
                'In production, this will integrate with Razorpay Checkout.js.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Simulate Success'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }
  
  /// Show payment failure dialog
  static Future<void> showPaymentFailure({
    required BuildContext context,
    String? errorMessage,
  }) async {
    if (!isWeb) return;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(errorMessage ?? 'Payment failed. Please try again.'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  /// Show payment success dialog
  static Future<void> showPaymentSuccess({
    required BuildContext context,
    required String phoneNumber,
    required String amount,
  }) async {
    if (!isWeb) return;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment Successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                size: 48,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text('Phone: $phoneNumber'),
              Text('Amount: ₹$amount'),
              const SizedBox(height: 16),
              const Text(
                'Your payment was successful!\n'
                'Your TALOWA membership is now active.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }
}
