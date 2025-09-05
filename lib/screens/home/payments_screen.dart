import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/payment_service.dart';
import '../../services/razorpay_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
// import '../../services/navigation/navigation_guard_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>> paymentHistory = [];
  bool isLoading = true;
  bool hasCompletedPayment = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentData();
  }

  Future<void> _loadPaymentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.phoneNumber != null) {
        final history = await PaymentService.getPaymentHistory(user!.phoneNumber!);
        final paymentStatus = await PaymentService.hasCompletedPayment(user.phoneNumber!);
        
        if (mounted) {
          setState(() {
            paymentHistory = history;
            hasCompletedPayment = paymentStatus;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payment data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Payments'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildPaymentStatusCard(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildPaymentHistory()),
                ],
              ),
    );
  }

  Widget _buildPaymentStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        color: hasCompletedPayment ? Colors.green.shade50 : Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                hasCompletedPayment ? Icons.check_circle : Icons.info_outline,
                size: 48,
                color: hasCompletedPayment ? Colors.green : Colors.blue,
              ),
              const SizedBox(height: 12),
              Text(
                hasCompletedPayment ? 'Membership Active' : 'Membership Optional',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: hasCompletedPayment ? Colors.green : Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasCompletedPayment
                    ? 'Your membership fee has been paid successfully. Thank you for supporting TALOWA!'
                    : 'Membership payment is optional. You can enjoy all app features regardless of payment status.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              if (!hasCompletedPayment) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _showPaymentDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Support TALOWA (Optional)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    if (paymentHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No payment history found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: paymentHistory.length,
      itemBuilder: (context, index) {
        final payment = paymentHistory[index];
        return _buildPaymentCard(payment);
      },
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final createdAt = payment['createdAt']?.toDate() as DateTime?;
    final amount = payment['amount'] as double?;
    final status = payment['status'] as String?;
    final transactionId = payment['transactionId'] as String?;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status == 'completed' ? Colors.green : Colors.orange,
          child: Icon(
            status == 'completed' ? Icons.check : Icons.pending,
            color: Colors.white,
          ),
        ),
        title: const Text(
          'Membership Fee',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction ID: ${transactionId ?? 'N/A'}'),
            if (createdAt != null)
              Text('Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(createdAt)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${amount?.toInt() ?? 0}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: status == 'completed' ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status?.toUpperCase() ?? 'UNKNOWN',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Support TALOWA'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your support helps us continue our mission to protect land rights and empower communities.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Suggested contribution: ₹100',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This is completely optional. All app features remain free regardless of payment.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processPayment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Support Now'),
            ),
          ],
        );
      },
    );
  }

  void _processPayment() async {
    try {
      // Get current user data
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) _showErrorDialog('Please log in to make a payment.');
        return;
      }

      // Get user data to get phone number and other details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        if (mounted) _showErrorDialog('User profile not found. Please update your profile.');
        return;
      }

      final userData = userDoc.data()!;
      final phoneNumber = userData['phoneNumber'] as String?;
      final fullName = userData['fullName'] as String? ?? 'TALOWA User';
      final email = userData['email'] as String? ?? 'user@talowa.org';

      if (phoneNumber == null) {
        if (mounted) _showErrorDialog('Phone number not found. Please update your profile.');
        return;
      }

      if (kIsWeb) {
        // For web, use the mock payment service
        _processWebPayment(user.uid, phoneNumber);
      } else {
        // For mobile, use Razorpay
        _processRazorpayPayment(phoneNumber, fullName, email);
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Payment initialization failed: ${e.toString()}');
    }
  }

  void _processWebPayment(String userId, String phoneNumber) async {
    // Show loading dialog for web
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Processing payment...'),
            ],
          ),
        );
      },
    );

    try {
      // Process payment using mock PaymentService for web
      final result = await PaymentService.processMembershipPayment(
        userId: userId,
        phoneNumber: phoneNumber,
        amount: 100.0, // ₹100 suggested contribution
      );

      if (mounted) Navigator.of(context).pop(); // Close loading dialog

      if (result.success) {
        if (mounted) _showSuccessDialog(result.transactionId!);
        _loadPaymentData(); // Refresh the payment data
      } else {
        if (mounted) _showErrorDialog(result.message);
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading dialog
      if (mounted) _showErrorDialog('Payment failed: ${e.toString()}');
    }
  }

  void _processRazorpayPayment(String phoneNumber, String fullName, String email) {
    // Initialize Razorpay
    RazorpayService.initialize();

    // Process payment using Razorpay
    RazorpayService.processMembershipPayment(
      context: context,
      phoneNumber: phoneNumber,
      fullName: fullName,
      email: email,
      onSuccess: (PaymentSuccessResponse response) {
        if (mounted) {
          _showSuccessDialog(response.paymentId ?? 'Unknown');
          _loadPaymentData(); // Refresh the payment data
        }
      },
      onError: (PaymentFailureResponse response) {
        if (mounted) {
          _showErrorDialog('Payment failed: ${response.message ?? 'Unknown error'}');
        }
      },
      onExternalWallet: (ExternalWalletResponse response) {
        if (mounted) {
          _showErrorDialog('External wallet payments are not supported yet.');
        }
      },
    );
  }

  void _showSuccessDialog(String transactionId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Payment Successful!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Thank you for supporting TALOWA!'),
              const SizedBox(height: 8),
              Text('Transaction ID: $transactionId'),
              const SizedBox(height: 8),
              const Text(
                'Your contribution helps us protect land rights and empower communities.',
                style: TextStyle(color: Colors.grey),
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
              child: const Text('Great!'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Payment Failed'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

