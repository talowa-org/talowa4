// Enhanced Admin Login Screen - Firebase Auth + Custom Claims + PIN as 2FA
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/admin/enhanced_admin_auth_service.dart';
import 'enhanced_admin_dashboard_screen.dart';
import 'admin_pin_change_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _showPinField = false;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  /// Check if user is already authenticated with admin role
  Future<void> _checkExistingAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final accessCheck = await EnhancedAdminAuthService.checkAdminAccess();
      if (accessCheck.success && mounted) {
        // User already has admin access, go to dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const EnhancedAdminDashboardScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Access'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Admin icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.admin_panel_settings,
                size: 64,
                color: Colors.red[800],
              ),
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Secure Admin Access',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              _showPinField 
                  ? 'Enter your PIN for two-factor authentication'
                  : 'Login with your Firebase admin credentials',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 32),
            
            if (!_showPinField) ...[
              // Email field
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Admin Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
              ),
              
              const SizedBox(height: 16),
              
              // Password field
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enabled: !_isLoading,
              ),
            ] else ...[
              // PIN field for 2FA
              TextField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'Admin PIN (2FA)',
                  prefixIcon: Icon(Icons.security),
                  border: OutlineInputBorder(),
                  helperText: 'Enter your 4-digit PIN for verification',
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                maxLength: 4,
              ),
              
              if (_currentUserRole != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.green[800], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Role: ${_currentUserRole!.replaceAll('_', ' ').toUpperCase()}',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            
            const SizedBox(height: 24),
            
            // Login button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_showPinField ? _verifyPin : _loginWithFirebase),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_showPinField ? 'Verify PIN & Access Dashboard' : 'Login with Firebase'),
              ),
            ),
            
            if (_showPinField) ...[
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: _isLoading ? null : () {
                  setState(() {
                    _showPinField = false;
                    _currentUserRole = null;
                  });
                },
                child: const Text('Back to Login'),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Security notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.orange[800], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Security Notice',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This system uses Firebase Authentication with Custom Claims and PIN-based two-factor authentication for enhanced security.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Login with Firebase Authentication
  Future<void> _loginWithFirebase() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter both email and password'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Sign in with Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Check if user has admin role
      final accessCheck = await EnhancedAdminAuthService.checkAdminAccess();
      
      if (accessCheck.success) {
        setState(() {
          _currentUserRole = accessCheck.role;
          _showPinField = true;
        });
      } else {
        // User doesn't have admin role
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(accessCheck.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

    } on FirebaseAuthException catch (e) {
      String message = 'Authentication failed';
      
      switch (e.code) {
        case 'user-not-found':
          message = 'No admin account found with this email';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'user-disabled':
          message = 'This admin account has been disabled';
          break;
        default:
          message = 'Authentication failed: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Verify PIN for two-factor authentication
  Future<void> _verifyPin() async {
    if (_pinController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your PIN'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate PIN as 2FA
      final result = await EnhancedAdminAuthService.authenticateWithPin(
        phoneNumber: '+917981828388', // Admin phone for PIN verification
        pin: _pinController.text,
      );

      if (result.success) {
        if (mounted) {
          // Navigate to enhanced admin dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const EnhancedAdminDashboardScreen(),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}