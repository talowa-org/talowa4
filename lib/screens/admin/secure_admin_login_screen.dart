// Secure Admin Login Screen - Firebase Auth + Custom Claims + PIN as 2FA
// Enterprise-grade admin login with proper authentication flow
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/admin/enhanced_admin_auth_service.dart';
import 'enterprise_admin_dashboard_screen.dart';

class SecureAdminLoginScreen extends StatefulWidget {
  const SecureAdminLoginScreen({super.key});

  @override
  State<SecureAdminLoginScreen> createState() => _SecureAdminLoginScreenState();
}

class _SecureAdminLoginScreenState extends State<SecureAdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _showPinField = false;
  bool _obscurePassword = true;
  bool _obscurePin = true;
  String? _currentUserRole;
  String? _currentUserRegion;

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
    // Initialize the admin auth service
    EnhancedAdminAuthService.initialize();
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
            builder: (context) => const EnterpriseAdminDashboardScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Admin logo and title
                      _buildHeader(),
                      
                      const SizedBox(height: 32),
                      
                      // Login form
                      if (!_showPinField) ...[
                        _buildEmailField(),
                        const SizedBox(height: 16),
                        _buildPasswordField(),
                      ] else ...[
                        _buildPinField(),
                        if (_currentUserRole != null) _buildRoleInfo(),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Login button
                      _buildLoginButton(),
                      
                      if (_showPinField) ...[
                        const SizedBox(height: 16),
                        _buildBackButton(),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Security notice
                      _buildSecurityNotice(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
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
        
        const SizedBox(height: 16),
        
        Text(
          'TALOWA Admin Portal',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.red[800],
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          _showPinField 
              ? 'Enter your PIN for two-factor authentication'
              : 'Secure admin access with Firebase Authentication',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'Admin Email',
        prefixIcon: const Icon(Icons.email_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: TextInputType.emailAddress,
      enabled: !_isLoading,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      obscureText: _obscurePassword,
      enabled: !_isLoading,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildPinField() {
    return TextFormField(
      controller: _pinController,
      decoration: InputDecoration(
        labelText: 'Admin PIN (2FA)',
        prefixIcon: const Icon(Icons.security),
        suffixIcon: IconButton(
          icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscurePin = !_obscurePin),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.green[50],
        helperText: 'Enter your 4-8 digit PIN for verification',
      ),
      obscureText: _obscurePin,
      keyboardType: TextInputType.number,
      enabled: !_isLoading,
      maxLength: 8,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your PIN';
        }
        if (value.length < 4) {
          return 'PIN must be at least 4 digits';
        }
        return null;
      },
    );
  }

  Widget _buildRoleInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Row(
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
          if (_currentUserRegion != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.green[800], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Region: ${_currentUserRegion!}',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : (_showPinField ? _verifyPin : _loginWithFirebase),
        style: ElevatedButton.styleFrom(
          backgroundColor: _showPinField ? Colors.green[800] : Colors.red[800],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _showPinField ? 'Verify PIN & Access Dashboard' : 'Login with Firebase',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton(
      onPressed: _isLoading ? null : () {
        setState(() {
          _showPinField = false;
          _currentUserRole = null;
          _currentUserRegion = null;
          _pinController.clear();
        });
      },
      child: const Text('Back to Login'),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.blue[800], size: 20),
              const SizedBox(width: 8),
              Text(
                'Enterprise Security',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This system uses Firebase Authentication with Custom Claims and PIN-based two-factor authentication. All admin actions are logged for audit purposes.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  /// Login with Firebase Authentication (Primary Factor)
  Future<void> _loginWithFirebase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Sign in with Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Check if user has admin role via Custom Claims
      final accessCheck = await EnhancedAdminAuthService.checkAdminAccess();
      
      if (accessCheck.success) {
        setState(() {
          _currentUserRole = accessCheck.role;
          _currentUserRegion = accessCheck.region;
          _showPinField = true;
        });
      } else {
        // User doesn't have admin role
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          _showErrorSnackBar(accessCheck.message);
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
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later';
          break;
        default:
          message = 'Authentication failed: ${e.message}';
      }

      if (mounted) {
        _showErrorSnackBar(message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Login error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Verify PIN for two-factor authentication (Secondary Factor)
  Future<void> _verifyPin() async {
    if (!_formKey.currentState!.validate()) return;

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
          // Check if PIN change is required
          if (result.requiresPinChange) {
            _showPinChangeDialog();
          } else {
            // Navigate to enhanced admin dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const EnterpriseAdminDashboardScreen(),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          _showErrorSnackBar(result.message);
        }
      }

    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('PIN verification failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showPinChangeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('PIN Change Required'),
          ],
        ),
        content: const Text(
          'You are using the default PIN. For security reasons, please change your PIN before accessing the admin dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to PIN change screen or show PIN change dialog
              _showPinChangeForm();
            },
            child: const Text('Change PIN'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Allow access but show warning
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const EnterpriseAdminDashboardScreen(),
                ),
              );
            },
            child: const Text('Continue (Not Recommended)'),
          ),
        ],
      ),
    );
  }

  void _showPinChangeForm() {
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Change Admin PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPinController,
              decoration: const InputDecoration(
                labelText: 'New PIN',
                helperText: 'Enter 4-8 digits',
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPinController,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPinController.text != confirmPinController.text) {
                _showErrorSnackBar('PINs do not match');
                return;
              }
              
              try {
                final result = await EnhancedAdminAuthService.changeAdminPin(
                  currentPin: _pinController.text,
                  newPin: newPinController.text,
                );
                
                if (result.success) {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EnterpriseAdminDashboardScreen(),
                    ),
                  );
                } else {
                  _showErrorSnackBar(result.message);
                }
              } catch (e) {
                _showErrorSnackBar('Failed to change PIN: $e');
              }
            },
            child: const Text('Change PIN'),
          ),
        ],
      ),
    );
  }
}