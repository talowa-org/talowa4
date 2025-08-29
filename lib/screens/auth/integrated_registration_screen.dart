// Real User Registration Screen for TALOWA
// Regional user experience with proper validation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_model.dart';

import '../../services/database_service.dart';
import '../../services/referral/referral_code_generator.dart';
import '../../services/auth_policy.dart';
// Removed payment_screen.dart import - using inline payment simulation

import '../../services/referral/universal_link_service.dart';

class IntegratedRegistrationScreen extends StatefulWidget {
  final String? phoneNumber;

  const IntegratedRegistrationScreen({super.key, this.phoneNumber});

  @override
  State<IntegratedRegistrationScreen> createState() =>
      _IntegratedRegistrationScreenState();
}

class _IntegratedRegistrationScreenState
    extends State<IntegratedRegistrationScreen> {
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

    // Pre-fill phone number if provided
    if (widget.phoneNumber != null) {
      String cleanPhone = widget.phoneNumber!.replaceAll('+91', '');
      _phoneController.text = cleanPhone;
    }

    // Initialize referral code handling
    _initializeReferralCodeHandling();
  }

  Future<void> _initializeReferralCodeHandling() async {
    try {
      // Check for pending referral code from deep link (don't consume it yet)
      final pendingCode = UniversalLinkService.getPendingReferralCode();
      if (pendingCode != null) {
        debugPrint('📋 Auto-filling referral code from deep link: $pendingCode');
        _setReferralCode(pendingCode);
        // Clear the pending code since we've used it
        UniversalLinkService.clearPendingReferralCode();
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
              Expanded(child: Text('Referral code auto-filled: $referralCode')),
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
            colors: [AppTheme.talowaGreen.withOpacity(0.1), Colors.white],
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
                    label: widget.phoneNumber != null
                        ? 'Mobile Number * (Verified)'
                        : 'Mobile Number *',
                    hint: '9876543210',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    readOnly: widget.phoneNumber != null,
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

                  const SizedBox(height: 16),

                  // PIN Fields
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
                        return 'Please enter a PIN';
                      }
                      if (value.length != 6) {
                        return 'PIN must be 6 digits';
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
                      value: _districtController.text.isEmpty
                          ? null
                          : _districtController.text,
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
          Icon(Icons.eco, size: 48, color: AppTheme.talowaGreen),
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
            style: TextStyle(fontSize: 16, color: AppTheme.secondaryText),
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
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      obscureText: obscureText,
      readOnly: readOnly,
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
        return DropdownMenuItem<String>(value: item, child: Text(item));
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
              style: TextStyle(fontSize: 14, color: AppTheme.secondaryText),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

    // If phone number is already verified (came from mobile entry screen), skip verification
    if (widget.phoneNumber != null) {
      await _completeRegistration();
    } else {
      // Start phone verification process for direct registration
      await _startPhoneVerification();
    }
  }

  String _verificationId = '';
  final _otpController = TextEditingController();

  Future<void> _startPhoneVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final phoneText = _phoneController.text.trim();
      final phoneNumber = '+91$phoneText';

      debugPrint('Starting phone verification for: $phoneNumber');

      // Check if phone number is already registered
      final isRegistered = await DatabaseService.isPhoneRegistered(phoneNumber);
      if (isRegistered) {
        _showErrorMessage(
          'This mobile number is already registered. Please login instead.',
        );
        return;
      }

      // Start Firebase phone verification
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed (Android only)
          debugPrint('Phone verification completed automatically');
          await _completeRegistrationWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Phone verification failed: ${e.code} - ${e.message}');
          setState(() => _isLoading = false);

          String errorMessage = 'Phone verification failed. Please try again.';
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'Invalid phone number format.';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many requests. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            errorMessage = 'SMS quota exceeded. Please try again later.';
          }

          _showErrorMessage(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('OTP sent successfully. Verification ID: $verificationId');
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
          _showOtpDialog();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint(
            'Code auto-retrieval timeout. Verification ID: $verificationId',
          );
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint('Error starting phone verification: $e');
      setState(() => _isLoading = false);
      _showErrorMessage('Failed to send OTP. Please try again.');
    }
  }

  void _showOtpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Phone Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the 6-digit OTP sent to +91${_phoneController.text}'),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isLoading = false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(onPressed: _verifyOtp, child: const Text('Verify')),
        ],
      ),
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showErrorMessage('Please enter a valid 6-digit OTP');
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );

      Navigator.of(context).pop(); // Close OTP dialog
      await _completeRegistrationWithCredential(credential);
    } catch (e) {
      debugPrint('OTP verification failed: $e');
      _showErrorMessage('Invalid OTP. Please try again.');
    }
  }

  Future<void> _completeRegistration() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showErrorMessage('User not authenticated');
        return;
      }

      await _createUserProfile(user);
    } catch (e) {
      debugPrint('Registration failed: $e');
      _showErrorMessage('Registration failed: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRegistrationWithCredential(
    PhoneAuthCredential credential,
  ) async {
    setState(() => _isLoading = true);

    try {
      // Sign in with phone credential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user == null) {
        _showErrorMessage('Failed to verify phone number');
        return;
      }

      await _createUserProfile(user);
    } catch (e) {
      debugPrint('Registration failed: $e');
      _showErrorMessage('Registration failed: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createUserProfile(User user) async {
    try {
      // Collect form data
      final nameText = _nameController.text.trim();
      final phoneText = _phoneController.text.trim();
      final pinText = _pinController.text.trim();

      final phoneNumber = '+91$phoneText';

      // Get referral code if provided
      final referralCodeText = _referralCodeController.text.trim();
      final referralCode = referralCodeText.isEmpty ? null : referralCodeText;

      // Get current Firebase Auth user (created during phone verification)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user found');
        _showErrorMessage('Authentication error. Please restart registration.');
        // Navigate back to mobile entry
        Navigator.pushReplacementNamed(context, '/mobile-entry');
        return;
      }
      debugPrint('✅ Found authenticated user: ${currentUser.uid}');

      // Create email/password credentials for login compatibility
      final fakeEmail = '$phoneNumber@talowa.app';
      final hashedPin = passwordFromPin(pinText); // Use consistent PIN hashing

      try {
        // Link email/password to the existing phone auth user
        final emailCredential = EmailAuthProvider.credential(
          email: fakeEmail,
          password: hashedPin,
        );

        await currentUser.linkWithCredential(emailCredential);
        debugPrint(
          '✅ Email/password credentials linked for login compatibility',
        );
      } catch (e) {
        debugPrint('⚠️ Could not link email/password credentials: $e');
        // Continue with registration - PIN will be stored in Firestore
      }

      // Create user profile and registry for the existing Firebase Auth user
      final userAddress = Address(
        state: _selectedState,
        district: _districtController.text.trim(),
        mandal: _mandalController.text.trim(),
        villageCity: _villageController.text.trim(),
      );

      // Generate referral code with error handling
      String newReferralCode;
      try {
        newReferralCode = await ReferralCodeGenerator.generateUniqueCode();
        debugPrint('✅ Generated referral code: $newReferralCode');
      } catch (e) {
        debugPrint('⚠️ Referral code generation failed: $e');
        // Fallback to a simple unique code
        newReferralCode =
            'TAL${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        debugPrint('🔄 Using fallback referral code: $newReferralCode');
      }

      // Create user profile directly with error handling
      try {
        await DatabaseService.createUserProfile(
          UserModel(
            id: currentUser.uid,
            fullName: nameText,
            email: '$phoneNumber@talowa.app',
            phoneNumber: phoneNumber,
            role: AppConstants.roleMember,
            memberId: 'TAL${DateTime.now().millisecondsSinceEpoch}',
            referralCode: newReferralCode,
            referredBy: referralCode,
            address: userAddress,
            directReferrals: 0,
            teamSize: 0,
            teamReferrals: 0, // New field for BSS compatibility
            currentRoleLevel: 1, // Start as Member (level 1)
            membershipPaid: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            preferences: UserPreferences.defaultPreferences(),
            pinHash: hashedPin, // Store PIN hash for authentication
          ),
        );
        debugPrint('✅ User profile created successfully');
      } catch (e) {
        debugPrint('⚠️ User profile creation failed: $e');
        _showErrorMessage('Failed to create user profile: $e');
        return;
      }

      // Create user registry entry with error handling
      try {
        await DatabaseService.createUserRegistry(
          phoneNumber: phoneNumber,
          uid: currentUser.uid,
          email: '$phoneNumber@talowa.app',
          role: AppConstants.roleMember,
          state: _selectedState,
          district: _districtController.text.trim(),
          mandal: _mandalController.text.trim(),
          village: _villageController.text.trim(),
          pinHash: hashedPin, // Pass PIN hash for login verification
          referralCode: newReferralCode, // Pass the already generated referral code
        );
        debugPrint('✅ User registry created successfully');
      } catch (e) {
        debugPrint('⚠️ User registry creation failed: $e');
        // Don't return here as profile is already created
      }

      // Get the created user profile
      final userProfile = await DatabaseService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        _showErrorMessage('Failed to create user profile');
        return;
      }

      final finalReferralCode = userProfile.referralCode;
      _showSuccessMessage(
        'Registration successful! Your referral code: $finalReferralCode',
      );

      // Navigate to payment screen after a short delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        try {
          // Payment simulation for web - direct navigation to main app
          _showPaymentSimulationDialog(context);
        } catch (e) {
          debugPrint('⚠️ Payment screen navigation failed: $e');
          // Fallback: Navigate directly to main app
          Navigator.pushReplacementNamed(context, '/main');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Registration error: $e');
      debugPrint('Stack trace: $stackTrace');

      String errorMessage = 'Registration failed. Please try again.';

      // Provide more specific error messages
      if (e.toString().contains('network')) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains('firebase')) {
        errorMessage =
            'Service temporarily unavailable. Please try again in a few moments.';
      } else if (e.toString().contains('phone')) {
        errorMessage =
            'Invalid phone number format. Please check and try again.';
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

  void _showPaymentSimulationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment Simulation'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payment, size: 48, color: Colors.green),
              SizedBox(height: 16),
              Text('Payment simulation for web development'),
              Text('Registration completed successfully!'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/main');
              },
              child: const Text('Continue to App'),
            ),
          ],
        );
      },
    );
  }
}
