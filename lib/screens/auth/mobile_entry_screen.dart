// Mobile Number Entry Screen for TALOWA
// First step in registration: Enter mobile number and request OTP

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import 'integrated_registration_screen.dart';

class MobileEntryScreen extends StatefulWidget {
  const MobileEntryScreen({super.key});

  @override
  State<MobileEntryScreen> createState() => _MobileEntryScreenState();
}

class _MobileEntryScreenState extends State<MobileEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Remove any non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // If it starts with 91, remove it (we'll add +91 prefix)
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    }

    // If it doesn't start with 91 and is 10 digits, it's a valid Indian number
    if (cleaned.length == 10 && !cleaned.startsWith('0')) {
      return '+91$cleaned';
    }

    return '';
  }

  bool _isValidIndianMobile(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Remove 91 prefix if present
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    }

    // Check if it's a valid 10-digit Indian mobile number
    if (cleaned.length != 10) return false;
    if (cleaned.startsWith('0')) {
      return false; // Indian mobiles don't start with 0
    }

    // Indian mobile numbers start with 6, 7, 8, or 9
    String firstDigit = cleaned.substring(0, 1);
    return ['6', '7', '8', '9'].contains(firstDigit);
  }

  Future<void> _requestOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String phoneNumber = _formatPhoneNumber(_phoneController.text);

      if (phoneNumber.isEmpty) {
        throw Exception('Invalid phone number format');
      }

      // Show OTP dialog immediately and start verification
      _showOtpDialog(phoneNumber);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _showOtpDialog(String phoneNumber) {
    String verificationId = '';
    String otpCode = '';
    bool isVerifying = false;
    String? otpError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start Firebase phone verification
            if (verificationId.isEmpty && !isVerifying) {
              isVerifying = true;
              FirebaseAuth.instance.verifyPhoneNumber(
                phoneNumber: phoneNumber,
                verificationCompleted: (PhoneAuthCredential credential) async {
                  try {
                    await FirebaseAuth.instance.signInWithCredential(
                      credential,
                    );
                    Navigator.of(dialogContext).pop();
                    _navigateToRegistrationForm(phoneNumber);
                  } catch (e) {
                    setDialogState(() {
                      otpError = 'Auto-verification failed: ${e.toString()}';
                    });
                  }
                },
                verificationFailed: (FirebaseAuthException e) {
                  setDialogState(() {
                    otpError = _getFirebaseErrorMessage(e);
                  });
                },
                codeSent: (String vId, int? resendToken) {
                  setDialogState(() {
                    verificationId = vId;
                    otpError = null;
                  });
                },
                codeAutoRetrievalTimeout: (String vId) {
                  // Handle timeout
                },
                timeout: const Duration(seconds: 60),
              );
            }

            return AlertDialog(
              title: const Text('Enter OTP'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('OTP sent to $phoneNumber'),
                  const SizedBox(height: 16),
                  if (verificationId.isEmpty)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Sending OTP...'),
                      ],
                    )
                  else
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Enter 6-digit OTP',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (value) {
                        otpCode = value;
                      },
                    ),
                  if (otpError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        otpError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _isLoading = false;
                    });
                  },
                  child: const Text('Cancel'),
                ),
                if (verificationId.isNotEmpty)
                  ElevatedButton(
                    onPressed: () async {
                      if (otpCode.length == 6) {
                        try {
                          PhoneAuthCredential credential =
                              PhoneAuthProvider.credential(
                                verificationId: verificationId,
                                smsCode: otpCode,
                              );
                          await FirebaseAuth.instance.signInWithCredential(
                            credential,
                          );
                          Navigator.of(dialogContext).pop();
                          _navigateToRegistrationForm(phoneNumber);
                        } catch (e) {
                          setDialogState(() {
                            otpError = 'Invalid OTP. Please try again.';
                          });
                        }
                      } else {
                        setDialogState(() {
                          otpError = 'Please enter a 6-digit OTP';
                        });
                      }
                    },
                    child: const Text('Verify'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      default:
        return 'Verification failed: ${e.message}';
    }
  }

  void _navigateToRegistrationForm(String phoneNumber) {
    setState(() {
      _isLoading = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            IntegratedRegistrationScreen(phoneNumber: phoneNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.talowaGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Join TALOWA',
          style: TextStyle(
            color: AppTheme.talowaGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.talowaGreen.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Header
                  const Text(
                    'Enter Your Mobile Number',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.talowaGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We\'ll send you an OTP to verify your number',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),

                  const SizedBox(height: 40),

                  // Phone Number Input
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      hintText: '9876543210',
                      prefixText: '+91 ',
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: AppTheme.talowaGreen,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.talowaGreen,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.talowaGreen,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your mobile number';
                      }
                      if (!_isValidIndianMobile(value)) {
                        return 'Please enter a valid 10-digit mobile number';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Error Message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // Send OTP Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _requestOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.talowaGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Send OTP',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Terms
                  const Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
