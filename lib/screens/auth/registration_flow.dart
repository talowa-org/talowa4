import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../services/auth_policy.dart';
import '../../services/registration_state_service.dart';

enum StepStage { phone, otp, form, paying, done }

class RegistrationFlow extends StatefulWidget {
  final String? prefilledReferral;
  final String? prefilledPhone;
  
  const RegistrationFlow({super.key, this.prefilledReferral, this.prefilledPhone});

  @override
  State<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends State<RegistrationFlow> {
  StepStage stage = StepStage.phone;
  bool busy = false;
  bool termsAccepted = false;

  // phone + otp
  final phoneCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  String? _verificationId;

  // form
  final nameCtrl = TextEditingController();
  final villageCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  final pin2Ctrl = TextEditingController();
  final referralCtrl = TextEditingController();

  // simple cascading demo lists (replace with real data as needed)
  String? stateVal = 'Telangana';
  String? districtVal;
  String? mandalVal;

  final List<String> states = ['Telangana', 'Andhra Pradesh'];
  final Map<String, List<String>> districtsByState = {
    'Telangana': ['Hyderabad', 'Rangareddy', 'Nalgonda'],
    'Andhra Pradesh': ['Guntur', 'Krishna', 'Visakhapatnam'],
  };
  final Map<String, List<String>> mandalsByDistrict = {
    'Hyderabad': ['Shaikpet', 'Ameerpet', 'Serilingampally'],
    'Rangareddy': ['Ibrahimpatnam', 'Hayathnagar'],
    'Nalgonda': ['Nalgonda', 'Chityal'],
    'Guntur': ['Guntur East', 'Guntur West'],
    'Krishna': ['Vijayawada North', 'Machilipatnam'],
    'Visakhapatnam': ['Bheemunipatnam', 'Anandapuram'],
  };

  Razorpay? _razorpay; // not used on web

  @override
  void initState() {
    super.initState();
    referralCtrl.text = widget.prefilledReferral ?? '';
    phoneCtrl.text = widget.prefilledPhone ?? '';
    
    // If phone is prefilled, check if we can skip OTP
    if (widget.prefilledPhone != null) {
      _checkInitialRegistrationStatus();
    }
    
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  Future<void> _checkInitialRegistrationStatus() async {
    if (widget.prefilledPhone == null) return;
    
    try {
      final registrationStatus = await RegistrationStateService.checkRegistrationStatus(widget.prefilledPhone!);
      if (registrationStatus.isOtpVerified) {
        // Skip to form if OTP already verified
        setState(() => stage = StepStage.form);
      }
    } catch (e) {
      // If check fails, continue with normal flow
      debugPrint('Error checking initial registration status: $e');
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    phoneCtrl.dispose();
    otpCtrl.dispose();
    nameCtrl.dispose();
    villageCtrl.dispose();
    pinCtrl.dispose();
    pin2Ctrl.dispose();
    referralCtrl.dispose();
    super.dispose();
  }

  // ------------ PHONE + OTP ------------

  Future<void> _sendOtp() async {
    final phone = phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _snack('Enter mobile number');
      return;
    }
    
    setState(() => busy = true);
    
    try {
      // First check registration status
      final registrationStatus = await RegistrationStateService.checkRegistrationStatus(phone);
      
      if (registrationStatus.isAlreadyRegistered) {
        _snack(registrationStatus.message);
        setState(() => busy = false);
        return;
      }
      
      if (registrationStatus.isOtpVerified) {
        // Phone already verified, skip OTP and go to form
        _snack(registrationStatus.message);
        setState(() => stage = StepStage.form);
        setState(() => busy = false);
        return;
      }
      
      // Need to send OTP
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (cred) async {
          final user = await FirebaseAuth.instance.signInWithCredential(cred);
          if (user.user != null) {
            await RegistrationStateService.markPhoneAsVerified(phone, user.user!.uid);
            setState(() => stage = StepStage.form);
          }
        },
        verificationFailed: (e) => _snack(e.message ?? 'OTP failed'),
        codeSent: (id, _) {
          _verificationId = id;
          setState(() => stage = StepStage.otp);
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      _snack('Error: ${e.toString()}');
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = otpCtrl.text.trim();
    if (_verificationId == null || code.length < 4) {
      _snack('Enter valid OTP');
      return;
    }
    setState(() => busy = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(cred);
      
      if (userCredential.user != null) {
        // Mark phone as verified for future registrations
        final phone = phoneCtrl.text.trim();
        await RegistrationStateService.markPhoneAsVerified(phone, userCredential.user!.uid);
        setState(() => stage = StepStage.form);
      }
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Invalid OTP');
    } finally {
      setState(() => busy = false);
    }
  }

  // ------------ FORM → LINK EMAIL/PASS → PAYMENT ------------

  Future<void> _submitFormThenPay() async {
    if (!termsAccepted) return _snack('Please accept Terms & Conditions');
    if (nameCtrl.text.trim().isEmpty) return _snack('Enter full name');

    if (stateVal == null ||
        districtVal == null ||
        mandalVal == null ||
        villageCtrl.text.trim().isEmpty) {
      return _snack('Fill location details');
    }

    final pin = pinCtrl.text.trim();
    final pin2 = pin2Ctrl.text.trim();
    if (!isValidPin(pin) || pin != pin2) {
      return _snack('Enter a valid 6-digit PIN (both must match)');
    }

    setState(() => busy = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _snack('Not signed in with phone. Please restart.');
        return;
      }

      // 1) Link alias email/password (sha256(PIN)) to same UID
      final e164 = normalizeE164(phoneCtrl.text.trim());
      final alias = aliasEmailForPhone(e164);
      final pass  = passwordFromPin(pin);

      final hasPassword = user.providerData.any((p) => p.providerId == 'password');
      if (!hasPassword) {
        final cred = EmailAuthProvider.credential(email: alias, password: pass);
        try {
          await user.linkWithCredential(cred);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
            await user.updatePassword(pass);
          } else {
            rethrow;
          }
        }
        await user.updateEmail(alias);
      } else {
        await user.updatePassword(pass);
        await user.updateEmail(alias);
      }

      // 2) Payment step
      setState(() => stage = StepStage.paying);
      await _startPayment(e164: e164);

    } catch (e) {
      _snack('Form error: $e');
      setState(() => stage = StepStage.form);
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _startPayment({required String e164}) async {
    if (kIsWeb) {
      // Flutter web: razorpay_flutter is not supported. Simulate for dev.
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Payment (Web Dev)'),
          content: const Text('Razorpay web integration not active. Simulate success to continue.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () { Navigator.pop(context); _handlePaymentSuccess(null); },
              child: const Text('Simulate Success'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final opts = {
        'key': 'YOUR_RAZORPAY_KEY', // TODO: replace with your key
        'amount': 10000,            // ₹100 in paise
        'name': 'TALOWA Registration',
        'description': 'Membership Fee',
        'prefill': {'contact': e164},
        'timeout': 120,
      };
      _razorpay?.open(opts);
    } catch (e) {
      _snack('Payment init failed: $e');
      setState(() => stage = StepStage.form);
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse? response) async {
    await _saveProfile(
      paymentRef: response?.paymentId ?? 'web_demo_success',
      paymentStatus: 'success',
    );
    setState(() => stage = StepStage.done);
    _snack('Registration successful 🎉');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _snack('Payment failed: ${response.code}');
    setState(() => stage = StepStage.form);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _snack('External wallet: ${response.walletName}');
  }

  // ------------ SAVE PROFILE (users/{uid}) ------------

  Future<void> _saveProfile({
    required String paymentRef,
    required String paymentStatus,
  }) async {
    // ensure signed-in user (important on web)
    final user = FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null);

    final uid = user!.uid;
    final phoneE164 = normalizeE164(phoneCtrl.text.trim());
    final aliasEmail = aliasEmailForPhone(phoneE164);
    final pinHashHex = passwordFromPin(pinCtrl.text.trim()); // sha256(PIN)

    // Save user profile
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'fullName': nameCtrl.text.trim(),
      'phoneE164': phoneE164,
      'aliasEmail': aliasEmail,
      'state': stateVal,
      'district': districtVal,
      'mandal': mandalVal,
      'village': villageCtrl.text.trim(),
      'referralCodeUsed': (referralCtrl.text.trim().isEmpty) ? null : referralCtrl.text.trim(),
      'pinHash': pinHashHex, // store hash only
      'role': 'Member',
      'createdAt': FieldValue.serverTimestamp(),
      'payment': {
        'amount': 100,
        'currency': 'INR',
        'provider': kIsWeb ? 'web-demo' : 'razorpay',
        'reference': paymentRef,
        'status': paymentStatus,
        'paidAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    // Create user registry entry to prevent duplicate registrations
    await FirebaseFirestore.instance.collection('user_registry').doc(phoneE164).set({
      'uid': uid,
      'phoneNumber': phoneE164,
      'email': aliasEmail,
      'fullName': nameCtrl.text.trim(),
      'role': 'Member',
      'state': stateVal,
      'district': districtVal,
      'mandal': mandalVal,
      'village': villageCtrl.text.trim(),
      'isActive': true,
      'membershipPaid': paymentStatus == 'success',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'pinHash': pinHashHex,
    });

    // Clear phone verification since registration is complete
    await RegistrationStateService.clearPhoneVerification(phoneE164);
  }

  // ------------ UI ------------

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join TALOWA Movement')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (stage == StepStage.phone) _phoneStep(),
              if (stage == StepStage.otp) _otpStep(),
              if (stage == StepStage.form) _formStep(),
              if (stage == StepStage.paying) _payingStep(),
              if (stage == StepStage.done) _doneStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Header(),
      const SizedBox(height: 12),
      TextField(
        controller: phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Mobile Number *',
          prefixIcon: Icon(Icons.phone),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: busy ? null : _sendOtp,
        child: Text(busy ? 'Sending…' : 'Send OTP'),
      ),
    ],
  );

  Widget _otpStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Header(),
      const SizedBox(height: 12),
      TextField(
        controller: otpCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Enter OTP',
          prefixIcon: Icon(Icons.verified),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: busy ? null : _verifyOtp,
        child: Text(busy ? 'Verifying…' : 'Verify OTP'),
      ),
    ],
  );

  Widget _formStep() {
    final districts = districtsByState[stateVal] ?? <String>[];
    if (districtVal != null && !districts.contains(districtVal)) districtVal = null;
    final mandals = mandalsByDistrict[districtVal] ?? <String>[];
    if (mandalVal != null && !mandals.contains(mandalVal)) mandalVal = null;

    final verifiedPhone = phoneCtrl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(),
        const SizedBox(height: 12),
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Full Name *',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          enabled: false,
          controller: TextEditingController(text: verifiedPhone),
          decoration: const InputDecoration(
            labelText: 'Mobile Number (verified)',
            prefixIcon: Icon(Icons.phone_android),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: stateVal,
          decoration: const InputDecoration(
            labelText: 'State *',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
          items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => stateVal = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: districtVal,
          decoration: const InputDecoration(
            labelText: 'District *',
            prefixIcon: Icon(Icons.location_city),
            border: OutlineInputBorder(),
          ),
          items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => districtVal = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: mandalVal,
          decoration: const InputDecoration(
            labelText: 'Mandal/Tehsil *',
            prefixIcon: Icon(Icons.map),
            border: OutlineInputBorder(),
          ),
          items: mandals.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => mandalVal = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: villageCtrl,
          decoration: const InputDecoration(
            labelText: 'Village/City *',
            prefixIcon: Icon(Icons.home),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pinCtrl,
          maxLength: 6,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(
            counterText: '',
            labelText: 'Create PIN (6 digits) *',
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pin2Ctrl,
          maxLength: 6,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(
            counterText: '',
            labelText: 'Confirm PIN *',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: referralCtrl,
          decoration: const InputDecoration(
            labelText: 'Referral Code (Optional)',
            prefixIcon: Icon(Icons.group_add),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: termsAccepted,
              onChanged: (v) => setState(() => termsAccepted = v ?? false),
            ),
            const Expanded(
              child: Text(
                'I agree to the Terms of Service and Privacy Policy of TALOWA.',
                maxLines: 3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : _submitFormThenPay,
          child: Text(busy ? 'Please wait…' : 'Pay ₹100 & Register'),
        ),
      ],
    );
  }

  Widget _payingStep() => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Header(),
      SizedBox(height: 20),
      Center(child: CircularProgressIndicator()),
      SizedBox(height: 8),
      Center(child: Text('Opening payment…')),
    ],
  );

  Widget _doneStep() => const Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _Header(),
      SizedBox(height: 24),
      Icon(Icons.check_circle, size: 96, color: Colors.green),
      SizedBox(height: 24),
      Text('Registration Successful', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE3F3E6), Color(0xFFCFEBD6)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.eco, color: Colors.green, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Welcome to TALOWA\nJoin the movement for land rights and rural empowerment',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
