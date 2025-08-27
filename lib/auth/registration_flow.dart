// lib/registration_flow.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_policy.dart';

/// Minimal registration flow widget:
/// Assumes OTP verification already done, currentUser != null.
/// Then it links email/password (alias) so future logins can use phone+PIN,
/// writes profile to /users/{uid}, ensures unique /phones/{e164},
/// and creates a /registries/{uid} doc (needed by your app).
class CompleteRegistrationScreen extends StatefulWidget {
  final String fullName;
  final String phoneRaw;              // The phone entered by user earlier
  final String pin;                   // 6 digits (string)
  final String? referralCode;         // optional
  final String state;
  final String district;
  final String mandal;
  final String village;
  final bool simulatePayment;         // for now true: mark paid instantly

  const CompleteRegistrationScreen({
    super.key,
    required this.fullName,
    required this.phoneRaw,
    required this.pin,
    this.referralCode,
    required this.state,
    required this.district,
    required this.mandal,
    required this.village,
    this.simulatePayment = true,
  });

  @override
  State<CompleteRegistrationScreen> createState() => _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState extends State<CompleteRegistrationScreen> {
  bool _busy = false;
  String? _error;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> _finish() async {
    setState(() { _busy = true; _error = null; });

    try {
      // 1) Verify we have an authenticated user from OTP step
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user. Complete OTP first.');
      }

      // 2) Build alias email + hashed password using shared policy
      final e164 = normalizePhoneE164(widget.phoneRaw);
      final email = phoneToAliasEmail(e164);
      final hashedPin = hashPin(widget.pin);

      // 3) Link Email/Password credentials to this OTP-authenticated user
      // If already linked, this will throw; handle and continue.
      try {
        final cred = EmailAuthProvider.credential(email: email, password: hashedPin);
        await user.linkWithCredential(cred);
        // success → future email/pw login (phone+PIN) will work
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked' || e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          // Ensure the email/pw password is the latest hash (set via reauth)
          try {
            // Reauthenticate (phone user) cannot sign-in as email without password,
            // so update by signing-in silently via email; if it fails, ignore (still usable).
            await _auth.signInWithEmailAndPassword(email: email, password: hashedPin);
          } catch (_) {/* ignore */}
        } else {
          rethrow;
        }
      }

      // 4) Write /users/{uid} (owner-only)
      final uid = user.uid;
      final now = FieldValue.serverTimestamp();
      final userDoc = _db.collection('users').doc(uid);

      // idempotent merge
      await userDoc.set({
        'fullName': widget.fullName,
        'phone': e164,
        'email': email,
        'active': true,
        'role': 'member',
        'state': widget.state,
        'district': widget.district,
        'mandal': widget.mandal,
        'village': widget.village,
        'referralChain': {
          'referredBy': widget.referralCode,
          'referralCode': null, // can be filled later/CFN
        },
        'directReferrals': 0,
        'teamSize': 0,
        'createdAt': now,
        'updatedAt': now,
        'membershipPaid': widget.simulatePayment,
        'paymentCompletedAt': widget.simulatePayment ? now : null,
        'paymentTransactionId': widget.simulatePayment ? 'web_simulation_${DateTime.now().millisecondsSinceEpoch}' : null,
      }, SetOptions(merge: true));

      // 5) Enforce uniqueness: /phones/{e164}
      // Only create if not exists; rule will enforce this too.
      final phoneDoc = _db.collection('phones').doc(e164);
      final snap = await phoneDoc.get();
      if (!snap.exists) {
        await phoneDoc.set({
          'uid': uid,
          'createdAt': now,
        });
      } else {
        // If it points elsewhere, refuse
        final existingUid = snap.data()?['uid'];
        if (existingUid != uid) {
          throw Exception('This phone is already registered to another account.');
        }
      }

      // 6) Minimal registry doc your app expects
      final regDoc = _db.collection('registries').doc(uid);
      await regDoc.set({
        'uid': uid,
        'phone': e164,
        'email': email,
        'membershipPaid': widget.simulatePayment,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration complete. Welcome to TALOWA!')),
      );
      Navigator.of(context).pushReplacementNamed('/main');
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-finish for this demo page (or attach to a button).
    unawaited(_finish());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Registration')),
      body: Center(
        child: _busy
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                    ElevatedButton(
                      onPressed: _finish,
                      child: const Text('Retry Complete Registration'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}