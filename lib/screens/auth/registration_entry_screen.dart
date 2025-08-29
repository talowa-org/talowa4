import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/registration_state_service.dart';

import 'registration_flow.dart';
import 'login_screen.dart';

/// Entry screen that checks registration status and directs users appropriately
class RegistrationEntryScreen extends StatefulWidget {
  final String? prefilledReferral;
  
  const RegistrationEntryScreen({super.key, this.prefilledReferral});

  @override
  State<RegistrationEntryScreen> createState() => _RegistrationEntryScreenState();
}

class _RegistrationEntryScreenState extends State<RegistrationEntryScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _statusMessage;
  Color _statusColor = Colors.blue;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkRegistrationStatus() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('Please enter your mobile number', Colors.red);
      return;
    }

    if (phone.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      _showMessage('Please enter a valid 10-digit mobile number', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking registration status...';
      _statusColor = Colors.blue;
    });

    try {
      final registrationStatus = await RegistrationStateService.checkRegistrationStatus(phone);
      
      setState(() {
        _statusMessage = registrationStatus.message;
        _statusColor = registrationStatus.isAlreadyRegistered ? Colors.orange : Colors.green;
      });

      // Wait a moment to show the message
      await Future.delayed(const Duration(milliseconds: 1500));

      if (registrationStatus.isAlreadyRegistered) {
        // Navigate to login screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LoginScreen(prefilledPhone: phone),
            ),
          );
        }
      } else if (registrationStatus.isOtpVerified) {
        // Navigate directly to registration form (skip OTP)
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => RegistrationFlow(
                prefilledReferral: widget.prefilledReferral,
                prefilledPhone: phone,
              ),
            ),
          );
        }
      } else {
        // Navigate to full registration flow (including OTP)
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => RegistrationFlow(
                prefilledReferral: widget.prefilledReferral,
                prefilledPhone: phone,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showMessage('Error checking registration status. Please try again.', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message, Color color) {
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join TALOWA'),
        backgroundColor: Colors.green.shade50,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.green.shade100],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.eco,
                      size: 64,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome to TALOWA',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join the movement for land rights and rural empowerment',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Phone input
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'Enter your 10-digit mobile number',
                  prefixIcon: const Icon(Icons.phone),
                  prefixText: '+91 ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (value) {
                  if (_statusMessage != null) {
                    setState(() {
                      _statusMessage = null;
                    });
                  }
                },
              ),

              const SizedBox(height: 24),

              // Status message
              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusColor == Colors.red
                            ? Icons.error_outline
                            : _statusColor == Colors.orange
                                ? Icons.info_outline
                                : Icons.check_circle_outline,
                        color: _statusColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Continue button
              FilledButton(
                onPressed: _isLoading ? null : _checkRegistrationStatus,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              const SizedBox(height: 32),

              // Info section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Smart Registration',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Already registered? We\'ll take you to login\n'
                      '• Phone verified but registration incomplete? We\'ll skip OTP\n'
                      '• New user? We\'ll guide you through the complete process',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}