// Admin Login Screen - Quick access for admin users
import 'package:flutter/material.dart';
import '../../services/admin/admin_auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'admin_pin_change_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill admin credentials for quick access
    _phoneController.text = '+917981828388';
    // Initialize admin user if needed
    AdminAuthService.initializeAdminUser();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Login'),
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
              'Admin Access',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Login with admin credentials to access the dashboard',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Phone number field
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Admin Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              enabled: !_isLoading,
            ),
            
            const SizedBox(height: 16),
            
            // PIN field
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'Admin PIN',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              enabled: !_isLoading,
            ),
            
            const SizedBox(height: 24),
            
            // Login button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _loginAsAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login as Admin'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Quick access note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[800], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Admin Credentials',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Phone: +917981828388\nDefault PIN: 1234',
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

  Future<void> _loginAsAdmin() async {
    if (_phoneController.text.isEmpty || _pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both phone number and PIN'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AdminAuthService.authenticateAdmin(
        phoneNumber: _phoneController.text,
        pin: _pinController.text,
      );

      if (result.success) {
        if (mounted) {
          // Check if using default PIN
          if (result.isDefaultPin) {
            // Show PIN change recommendation
            final shouldChangePIN = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Security Notice'),
                content: const Text(
                  'You are using the default PIN. For security reasons, it is recommended to change your PIN.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Later'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Change PIN'),
                  ),
                ],
              ),
            );

            if (shouldChangePIN == true) {
              // Navigate to PIN change screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminPinChangeScreen(),
                ),
              );
              return;
            }
          }

          // Navigate to admin dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminDashboardScreen(),
            ),
          );
        }
      } else {
        // Login failed
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
}