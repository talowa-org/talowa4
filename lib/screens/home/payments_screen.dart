import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/payment_service.dart';
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
}