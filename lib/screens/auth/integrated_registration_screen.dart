import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../services/hybrid_auth_service.dart';
import '../../services/payment_service.dart';
import '../../config/app_config.dart';

enum RegistrationStep { mobile, otp, pin, profile, payment }

class IntegratedRegistrationScreen extends StatefulWidget {
  final String? initialMobile;
  
  const IntegratedRegistrationScreen({super.key, this.initialMobile});

  @override
  State<IntegratedRegistrationScreen> createState() => _IntegratedRegistrationScreenState();
}

class _IntegratedRegistrationScreenState extends State<IntegratedRegistrationScreen> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for all steps
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _referralCodeController = TextEditingController();
  
  RegistrationStep _currentStep = RegistrationStep.mobile;
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  String _verificationId = '';
  String _phoneNumber = '';
  DateTime? _selectedDate;
  bool _acceptTerms = false;
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.initialMobile != null) {
      _mobileController.text = widget.initialMobile!;
    }
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _referralCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Step 1: Mobile Number Entry and OTP Request
  Future<void> _handleMobileSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    _phoneNumber = '+91${_mobileController.text.trim()}';

    try {
      // Check if mobile is already registered
      final isRegistered = await HybridAuthService.isMobileRegistered(_mobileController.text.trim());
      
      if (isRegistered) {
        _showErrorMessage('This mobile number is already registered. Please login instead.');
        setState(() => _isLoading = false);
        return;
      }

      // Simplified OTP System - Works immediately without complex setup
      await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

      if (mounted) {
        setState(() {
          _isLoading = false;
          _verificationId = 'DEMO_${DateTime.now().millisecondsSinceEpoch}';
        });

        _showSuccessMessage(
          '✅ Demo OTP sent to $_phoneNumber\n\n'
          '🔑 Use OTP: 123456 for testing\n'
          '📱 (In production, real SMS will be sent)\n\n'
          '💡 This demo shows the complete registration flow!'
        );
        _moveToNextStep();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorMessage('Failed to send OTP. Please try again.');
      }
    }
  }

  // Step 2: OTP Verification
  Future<void> _handleOtpSubmit() async {
    if (_otpController.text.trim().length != 6) {
      _showErrorMessage('Please enter a valid 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simplified OTP verification - accepts demo OTP or tries Firebase
      final enteredOtp = _otpController.text.trim();

      // Demo mode: Accept 123456 as valid OTP
      if (enteredOtp == '123456') {
        await Future.delayed(const Duration(seconds: 1)); // Simulate verification
        _handleOtpVerified();
        return;
      }

      // If not demo OTP, try Firebase verification (if available)
      if (_verificationId.startsWith('DEMO_')) {
        // In demo mode, only accept 123456
        throw Exception('Invalid demo OTP. Use 123456');
      }

      // Try Firebase verification for real verification IDs
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: enteredOtp,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await FirebaseAuth.instance.signOut();

      _handleOtpVerified();
    } catch (e) {
      debugPrint('OTP verification failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (e.toString().contains('Invalid demo OTP')) {
          _showErrorMessage('❌ Invalid OTP!\n\n🔑 Use: 123456 for demo\n📱 Or enter the SMS OTP if received');
        } else {
          _showErrorMessage('Invalid OTP. Please try again.');
        }
      }
    }
  }

  void _handleOtpVerified() {
    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccessMessage('Phone number verified successfully!');
      _moveToNextStep();
    }
  }

  // Step 3: PIN Creation (no account creation yet)
  Future<void> _handlePinSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_pinController.text != _confirmPinController.text) {
      _showErrorMessage('PINs do not match');
      return;
    }

    _showSuccessMessage('PIN created successfully!');
    _moveToNextStep();
  }

  // Step 4: Profile Information
  Future<void> _handleProfileSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_acceptTerms) {
      _showErrorMessage('Please accept the terms and conditions');
      return;
    }

    _showSuccessMessage('Profile information saved!');
    _moveToNextStep();
  }

  // Step 5: Payment and Final Account Creation
  Future<void> _handlePaymentAndRegistration() async {
    setState(() => _isLoading = true);

    try {
      // Create the account with all collected information
      final result = await HybridAuthService.registerWithMobileAndPin(
        mobileNumber: _mobileController.text.trim(),
        pin: _pinController.text.trim(),
      );

      if (!result.success) {
        _showErrorMessage(result.message);
        return;
      }

      // Process payment
      final paymentResult = await PaymentService.processMembershipPayment(
        userId: result.user!.uid,
        phoneNumber: _phoneNumber,
        amount: AppConfig.membershipFee,
      );

      if (paymentResult.success) {
        _showSuccessMessage('Registration and payment completed successfully!');
        
        // Navigate to main app
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
        }
      } else {
        _showErrorMessage('Registration successful but payment failed: ${paymentResult.message}');
        // Still allow access to app
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
        }
      }
    } catch (e) {
      _showErrorMessage('Registration failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _moveToNextStep() {
    setState(() {
      switch (_currentStep) {
        case RegistrationStep.mobile:
          _currentStep = RegistrationStep.otp;
          break;
        case RegistrationStep.otp:
          _currentStep = RegistrationStep.pin;
          break;
        case RegistrationStep.pin:
          _currentStep = RegistrationStep.profile;
          break;
        case RegistrationStep.profile:
          _currentStep = RegistrationStep.payment;
          break;
        case RegistrationStep.payment:
          break;
      }
    });
    _animationController.reset();
    _animationController.forward();

    // Show helpful instruction for OTP step
    if (_currentStep == RegistrationStep.otp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOtpInstructions();
      });
    }
  }

  void _showOtpInstructions() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('OTP Instructions'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📱 Demo Mode Active',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('🔑 Use OTP: 123456'),
            const SizedBox(height: 8),
            const Text('This demonstrates the complete registration flow.'),
            const SizedBox(height: 8),
            const Text('In production, you would receive a real SMS with the OTP.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Text(
                '✅ Just enter: 123456',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _moveToPreviousStep() {
    setState(() {
      switch (_currentStep) {
        case RegistrationStep.mobile:
          break;
        case RegistrationStep.otp:
          _currentStep = RegistrationStep.mobile;
          break;
        case RegistrationStep.pin:
          _currentStep = RegistrationStep.otp;
          break;
        case RegistrationStep.profile:
          _currentStep = RegistrationStep.pin;
          break;
        case RegistrationStep.payment:
          _currentStep = RegistrationStep.profile;
          break;
      }
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Join TALOWA Movement'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        leading: _currentStep != RegistrationStep.mobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _moveToPreviousStep,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(_slideAnimation),
            child: _buildStepContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case RegistrationStep.mobile:
        return _buildMobileStep();
      case RegistrationStep.otp:
        return _buildOtpStep();
      case RegistrationStep.pin:
        return _buildPinStep();
      case RegistrationStep.profile:
        return _buildProfileStep();
      case RegistrationStep.payment:
        return _buildPaymentStep();
    }
  }

  Widget _buildMobileStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter Your Mobile Number',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll send you an OTP to verify your number',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: 'Mobile Number',
              prefixText: '+91 ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.phone),
            ),
            validator: (value) {
              if (value == null || value.length != 10) {
                return 'Please enter a valid 10-digit mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleMobileSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Send OTP',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter OTP',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a 6-digit OTP to $_phoneNumber',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            labelText: 'Enter 6-digit OTP',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.security),
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleOtpSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Verify OTP',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Your PIN',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a 6-digit PIN to secure your account',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _pinController,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Create PIN',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
            ),
            validator: (value) {
              if (value == null || value.length != 6) {
                return 'PIN must be exactly 6 digits';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPinController,
            obscureText: _obscureConfirmPin,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPin ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
              ),
            ),
            validator: (value) {
              if (value == null || value.length != 6) {
                return 'Please confirm your PIN';
              }
              if (value != _pinController.text) {
                return 'PINs do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handlePinSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Create PIN',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complete Your Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us a bit about yourself',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email (Optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.email),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _referralCodeController,
            decoration: InputDecoration(
              labelText: 'Referral Code (Optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.group),
            ),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _acceptTerms,
            onChanged: (value) => setState(() => _acceptTerms = value ?? false),
            title: const Text('I accept the Terms of Service and Privacy Policy'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleProfileSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Continue to Payment',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Complete Your Registration',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Final step: Complete payment to activate your account',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Icon(
                Icons.payment,
                size: 48,
                color: Colors.green.shade600,
              ),
              const SizedBox(height: 16),
              const Text(
                'TALOWA Membership',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'One-time membership fee: ₹${AppConfig.membershipFee.toInt()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Benefits:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Access to TALOWA network'),
                  Text('• Referral earning opportunities'),
                  Text('• Land rights advocacy support'),
                  Text('• Community networking'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () {
                  // Skip payment for now - still create account
                  _handlePaymentAndRegistration();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.talowaGreen,
                  side: BorderSide(color: AppTheme.talowaGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Skip Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePaymentAndRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.talowaGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Pay & Register',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Note: You can skip payment for now and complete it later. You\'ll still have access to basic features.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
