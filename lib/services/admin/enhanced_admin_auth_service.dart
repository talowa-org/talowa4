// Enhanced Admin Authentication Service - Firebase Auth + Custom Claims + PIN as 2FA
// Enterprise-grade admin system with RBAC, MFA, and session management
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';

class EnhancedAdminAuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Session timeout in minutes
  static const int _sessionTimeoutMinutes = 30;
  static DateTime? _lastActivity;
  static Timer? _sessionTimer;
  
  // Admin roles hierarchy (lower number = higher privilege)
  static const Map<String, int> adminRoles = {
    'super_admin': 0,
    'moderator': 1,
    'regional_admin': 2,
    'auditor': 3,
  };
  
  // Role permissions mapping
  static const Map<String, List<String>> rolePermissions = {
    'super_admin': ['*'], // All permissions
    'moderator': ['moderate_content', 'ban_users', 'view_reports', 'manage_posts'],
    'regional_admin': ['moderate_content', 'view_regional_data', 'manage_regional_users'],
    'auditor': ['view_logs', 'view_analytics', 'export_data', 'read_only_access'],
  };
  
  /// Initialize admin authentication system
  static Future<void> initialize() async {
    try {
      // Start session monitoring
      _startSessionMonitoring();
      
      // Ensure admin configuration exists
      await _ensureAdminConfig();
      
      debugPrint('Enhanced Admin Auth Service initialized');
    } catch (e) {
      debugPrint('Error initializing admin auth service: $e');
    }
  }
  
  /// Check if current user has admin access via Custom Claims
  static Future<AdminAccessResult> checkAdminAccess() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AdminAccessResult(
          success: false,
          message: 'User not authenticated',
        );
      }
      
      // Force token refresh to get latest custom claims
      await user.getIdToken(true);
      final idTokenResult = await user.getIdTokenResult();
      final claims = idTokenResult.claims;
      
      final role = claims?['role'] as String?;
      final region = claims?['region'] as String?;
      
      if (role == null || !adminRoles.containsKey(role)) {
        return AdminAccessResult(
          success: false,
          message: 'User does not have admin privileges',
        );
      }
      
      // Check if account is disabled
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final status = userData['status'] as String?;
        if (status == 'banned' || status == 'disabled') {
          return AdminAccessResult(
            success: false,
            message: 'Admin account is disabled',
          );
        }
      }
      
      // Update last activity
      _updateLastActivity();
      
      return AdminAccessResult(
        success: true,
        message: 'Admin access verified',
        role: role,
        region: region,
        permissions: rolePermissions[role] ?? [],
      );
      
    } catch (e) {
      debugPrint('Error checking admin access: $e');
      return AdminAccessResult(
        success: false,
        message: 'Failed to verify admin access: ${e.toString()}',
      );
    }
  }
  
  /// Authenticate with PIN as secondary factor (2FA)
  static Future<AdminAuthResult> authenticateWithPin({
    required String phoneNumber,
    required String pin,
  }) async {
    try {
      // First verify user has admin role via Custom Claims
      final accessCheck = await checkAdminAccess();
      if (!accessCheck.success) {
        return AdminAuthResult(
          success: false,
          message: accessCheck.message,
        );
      }
      
      // Normalize phone number
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      
      // Get admin PIN configuration
      final adminDoc = await _firestore.collection('admin_config').doc('credentials').get();
      
      if (!adminDoc.exists) {
        return AdminAuthResult(
          success: false,
          message: 'Admin configuration not found',
        );
      }
      
      final adminData = adminDoc.data()!;
      final storedPinHash = adminData['pinHash'] as String;
      final isActive = adminData['isActive'] as bool? ?? true;
      final maxAttempts = adminData['maxAttempts'] as int? ?? 5;
      final failedAttempts = adminData['failedAttempts'] as int? ?? 0;
      
      if (!isActive) {
        return AdminAuthResult(
          success: false,
          message: 'Admin account is disabled',
        );
      }
      
      // Check for too many failed attempts
      if (failedAttempts >= maxAttempts) {
        final lockoutUntil = adminData['lockoutUntil'] as Timestamp?;
        if (lockoutUntil != null && lockoutUntil.toDate().isAfter(DateTime.now())) {
          return AdminAuthResult(
            success: false,
            message: 'Account locked due to too many failed attempts. Try again later.',
          );
        }
      }
      
      // Verify PIN
      final inputPinHash = _hashPin(pin);
      if (inputPinHash != storedPinHash) {
        // Increment failed attempts
        await _firestore.collection('admin_config').doc('credentials').update({
          'failedAttempts': FieldValue.increment(1),
          'lastFailedAttempt': FieldValue.serverTimestamp(),
        });
        
        // Lock account if too many attempts
        if (failedAttempts + 1 >= maxAttempts) {
          await _firestore.collection('admin_config').doc('credentials').update({
            'lockoutUntil': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 30))),
          });
        }
        
        return AdminAuthResult(
          success: false,
          message: 'Invalid PIN',
        );
      }
      
      // Reset failed attempts on successful login
      await _firestore.collection('admin_config').doc('credentials').update({
        'failedAttempts': 0,
        'lockoutUntil': FieldValue.delete(),
      });
      
      // Update last login
      await _updateLastLogin();
      
      // Check if using default PIN
      const defaultPin = '1234';
      final isDefaultPin = storedPinHash == _hashPin(defaultPin);
      
      // Log successful authentication
      await _logAdminAction('admin_login', {
        'method': 'pin_2fa',
        'role': accessCheck.role,
        'isDefaultPin': isDefaultPin,
      });
      
      return AdminAuthResult(
        success: true,
        message: 'PIN verification successful',
        role: accessCheck.role,
        region: accessCheck.region,
        isDefaultPin: isDefaultPin,
        requiresPinChange: isDefaultPin,
      );
      
    } catch (e) {
      debugPrint('PIN authentication error: $e');
      return AdminAuthResult(
        success: false,
        message: 'PIN verification failed: ${e.toString()}',
      );
    }
  }
  
  /// Validate admin access for sensitive operations with re-authentication
  static Future<AdminAuthResult> validateSensitiveOperation({
    required String operation,
    String? pin,
  }) async {
    try {
      final sensitiveOperations = [
        'ban_user', 'delete_user', 'export_data', 'assign_role', 
        'revoke_role', 'bulk_moderate', 'system_config'
      ];
      
      if (!sensitiveOperations.contains(operation)) {
        // Non-sensitive operation, just check basic access
        final accessCheck = await checkAdminAccess();
        return AdminAuthResult(
          success: accessCheck.success,
          message: accessCheck.message,
          role: accessCheck.role,
        );
      }
      
      // Sensitive operation requires re-authentication
      if (pin == null) {
        return AdminAuthResult(
          success: false,
          message: 'PIN required for sensitive operation',
          requiresReauth: true,
        );
      }
      
      // Use Cloud Function for validation
      final result = await _functions.httpsCallable('validateAdminAccess').call({
        'action': operation,
        'pin': pin,
      });

      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        return AdminAuthResult(
          success: true,
          message: 'Sensitive operation validated',
          role: data['role'] as String?,
          permissions: List<String>.from(data['permissions'] ?? []),
        );
      } else {
        return AdminAuthResult(
          success: false,
          message: data['message'] ?? 'Validation failed',
        );
      }
      
    } catch (e) {
      debugPrint('Error validating sensitive operation: $e');
      return AdminAuthResult(
        success: false,
        message: 'Validation failed: ${e.toString()}',
      );
    }
  }
  
  /// Assign admin role (only super_admin can do this)
  static Future<AdminAuthResult> assignAdminRole({
    required String targetUid,
    required String role,
    String? region,
  }) async {
    try {
      final result = await _functions.httpsCallable('assignAdminRole').call({
        'targetUid': targetUid,
        'role': role,
        'region': region,
      });

      final data = result.data as Map<String, dynamic>;
      
      return AdminAuthResult(
        success: data['success'] == true,
        message: data['message'] ?? 'Unknown error',
      );

    } catch (e) {
      debugPrint('Error assigning admin role: $e');
      return AdminAuthResult(
        success: false,
        message: 'Failed to assign role: ${e.toString()}',
      );
    }
  }

  /// Revoke admin role (only super_admin can do this)
  static Future<AdminAuthResult> revokeAdminRole({
    required String targetUid,
  }) async {
    try {
      final result = await _functions.httpsCallable('revokeAdminRole').call({
        'targetUid': targetUid,
      });

      final data = result.data as Map<String, dynamic>;
      
      return AdminAuthResult(
        success: data['success'] == true,
        message: data['message'] ?? 'Unknown error',
      );

    } catch (e) {
      debugPrint('Error revoking admin role: $e');
      return AdminAuthResult(
        success: false,
        message: 'Failed to revoke role: ${e.toString()}',
      );
    }
  }
  
  /// Change admin PIN with enhanced security
  static Future<AdminAuthResult> changeAdminPin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      // Verify current PIN first
      final authResult = await authenticateWithPin(
        phoneNumber: '+917981828388', // Admin phone
        pin: currentPin,
      );
      
      if (!authResult.success) {
        return AdminAuthResult(
          success: false,
          message: 'Current PIN is incorrect',
        );
      }
      
      // Validate new PIN strength
      final validation = _validatePinStrength(newPin);
      if (!validation.isValid) {
        return AdminAuthResult(
          success: false,
          message: validation.message,
        );
      }
      
      // Check PIN history to prevent reuse
      final isReused = await _checkPinHistory(newPin);
      if (isReused) {
        return AdminAuthResult(
          success: false,
          message: 'Cannot reuse recent PINs. Choose a different PIN.',
        );
      }
      
      // Update PIN in Firestore
      await _firestore.collection('admin_config').doc('credentials').update({
        'pinHash': _hashPin(newPin),
        'lastUpdated': FieldValue.serverTimestamp(),
        'pinChangedAt': FieldValue.serverTimestamp(),
        'pinChangedBy': _auth.currentUser?.uid,
        'failedAttempts': 0, // Reset failed attempts
      });
      
      // Store PIN in history
      await _storePinHistory(currentPin);
      
      // Log PIN change
      await _logAdminAction('pin_changed', {
        'changedBy': _auth.currentUser?.uid,
        'role': authResult.role,
      });
      
      debugPrint('Admin PIN changed successfully');
      
      return AdminAuthResult(
        success: true,
        message: 'PIN changed successfully',
      );
      
    } catch (e) {
      debugPrint('Error changing admin PIN: $e');
      return AdminAuthResult(
        success: false,
        message: 'Failed to change PIN: ${e.toString()}',
      );
    }
  }
  
  /// Check if user has specific permission
  static Future<bool> hasPermission(String permission) async {
    try {
      final accessCheck = await checkAdminAccess();
      if (!accessCheck.success) return false;
      
      final permissions = accessCheck.permissions ?? [];
      return permissions.contains('*') || permissions.contains(permission);
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }
  
  /// Validate session and check for timeout
  static Future<bool> validateSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // Check session timeout
      if (_lastActivity != null) {
        final timeSinceLastActivity = DateTime.now().difference(_lastActivity!);
        if (timeSinceLastActivity.inMinutes > _sessionTimeoutMinutes) {
          await signOut();
          return false;
        }
      }
      
      // Check if token is still valid
      final idTokenResult = await user.getIdTokenResult();
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      
      // Check if token is expired or close to expiry (within 5 minutes)
      if (idTokenResult.expirationTime!.millisecondsSinceEpoch / 1000 - now < 300) {
        // Refresh token
        await user.getIdToken(true);
      }
      
      _updateLastActivity();
      return true;
    } catch (e) {
      debugPrint('Session validation error: $e');
      return false;
    }
  }
  
  /// Get admin audit logs
  static Future<List<Map<String, dynamic>>> getAuditLogs({
    int limit = 100,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final result = await _functions.httpsCallable('getAdminAuditLogs').call({
        'limit': limit,
        'startAfter': startAfter?.id,
      });

      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['logs'] ?? []);
      } else {
        throw Exception(data['message'] ?? 'Failed to get audit logs');
      }

    } catch (e) {
      debugPrint('Error getting audit logs: $e');
      throw Exception('Failed to get audit logs: ${e.toString()}');
    }
  }

  /// Flag suspicious referral activities
  static Future<Map<String, dynamic>> flagSuspiciousReferrals() async {
    try {
      final result = await _functions.httpsCallable('flagSuspiciousReferrals').call();
      return result.data as Map<String, dynamic>;

    } catch (e) {
      debugPrint('Error flagging suspicious referrals: $e');
      throw Exception('Failed to flag suspicious referrals: ${e.toString()}');
    }
  }

  /// Moderate content (ban/unban users)
  static Future<AdminAuthResult> moderateContent({
    required String action,
    required String targetUid,
    String? reason,
    int? duration,
  }) async {
    try {
      final result = await _functions.httpsCallable('moderateContent').call({
        'action': action,
        'targetUid': targetUid,
        'reason': reason,
        'duration': duration,
      });

      final data = result.data as Map<String, dynamic>;
      
      return AdminAuthResult(
        success: data['success'] == true,
        message: data['message'] ?? 'Unknown error',
      );

    } catch (e) {
      debugPrint('Error moderating content: $e');
      return AdminAuthResult(
        success: false,
        message: 'Moderation failed: ${e.toString()}',
      );
    }
  }

  /// Bulk moderate users
  static Future<Map<String, dynamic>> bulkModerateUsers({
    required String action,
    required List<String> targetUids,
    String? reason,
  }) async {
    try {
      final result = await _functions.httpsCallable('bulkModerateUsers').call({
        'action': action,
        'targetUids': targetUids,
        'reason': reason,
      });

      return result.data as Map<String, dynamic>;

    } catch (e) {
      debugPrint('Error in bulk moderation: $e');
      throw Exception('Bulk moderation failed: ${e.toString()}');
    }
  }
  
  /// Sign out admin user
  static Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Log admin logout
        await _logAdminAction('admin_logout', {
          'uid': user.uid,
          'sessionDuration': _lastActivity != null 
              ? DateTime.now().difference(_lastActivity!).inMinutes 
              : 0,
        });
      }
      
      await _auth.signOut();
      _stopSessionMonitoring();
      _lastActivity = null;
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
  
  /// Get admin session info
  static Future<AdminSessionInfo?> getSessionInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final accessCheck = await checkAdminAccess();
      if (!accessCheck.success) return null;
      
      final remainingTime = _lastActivity != null
          ? _sessionTimeoutMinutes - DateTime.now().difference(_lastActivity!).inMinutes
          : _sessionTimeoutMinutes;
      
      return AdminSessionInfo(
        uid: user.uid,
        email: user.email,
        role: accessCheck.role!,
        region: accessCheck.region,
        permissions: accessCheck.permissions!,
        sessionRemainingMinutes: remainingTime > 0 ? remainingTime : 0,
        lastActivity: _lastActivity,
      );
    } catch (e) {
      debugPrint('Error getting session info: $e');
      return null;
    }
  }
  
  // Private helper methods
  static void _startSessionMonitoring() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_lastActivity != null) {
        final timeSinceLastActivity = DateTime.now().difference(_lastActivity!);
        if (timeSinceLastActivity.inMinutes > _sessionTimeoutMinutes) {
          signOut();
        }
      }
    });
  }
  
  static void _stopSessionMonitoring() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }
  
  static void _updateLastActivity() {
    _lastActivity = DateTime.now();
  }
  
  static Future<void> _ensureAdminConfig() async {
    try {
      final adminDoc = await _firestore.collection('admin_config').doc('credentials').get();
      
      if (!adminDoc.exists) {
        // Create default admin configuration
        await _firestore.collection('admin_config').doc('credentials').set({
          'phoneNumber': '+917981828388',
          'pinHash': _hashPin('1234'), // Default PIN
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'isActive': true,
          'maxAttempts': 5,
          'failedAttempts': 0,
        });
        
        debugPrint('Admin configuration initialized with default PIN: 1234');
      }
    } catch (e) {
      debugPrint('Error ensuring admin config: $e');
    }
  }
  
  static PinValidationResult _validatePinStrength(String pin) {
    if (pin.length < 4) {
      return PinValidationResult(false, 'PIN must be at least 4 digits');
    }
    
    if (pin.length > 8) {
      return PinValidationResult(false, 'PIN must be at most 8 digits');
    }
    
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return PinValidationResult(false, 'PIN must contain only numbers');
    }
    
    // Check for weak patterns
    if (pin == '1234' || pin == '0000' || pin == '1111') {
      return PinValidationResult(false, 'PIN is too weak. Avoid sequential or repeated digits');
    }
    
    // Check for repeated digits
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      return PinValidationResult(false, 'PIN cannot contain only repeated digits');
    }
    
    return PinValidationResult(true, 'PIN is valid');
  }
  
  static Future<bool> _checkPinHistory(String newPin) async {
    try {
      final historyDoc = await _firestore.collection('admin_config').doc('pin_history').get();
      if (!historyDoc.exists) return false;
      
      final history = historyDoc.data()!['history'] as List<dynamic>? ?? [];
      final newPinHash = _hashPin(newPin);
      
      return history.contains(newPinHash);
    } catch (e) {
      debugPrint('Error checking PIN history: $e');
      return false;
    }
  }
  
  static Future<void> _storePinHistory(String oldPin) async {
    try {
      final oldPinHash = _hashPin(oldPin);
      
      await _firestore.collection('admin_config').doc('pin_history').set({
        'history': FieldValue.arrayUnion([oldPinHash]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Keep only last 5 PINs in history
      final historyDoc = await _firestore.collection('admin_config').doc('pin_history').get();
      if (historyDoc.exists) {
        final history = historyDoc.data()!['history'] as List<dynamic>? ?? [];
        if (history.length > 5) {
          final trimmedHistory = history.sublist(history.length - 5);
          await _firestore.collection('admin_config').doc('pin_history').update({
            'history': trimmedHistory,
          });
        }
      }
    } catch (e) {
      debugPrint('Error storing PIN history: $e');
    }
  }
  
  static String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String normalized = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle different formats
    if (normalized.startsWith('91') && normalized.length == 12) {
      normalized = normalized.substring(2);
    } else if (normalized.startsWith('+91')) {
      normalized = normalized.substring(3);
    }
    
    // Ensure it's a 10-digit number and add country code
    if (normalized.length == 10 && normalized.startsWith(RegExp(r'[6-9]'))) {
      return '+91$normalized';
    }
    
    throw Exception('Invalid phone number format');
  }
  
  static String _hashPin(String pin) {
    // Use SHA-256 for PIN hashing with salt
    final bytes = utf8.encode('talowa_admin_salt_2024_$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  static Future<void> _updateLastLogin() async {
    try {
      await _firestore.collection('admin_config').doc('credentials').update({
        'lastLogin': FieldValue.serverTimestamp(),
        'lastLoginBy': _auth.currentUser?.uid,
      });
    } catch (e) {
      debugPrint('Error updating admin last login: $e');
    }
  }
  
  static Future<void> _logAdminAction(String action, Map<String, dynamic> details) async {
    try {
      await _firestore.collection('transparency_logs').add({
        'adminUid': _auth.currentUser?.uid,
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'immutable': true,
        'source': 'admin_auth_service',
      });
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }
}

class AdminAccessResult {
  final bool success;
  final String message;
  final String? role;
  final String? region;
  final List<String>? permissions;
  
  AdminAccessResult({
    required this.success,
    required this.message,
    this.role,
    this.region,
    this.permissions,
  });
}

class AdminAuthResult {
  final bool success;
  final String message;
  final String? role;
  final String? region;
  final List<String>? permissions;
  final bool isDefaultPin;
  final bool requiresPinChange;
  final bool requiresReauth;
  
  AdminAuthResult({
    required this.success,
    required this.message,
    this.role,
    this.region,
    this.permissions,
    this.isDefaultPin = false,
    this.requiresPinChange = false,
    this.requiresReauth = false,
  });
}

class AdminSessionInfo {
  final String uid;
  final String? email;
  final String role;
  final String? region;
  final List<String> permissions;
  final int sessionRemainingMinutes;
  final DateTime? lastActivity;
  
  AdminSessionInfo({
    required this.uid,
    this.email,
    required this.role,
    this.region,
    required this.permissions,
    required this.sessionRemainingMinutes,
    this.lastActivity,
  });
}

class PinValidationResult {
  final bool isValid;
  final String message;
  
  PinValidationResult(this.isValid, this.message);
}