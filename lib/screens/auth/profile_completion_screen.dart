import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../services/payment_service.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final String phoneNumber;
  
  const ProfileCompletionScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  
  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _streetController = TextEditingController();
  final _villageCityController = TextEditingController();
  final _mandalController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _referralCodeController = TextEditingController();
  
  DateTime? _selectedDate;
  bool _acceptTerms = false;
  bool _isLoading = false;
  bool _showPaymentDialog = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _houseNoController.dispose();
    _streetController.dispose();
    _villageCityController.dispose();
    _mandalController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _referralCodeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _generateReferralCode(String name) {
    final prefix = name.substring(0, name.length >= 4 ? 4 : name.length)
        .toUpperCase()
        .replaceAll(' ', '');
    final randomPart = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    return '$prefix$randomPart';
  }

  String _generateMemberId() {
    final datePart = DateFormat('yyyyMMdd').format(DateTime.now());
    final randomPart = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    return 'MBR-$datePart-$randomPart';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), // ~18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      _showErrorMessage('You must accept the terms and conditions.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        _showErrorMessage('Authentication error. Please login again.');
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        return;
      }

      final isRootAdmin = AppConfig.isRootAdmin(widget.phoneNumber);
      final newMemberId = _generateMemberId();
      final newReferralCode = _generateReferralCode(_fullNameController.text);

      final userData = {
        'uid': currentUser.uid,
        'memberId': newMemberId,
        'referralCode': newReferralCode,
        'referralLink': AppConfig.generateReferralLink(newReferralCode),
        'referredBy': _referralCodeController.text.isEmpty ? null : _referralCodeController.text,
        'fullName': _fullNameController.text,
        'dob': _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null,
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'phone': widget.phoneNumber,
        'address': {
          'houseNo': _houseNoController.text.isEmpty ? null : _houseNoController.text,
          'street': _streetController.text.isEmpty ? null : _streetController.text,
          'villageCity': _villageCityController.text,
          'mandal': _mandalController.text,
          'district': _districtController.text,
          'state': _stateController.text,
          'pincode': _pincodeController.text.isEmpty ? null : _pincodeController.text,
        },
        'role': isRootAdmin ? 'Root Administrator' : 'Member',
        'currentRoleLevel': isRootAdmin ? 0 : 1,
        'directReferrals': 0,
        'teamReferrals': 0,
        'paymentStatus': isRootAdmin ? 'completed' : 'pending',
        'membershipPaid': isRootAdmin,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save user data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(userData);

      if (mounted) {
        if (isRootAdmin) {
          _showSuccessMessage('Root Admin profile created successfully!');
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else {
          // Show payment dialog for normal users
          setState(() {
            _isLoading = false;
            _showPaymentDialog = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorMessage('Failed to save profile. Please try again.');
      }
    }
  }

  Future<void> _handlePaymentConfirm() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorMessage('Authentication error.');
        return;
      }
      
      final paymentResult = await PaymentService.processMembershipPayment(
        userId: currentUser.uid,
        phoneNumber: widget.phoneNumber,
        amount: AppConfig.membershipFee,
      );
      
      if (paymentResult.success) {
        if (mounted) {
          _showSuccessMessage('Payment successful! Welcome to Talowa.');
          setState(() => _showPaymentDialog = false);
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        if (mounted) {
          _showErrorMessage(paymentResult.message);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Payment failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phone number display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.phone, color: Colors.green.shade600),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verified Mobile Number',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                widget.phoneNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(Icons.verified, color: Colors.green.shade600),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),

                    // Personal Information Section
                    _buildSectionHeader('Personal Information'),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.length < 2) {
                          return 'Full name must be at least 2 characters.';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.grey.shade600),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date of Birth (Optional)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        _selectedDate != null
                                            ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                                            : 'Select date',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: _selectedDate != null ? Colors.black : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _emailController,
                            label: 'Email (Optional)',
                            hint: 'your@email.com',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (!RegExp(AppConfig.emailPattern).hasMatch(value)) {
                                  return 'Please enter a valid email.';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Address Information Section
                    _buildSectionHeader('Address Information'),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _houseNoController,
                            label: 'House No (Optional)',
                            hint: 'House number',
                            icon: Icons.home,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _streetController,
                            label: 'Street (Optional)',
                            hint: 'Street name',
                            icon: Icons.streetview,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _villageCityController,
                            label: 'Village/City',
                            hint: 'Village or city',
                            icon: Icons.location_city,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Village/City is required.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _mandalController,
                            label: 'Mandal',
                            hint: 'Mandal name',
                            icon: Icons.map,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Mandal is required.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _districtController,
                            label: 'District',
                            hint: 'District name',
                            icon: Icons.location_on,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'District is required.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _stateController,
                            label: 'State',
                            hint: 'State name',
                            icon: Icons.public,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'State is required.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _pincodeController,
                      label: 'Pincode (Optional)',
                      hint: '123456',
                      icon: Icons.pin_drop,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 32),

                    // Referral Section
                    _buildSectionHeader('Referral Code (Optional)'),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _referralCodeController,
                      label: 'Referral Code',
                      hint: 'Enter referral code if you have one',
                      icon: Icons.card_giftcard,
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'If you were referred by someone or scanned a QR code, enter the referral code here to give them credit.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Terms and Conditions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (value) {
                            setState(() {
                              _acceptTerms = value ?? false;
                            });
                          },
                          activeColor: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'I accept the terms and conditions',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'By creating an account, you agree to our Terms of Service and Privacy Policy.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.green.shade600],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Complete Registration',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Payment Dialog
          if (_showPaymentDialog)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.payment,
                          size: 48,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Complete Your Registration',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'To complete your registration, please pay the one-time membership fee of ${AppConfig.currency}${AppConfig.membershipFee.toInt()}.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setState(() => _showPaymentDialog = false);
                                },
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handlePaymentConfirm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text('Pay ${AppConfig.currency}${AppConfig.membershipFee.toInt()}'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}