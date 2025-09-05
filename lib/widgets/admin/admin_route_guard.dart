// Admin Route Guard - Protects admin routes with proper authentication
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/admin/enhanced_admin_auth_service.dart';
import '../../screens/admin/enhanced_admin_dashboard_screen.dart';
import '../../screens/admin/admin_login_screen.dart';

class AdminRouteGuard extends StatefulWidget {
  const AdminRouteGuard({super.key});

  @override
  State<AdminRouteGuard> createState() => _AdminRouteGuardState();
}

class _AdminRouteGuardState extends State<AdminRouteGuard> {
  bool _isLoading = true;
  bool _hasAdminAccess = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _hasAdminAccess = false;
          _isLoading = false;
        });
        return;
      }

      // Check admin role via Custom Claims
      final accessCheck = await EnhancedAdminAuthService.checkAdminAccess();
      
      setState(() {
        _hasAdminAccess = accessCheck.success;
        _isLoading = false;
        if (!accessCheck.success) {
          _error = accessCheck.message;
        }
      });

    } catch (e) {
      setState(() {
        _hasAdminAccess = false;
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Access'),
          backgroundColor: Colors.red[800],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying admin access...'),
            ],
          ),
        ),
      );
    }

    if (_hasAdminAccess) {
      // User has admin access, show dashboard
      return const EnhancedAdminDashboardScreen();
    } else {
      // User doesn't have admin access, show unauthorized screen
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red[800],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 80,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Unauthorized Access',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'You do not have permission to access the admin panel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Show login button if not authenticated
                if (FirebaseAuth.instance.currentUser == null) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminLoginScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Admin Login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ] else ...[
                  // User is authenticated but doesn't have admin role
                  Column(
                    children: [
                      Text(
                        'Logged in as: ${FirebaseAuth.instance.currentUser!.email ?? 'Unknown'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AdminLoginScreen(),
                                  ),
                                );
                              }
                            },
                            child: const Text('Switch Account'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacementNamed('/main');
                            },
                            child: const Text('Go to App'),
                          ),
                        ],
                      ),
                    ],
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
                          Icon(Icons.info, color: Colors.orange[800], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Security Notice',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Admin access requires proper authentication and role assignment. Contact your system administrator if you believe you should have access.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

