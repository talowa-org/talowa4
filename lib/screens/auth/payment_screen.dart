import 'dart:async';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../services/razorpay_service.dart';
import '../../core/theme/app_theme.dart';

class PaymentScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final String email;
  final String referralCode;

  const PaymentScreen({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    required this.email,
    required this.referralCode,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    try {
      RazorpayService.initialize();
    } catch (e) {
      debugPrint('Razorpay initialization error: $e');
    }
  }

  @override
  void dispose() {
    RazorpayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Registration'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 60,
                  color: Colors.green.shade600,
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                'Registration Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Referral Code (only show if not empty)
              if (widget.referralCode.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Referral Code',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.referralCode,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Payment Info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.payment, size: 48, color: Colors.blue.shade600),
                    const SizedBox(height: 16),
                    const Text(
                      'Complete Your Membership',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To activate your TALOWA membership and access all features, please complete the one-time payment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '₹100',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'One-time fee',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Payment Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handlePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.talowaGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Pay ₹100 & Activate',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Skip Button
              Container(
                width: double.infinity,
                height: 48,
                margin: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _skipPayment,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Skip Payment (Continue to App)',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePayment() {
    setState(() => _isLoading = true);

    try {
      debugPrint('🔄 Initializing payment for ${widget.phoneNumber}');

      // Add timeout to prevent infinite loading
      Timer(const Duration(seconds: 30), () {
        if (_isLoading && mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog('Payment timeout. Please try again.');
        }
      });

      RazorpayService.processMembershipPayment(
        context: context,
        phoneNumber: widget.phoneNumber,
        fullName: widget.fullName,
        email: widget.email,
        onSuccess: _onPaymentSuccess,
        onError: _onPaymentError,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('❌ Payment initialization error: $e');
      _showErrorDialog('Failed to initialize payment. Please try again.');
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    setState(() => _isLoading = false);

    debugPrint('✅ Payment successful: ${response.paymentId}');
    _showSuccessDialog();
  }

  void _onPaymentError(PaymentFailureResponse response) {
    setState(() => _isLoading = false);

    debugPrint('❌ Payment failed: ${response.code} - ${response.message}');
    _showErrorDialog(response.message ?? 'Payment failed. Please try again.');
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Successful!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Welcome to TALOWA! Your membership is now active.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToMain();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _skipPayment() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Payment?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You can complete the payment later from your profile.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Note: Some features may be limited until payment is completed.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              debugPrint('User skipped payment, navigating to main app');
              _navigateToMain();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue to App'),
          ),
        ],
      ),
    );
  }

  void _navigateToMain() {
    try {
      debugPrint('🚀 Navigating to main app...');
      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      debugPrint('✅ Navigation to main app completed');
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      // Fallback navigation
      try {
        Navigator.pushReplacementNamed(context, '/welcome');
        debugPrint('🔄 Fallback navigation to welcome completed');
      } catch (fallbackError) {
        debugPrint('❌ Fallback navigation failed: $fallbackError');
        // Last resort: reload the page
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please refresh the page to continue'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }
}
