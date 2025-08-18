// Real User Registration Screen for TALOWA
// Regional user experience with proper validation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

import '../../services/referral/universal_link_service.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../widgets/referral/deep_link_handler.dart';

class RealUserRegistrationScreen extends StatefulWidget {
  const RealUserRegistrationScreen({super.key});

  @override
  State<RealUserRegistrationScreen> createState() => _RealUserRegistrationScreenState();
}

class _RealUserRegistrationScreenState extends State<RealUserRegistrationScreen>
    with ReferralCodeHandler {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _nameController = TextEditingController();
  final _villageController = TextEditingController();
  final _mandalController = TextEditingController();
  final _districtController = TextEditingController();
  final _referralCodeController = TextEditingController();

  String _selectedState = 'Telangana';
  bool _isLoading = false;
  bool _acceptedTerms = false;

  final List<String> _states = [
    'Telangana',
    'Andhra Pradesh',
    'Karnataka',
    'Maharashtra',
    'Tamil Nadu',
    'Kerala',
    'Odisha',
    'Chhattisgarh',
  ];

  final List<String> _telanganDistricts = [
    'Hyderabad',
    'Warangal',
    'Khammam',
    'Nizamabad',
    'Karimnagar',
    'Mahbubnagar',
    'Nalgonda',
    'Adilabad',
    'Medak',
    'Rangareddy',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    // Check for pending referral code from deep link
    final pendingCode = UniversalLinkService.getPendingReferralCode();
    if (pendingCode != null) {
      _setReferralCode(pendingCode);
    }
  }

  @override
  void onReferralCodeReceived(String referralCode) {
    // Handle referral code from deep link
    _setReferralCode(referralCode);

    // Show a snackbar to inform user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.link, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Referral code auto-filled: $referralCode'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _setReferralCode(String referralCode) {
    setState(() {
      _referralCodeController.text = referralCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Join TALOWA Movement',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.talowaGreen,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.talowaGreen.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Message
                  _buildWelcomeSection(),
                  
                  const SizedBox(height: 32),
                  
                  // Personal Information
                  _buildSectionTitle('Personal Information'),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name *',
                    hint: 'Enter your full name',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your full name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Mobile Number *',
                    hint: '9876543210',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your mobile number';
                      }
                      if (value.length != 10) {
                        return 'Mobile number must be 10 digits';
                      }
                      if (!value.startsWith(RegExp(r'[6-9]'))) {
                        return 'Please enter a valid Indian mobile number';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Location Information
                  _buildSectionTitle('Location Information'),
                  const SizedBox(height: 16),
                  
                  _buildDropdownField(
                    value: _selectedState,
                    label: 'State *',
                    items: _states,
                    onChanged: (value) {
                      setState(() {
                        _selectedState = value!;
                        _districtController.clear();
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (_selectedState == 'Telangana')
                    _buildDropdownField(
                      value: _districtController.text.isEmpty ? null : _districtController.text,
                      label: 'District *',
                      items: _telanganDistricts,
                      onChanged: (value) {
                        _districtController.text = value!;
                      },
                    )
                  else
                    _buildTextField(
                      controller: _districtController,
                      label: 'District *',
                      hint: 'Enter your district',
                      icon: Icons.location_city,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your district';
                        }
                        return null;
                      },
                    ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _mandalController,
                    label: 'Mandal/Tehsil *',
                    hint: 'Enter your mandal or tehsil',
                    icon: Icons.location_on,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your mandal/tehsil';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _villageController,
                    label: 'Village/City *',
                    hint: 'Enter your village or city',
                    icon: Icons.home,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your village/city';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Security Information
                  _buildSectionTitle('Security Information'),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _pinController,
                    label: 'Create PIN *',
                    hint: 'Enter 6-digit PIN',
                    icon: Icons.lock,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please create a PIN';
                      }
                      if (value.length != 6) {
                        return 'PIN must be exactly 6 digits';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _confirmPinController,
                    label: 'Confirm PIN *',
                    hint: 'Re-enter your PIN',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your PIN';
                      }
                      if (value != _pinController.text) {
                        return 'PINs do not match';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Referral Information (Optional)
                  _buildSectionTitle('Referral Information (Optional)'),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _referralCodeController,
                    label: 'Referral Code',
                    hint: 'Enter referral code if you have one',
                    icon: Icons.people,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Terms and Conditions
                  _buildTermsCheckbox(),
                  
                  const SizedBox(height: 32),
                  
                  // Register Button
                  _buildRegisterButton(),
                  
                  const SizedBox(height: 16),
                  
                  // Login Link
                  _buildLoginLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.talowaGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.talowaGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.eco,
            size: 48,
            color: AppTheme.talowaGreen,
          ),
          const SizedBox(height: 12),
          Text(
            'Welcome to TALOWA',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.talowaGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join the movement for land rights and rural empowerment',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryText,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.talowaGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.talowaGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.location_on, color: AppTheme.talowaGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.talowaGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select $label';
        }
        return null;
      },
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _acceptedTerms,
          onChanged: (value) {
            setState(() {
              _acceptedTerms = value ?? false;
            });
          },
          activeColor: AppTheme.talowaGreen,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _acceptedTerms = !_acceptedTerms;
              });
            },
            child: Text(
              'I agree to the Terms of Service and Privacy Policy of TALOWA. I understand that this app is for land rights activism and I will use it responsibly.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading || !_acceptedTerms ? null : _handleRegistration,
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
            : const Text(
                'Join TALOWA Movement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: Text(
          'Already have an account? Login here',
          style: TextStyle(
            color: AppTheme.talowaGreen,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptedTerms) {
      _showErrorMessage('Please accept the terms and conditions');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final phoneNumber = '+91${_phoneController.text.trim()}';

      // Check if phone number is already registered
      final isRegistered = await DatabaseService.isPhoneRegistered(phoneNumber);
      if (isRegistered) {
        _showErrorMessage('This mobile number is already registered. Please login instead.');
        return;
      }

      // Step 1: Create Firebase Auth user (OTP verification would happen before this)
      final pin = _pinController.text.trim();

      final authResult = await AuthService.registerUser(
        phoneNumber: phoneNumber,
        pin: pin,
        fullName: _nameController.text.trim(),
        address: Address(
          villageCity: _villageController.text.trim(),
          mandal: _mandalController.text.trim(),
          district: _districtController.text.trim(),
          state: _selectedState,
        ),
        referralCode: _referralCodeController.text.trim().isEmpty
            ? null
            : _referralCodeController.text.trim(),
      );

      if (!authResult.success) {
        _showErrorMessage(authResult.message);
        return;
      }

      // AuthService now handles user profile creation internally with TAL referral codes
      final userProfile = authResult.user;
      if (userProfile == null) {
        _showErrorMessage('Failed to create user profile');
        return;
      }

      final referralCode = userProfile.referralCode;
      _showSuccessMessage('Registration successful! Your referral code: $referralCode');

      // Navigate to main app after a short delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main',
          (route) => false,
        );
      }
    } catch (e) {
      _showErrorMessage('Registration failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _nameController.dispose();
    _villageController.dispose();
    _mandalController.dispose();
    _districtController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }
}