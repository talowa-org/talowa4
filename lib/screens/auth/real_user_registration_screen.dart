// Real User Registration Screen for TALOWA
// Regional user experience with proper validation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../models/address.dart' as address_model;
import '../../services/auth_policy.dart';
import '../../services/backend.dart';

import '../../services/referral/universal_link_service.dart';
import '../../services/referral/cloud_referral_service.dart';
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

    // Initialize Universal Link Service for this screen
    _initializeReferralCodeHandling();
  }

  Future<void> _initializeReferralCodeHandling() async {
    try {
      // Check for pending referral code from deep link
      final pendingCode = UniversalLinkService.getPendingReferralCode();
      if (pendingCode != null) {
        debugPrint('📋 Auto-filling referral code from deep link: $pendingCode');
        _setReferralCode(pendingCode);
        return;
      }

      // Also check URL directly in case the service missed it
      if (kIsWeb) {
        final currentUrl = Uri.base;
        final urlCode = currentUrl.queryParameters['ref'];
        if (urlCode != null && urlCode.trim().isNotEmpty) {
          final cleanCode = urlCode.trim().toUpperCase();
          debugPrint('📋 Auto-filling referral code from URL: $cleanCode');
          _setReferralCode(cleanCode);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error initializing referral code handling: $e');
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
              const Icon(Icons.link, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Referral code auto-filled: $referralCode'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _setReferralCode(String referralCode) {
    if (mounted) {
      setState(() {
        _referralCodeController.text = referralCode;
      });
      
      // Show user that referral code was auto-filled
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.link, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Referral code auto-filled: $referralCode'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle localizations safely for testing
    AppLocalizations? localizations;
    try {
      localizations = AppLocalizations.of(context);
    } catch (e) {
      debugPrint('Localizations not available: $e');
      // Continue without localizations for testing
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Join TALOWA Movement',
          style: TextStyle(
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
      child: const Column(
        children: [
          Icon(
            Icons.eco,
            size: 48,
            color: AppTheme.talowaGreen,
          ),
          SizedBox(height: 12),
          Text(
            'Welcome to TALOWA',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.talowaGreen,
            ),
          ),
          SizedBox(height: 8),
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
          borderSide: const BorderSide(color: AppTheme.talowaGreen, width: 2),
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
        prefixIcon: const Icon(Icons.location_on, color: AppTheme.talowaGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.talowaGreen, width: 2),
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
            child: const Text(
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
        child: const Text(
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
    // Validate form with null safety
    if (_formKey.currentState?.validate() != true) {
      _showErrorMessage('Please fill in all required fields correctly');
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
      // Validate required fields
      final phoneText = _phoneController.text.trim();
      final pinText = _pinController.text.trim();
      final nameText = _nameController.text.trim();
      final villageText = _villageController.text.trim();
      final mandalText = _mandalController.text.trim();
      final districtText = _districtController.text.trim();

      if (phoneText.isEmpty || pinText.isEmpty || nameText.isEmpty ||
          villageText.isEmpty || mandalText.isEmpty || districtText.isEmpty) {
        _showErrorMessage('Please fill in all required fields');
        return;
      }

      final phoneNumber = normalizePhoneE164(phoneText);
      debugPrint('Starting registration for: $phoneNumber');

      // Check if phone number is already registered using Backend service
      try {
        final phoneExists = await Backend().checkPhoneExists(phoneNumber);
        if (phoneExists) {
          _showErrorMessage('This mobile number is already registered. Please login instead.');
          return;
        }
      } catch (e) {
        debugPrint('Error checking phone registration: $e');
        // Continue with registration if check fails
      }

      // Create address object safely
      final address = address_model.Address(
        villageCity: villageText,
        mandal: mandalText,
        district: districtText,
        state: _selectedState,
      );

      // Get referral code if provided
      final referralCodeText = _referralCodeController.text.trim();
      final referralCode = referralCodeText.isEmpty ? null : referralCodeText;

      debugPrint('Starting Firebase Auth and Backend registration...');

      // Step 1: Create Firebase Auth account with alias email
      final aliasEmail = phoneToAliasEmail(phoneNumber);
      final pinHash = hashPin(pinText);
      
      debugPrint('Creating Firebase Auth user with email: $aliasEmail');
      
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: aliasEmail,
        password: pinHash,
      );

      if (userCredential.user == null) {
        _showErrorMessage('Failed to create user account');
        return;
      }

      debugPrint('Firebase Auth user created with UID: ${userCredential.user!.uid}');

      // Step 2: Write user profile and registry directly with owner permissions
      final uid = userCredential.user!.uid;
      final now = FieldValue.serverTimestamp();
      final db = FirebaseFirestore.instance;

      // Write user profile (without referral code initially - will be added by Cloud Function)
      await db.collection('users').doc(uid).set({
        'fullName': nameText,
        'phone': phoneNumber,
        'phoneE164': phoneNumber, // Ensure Cloud Functions can find phone number
        'email': aliasEmail,
        'active': true,
        'role': 'member',
        'state': _selectedState,
        'district': districtText,
        'mandal': mandalText,
        'village': villageText,
        'createdAt': now,
        'updatedAt': now,
        'membershipPaid': kIsWeb, // Simulate payment on web
        'paymentCompletedAt': kIsWeb ? now : null,
        'paymentTransactionId': kIsWeb ? 'web_simulation_${DateTime.now().millisecondsSinceEpoch}' : null,
      }, SetOptions(merge: true));

      // Write user_registry (without referral code initially - will be added by Cloud Function)
      await db.collection('user_registry').doc(phoneNumber).set({
        'uid': uid,
        'phoneNumber': phoneNumber,
        'email': aliasEmail,
        'fullName': nameText,
        'role': 'member',
        'state': _selectedState,
        'district': districtText,
        'mandal': mandalText,
        'village': villageText,
        'isActive': true,
        'membershipPaid': kIsWeb,
        'createdAt': now,
        'lastLoginAt': now,
        'directReferrals': 0,
        'teamSize': 0,
        'pinHash': pinHash,
      }, SetOptions(merge: true));

      // Step 3: Generate user's own referral code using Cloud Functions
      String? userReferralCode;
      try {
        userReferralCode = await CloudReferralService.reserveReferralCode();
        debugPrint('Generated referral code for user: $userReferralCode');
      } catch (e) {
        debugPrint('Failed to generate referral code: $e');
        // Continue registration even if referral code generation fails
      }

      // Step 4: Apply referral code if provided (non-blocking)
      if (referralCode != null && referralCode.isNotEmpty) {
        try {
          if (CloudReferralService.isValidCodeFormat(referralCode)) {
            final referrerUid = await CloudReferralService.applyReferralCode(referralCode);
            debugPrint('Successfully applied referral code $referralCode, referrer: $referrerUid');
            
            // Show success message for referral
            _showSuccessMessage('Referral code applied successfully!');
          } else {
            debugPrint('Invalid referral code format: $referralCode');
            _showWarningMessage('Invalid referral code format, continuing registration...');
          }
        } catch (e) {
          debugPrint('Failed to apply referral code: $e');
          // Show warning but don't fail registration
          if (e is ReferralException) {
            _showWarningMessage('Referral code issue: ${e.message}');
          } else {
            _showWarningMessage('Could not apply referral code, continuing registration...');
          }
        }
      }

      // Unique phone binding (only if not already bound)
      final phoneRef = db.collection('phones').doc(phoneNumber);
      final phoneSnap = await phoneRef.get();
      if (!phoneSnap.exists) {
        await phoneRef.set({'uid': uid, 'createdAt': now});
      } else if (phoneSnap.data()?['uid'] != uid) {
        throw Exception('This phone is already registered to another account.');
      }

      // Note: user_registry is already created above, no need for separate registries collection

      _showSuccessMessage('Registration successful! Welcome to TALOWA!');

      // Navigate to success screen after a short delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/success',
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Registration error: $e');
      debugPrint('Stack trace: $stackTrace');

      String errorMessage = 'Registration failed. Please try again.';

      // Provide more specific error messages
      if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains('firebase')) {
        errorMessage = 'Service temporarily unavailable. Please try again in a few moments.';
      } else if (e.toString().contains('phone')) {
        errorMessage = 'Invalid phone number format. Please check and try again.';
      }

      _showErrorMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    try {
      if (mounted && context.mounted) {
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        if (scaffoldMessenger != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // Fallback: print to console if ScaffoldMessenger not available
          debugPrint('Success message (no ScaffoldMessenger): $message');
        }
      }
    } catch (e) {
      debugPrint('Failed to show success message: $e');
      debugPrint('Original success message: $message');
    }
  }

  void _showWarningMessage(String message) {
    try {
      if (mounted && context.mounted) {
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        if (scaffoldMessenger != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message)),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          debugPrint('Warning message (no ScaffoldMessenger): $message');
        }
      }
    } catch (e) {
      debugPrint('Failed to show warning message: $e');
      debugPrint('Original warning message: $message');
    }
  }

  void _showErrorMessage(String message) {
    try {
      if (mounted && context.mounted) {
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        if (scaffoldMessenger != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Fallback: print to console if ScaffoldMessenger not available
          debugPrint('Error message (no ScaffoldMessenger): $message');
        }
      }
    } catch (e) {
      debugPrint('Failed to show error message: $e');
      debugPrint('Original error message: $message');
    }
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