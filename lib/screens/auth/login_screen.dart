import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_policy.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  bool loading = false;
  bool obscure = true;

  @override
  void dispose() {
    phoneCtrl.dispose();
    pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final rawPhone = phoneCtrl.text.trim();
    final pin = pinCtrl.text.trim();

    if (rawPhone.isEmpty || pin.isEmpty) {
      _snack('Please enter phone and PIN');
      return;
    }
    if (!isValidPin(pin)) {
      _snack('PIN must be 6 digits');
      return;
    }

    final e164 = normalizeE164(rawPhone);               // "+91XXXXXXXXXX"
    final email = aliasEmailForPhone(e164);             // "<E164>@talowa.phone"
    final pass  = passwordFromPin(pin);                 // sha256(PIN)

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'user-not-found' => 'No account found. Please register.',
        'wrong-password' || 'invalid-credential' => 'Invalid PIN. Please try again.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'network-request-failed' => 'Network error. Check connection.',
        _ => 'Login error: ${e.code}',
      };
      _snack(msg);
    } catch (e) {
      _snack('Login failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text('Welcome Back!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: obscure,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '6-Digit PIN',
                  border: const OutlineInputBorder(),
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: loading ? null : _login,
                child: loading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Sign In'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text("Don't have an account? Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
