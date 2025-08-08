import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/hybrid_auth_service.dart';

import 'profile_completion_screen.dart';

enum RegistrationStep { mobile, otp, pin }

class NewRegisterScreen extends StatefulWidget {
  final String? initialMobile;
  
  const NewRegisterScreen({super.key, this.initialMobile});

  @override
  State<NewRegisterScreen> createState() => _NewRegisterScreenState();
}

class _NewRegisterScreenState extends State<NewRegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  
  RegistrationStep _currentStep = RegistrationStep.mobile;
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  String _verificationId = '';
  String _phoneNumber = '';
  
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
    _animationController.dispose();
    super.dispose();
  }

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

      // Send OTP
      await HybridAuthService.verifyPhoneNumber(
        phoneNumber: _phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification completed (Android only)
          _handleOtpVerified();
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            if (e.code == 'phone-verification-failed') {
              // For web or platforms where phone verification isn't available
              _showInfoMessage('Phone verification not available on this platform. You can still create an account with PIN.');
              _moveToNextStep();
            } else {
              _showErrorMessage('Failed to send OTP: ${e.message}');
            }
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _verificationId = verificationId;
            });
            _showSuccessMessage('OTP sent to $_phoneNumber');
            _moveToNextStep();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorMessage('Failed to send OTP. Please try again.');
      }
    }
  }

  Future<void> _handleOtpSubmit() async {
    if (_otpController.text.trim().length != 6) {
      _showErrorMessage('Please enter a valid 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // For demo purposes, accept any 6-digit OTP
      // In production, you would verify against the actual OTP sent via SMS service
      await Future.delayed(const Duration(seconds: 1)); // Simulate verification
      
      _handleOtpVerified();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorMessage('Invalid OTP. Please try again.');
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

  Future<void> _handlePinSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create account with mobile number and PIN
      final result = await HybridAuthService.registerWithMobileAndPin(
        mobileNumber: _mobileController.text.trim(),
        pin: _pinController.text.trim(),
      );

      if (mounted) {
        if (result.success) {
          _showSuccessMessage('Account created successfully!');
          
          // Navigate to profile completion
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileCompletionScreen(
                phoneNumber: _phoneNumber,
              ),
            ),
          );
        } else {
          _showErrorMessage(result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to create account. Please try again.');
      }
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
          break;
      }
    });
    _animationController.reset();
    _animationController.forward();
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
      }
    });
    _animationController.reset();
    _animationController.forward();
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

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep != RegistrationStep.mobile
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.grey.shade700),
                onPressed: _moveToPreviousStep,
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.grey.shade700),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Create Account',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(_slideAnimation),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress Indicator
                  _buildProgressIndicator(),
                  
                  const SizedBox(height: 40),
                  
                  // Step Content
                  _buildStepContent(),
                  
                  const SizedBox(height: 32),
                  
                  // Action Button
                  _buildActionButton(),
                  
                  const SizedBox(height: 24),
                  
                  // Additional Info
                  _buildAdditionalInfo(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        _buildStepIndicator(1, _currentStep.index >= 0, 'Mobile'),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep.index >= 1 ? Colors.green : Colors.grey.shade300,
          ),
        ),
        _buildStepIndicator(2, _currentStep.index >= 1, 'OTP'),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep.index >= 2 ? Colors.green : Colors.grey.shade300,
          ),
        ),
        _buildStepIndicator(3, _currentStep.index >= 2, 'PIN'),
      ],
    );
  }

  Widget _buildStepIndicator(int step, bool isActive, String label) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.green : Colors.grey.shade300,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.green : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
    }
  }

  Widget _buildMobileStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Mobile Number',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll send you an OTP to verify your number',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
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
              hintText: '9876543210',
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
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
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your mobile number';
              }
              if (value.length != 10) {
                return 'Mobile number must be 10 digits';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter OTP',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit code sent to $_phoneNumber',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              hintText: '123456',
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
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {
                _otpController.clear();
                _moveToPreviousStep();
              },
              child: Text(
                'Didn\'t receive OTP? Change number',
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create PIN',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a 6-digit PIN for secure login',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          
          // PIN Field
          TextFormField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: _obscurePin,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Enter PIN',
              hintText: '••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
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
              fillColor: Colors.grey.shade50,
            ),
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
          
          // Confirm PIN Field
          TextFormField(
            controller: _confirmPinController,
            keyboardType: TextInputType.number,
            obscureText: _obscureConfirmPin,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              hintText: '••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPin ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
              ),
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
              fillColor: Colors.grey.shade50,
            ),
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
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    String buttonText;
    VoidCallback? onPressed;

    switch (_currentStep) {
      case RegistrationStep.mobile:
        buttonText = 'Send OTP';
        onPressed = _isLoading ? null : _handleMobileSubmit;
        break;
      case RegistrationStep.otp:
        buttonText = 'Verify OTP';
        onPressed = _isLoading ? null : _handleOtpSubmit;
        break;
      case RegistrationStep.pin:
        buttonText = 'Create Account';
        onPressed = _isLoading ? null : _handlePinSubmit;
        break;
    }

    return Container(
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
        onPressed: onPressed,
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
            : Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.green.shade600,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'Secure Registration',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your mobile number will be verified with OTP. After registration, you can login quickly with just your mobile number and PIN.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }
}