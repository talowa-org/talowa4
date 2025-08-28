// lib/login.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/unified_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _busy = true; _error = null; });

    try {
      final phoneRaw = _phoneCtrl.text.trim();
      final pin = _pinCtrl.text.trim();

      if (phoneRaw.isEmpty) {
        throw Exception('Please enter your mobile number');
      }

      if (pin.length != 6) {
        throw Exception('PIN must be 6 digits');
      }

      // Login attempt - sensitive data not logged for security

      // Use UnifiedAuthService for consistent login
      final result = await UnifiedAuthService.loginUser(
        phoneNumber: phoneRaw,
        pin: pin,
      );

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        setState(() { _error = result.message; });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Login error: $e');
      }
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome Back!')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '6-Digit PIN'),
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy ? null : _login,
              child: _busy ? const CircularProgressIndicator() : const Text('Sign In'),
            ),
            const SizedBox(height: 8),
            const Text('Note: Login does not read Firestore; it uses your phone+PIN alias.'),
          ],
        ),
      ),
    );
  }
}