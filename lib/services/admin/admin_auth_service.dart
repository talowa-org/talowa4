// Admin Authentication Service - Dedicated admin login system
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AdminAuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Default admin credentials
  static const String _adminPhoneNumber = '+917981828388';
  static const String _defaultAdminPin = '1234'; // Default PIN
  
  /// Initialize admin user if not exists
  static Future<void> initializeAdminUser() async {
    try {
      final adminDoc = await _firestore.collection('admin_config').doc('credentials').get();
      
      if (!adminDoc.exists) {
        // Create default admin configuration
        await _firestore.collection('admin_config').doc('credentials').set({
          'phoneNumber': _adminPhoneNumber,
          'pinHash': _hashPin(_defaultAdminPin),
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'isActive': true,
        });
        
        debugPrint('Admin user initialized with default PIN: $_defaultAdminPin');
      }
    } catch (e) {
      debugPrint('Error initializing admin user: $e');
    }
  }
  
  /// Authenticate admin with phone number and PIN
  static Future<AdminAuthResult> authenticateAdmin({
    required String phoneNumber,
    required String pin,
  }) async {
    try {
      // Normalize phone number
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      
      // Check if it's the admin phone number
      if (normalizedPhone != _adminPhoneNumber) {
        return AdminAuthResult(
          success: false,
          message: 'Invalid admin phone number',
        );
      }
      
      // Get admin credentials from Firestore
      final adminDoc = await _firestore.collection('admin_config').doc('credentials').get();
      
      if (!adminDoc.exists) {
        // Initialize admin user if not exists
        await initializeAdminUser();
        
        // Try again with default PIN
        if (pin == _defaultAdminPin) {
          await _updateLastLogin();
          return AdminAuthResult(
            success: true,
            message: 'Admin login successful',
            isDefaultPin: true,
          );
        } else {
          return AdminAuthResult(
            success: false,
            message: 'Invalid PIN',
          );
        }
      }
      
      final adminData = adminDoc.data()!;
      final storedPinHash = adminData['pinHash'] as String;
      final isActive = adminData['isActive'] as bool? ?? true;
      
      if (!isActive) {
        return AdminAuthResult(
          success: false,
          message: 'Admin account is disabled',
        );
      }
      
      // Verify PIN
      final inputPinHash = _hashPin(pin);
      if (inputPinHash != storedPinHash) {
        return AdminAuthResult(
          success: false,
          message: 'Invalid PIN',
        );
      }
      
      // Update last login
      await _updateLastLogin();
      
      // Check if using default PIN
      final isDefaultPin = storedPinHash == _hashPin(_defaultAdminPin);
      
      return AdminAuthResult(
        success: true,
        message: 'Admin login successful',
        isDefaultPin: isDefaultPin,
      );
      
    } catch (e) {
      debugPrint('Admin authentication error: $e');
      return AdminAuthResult(
        success: false,
        message: 'Authentication failed: ${e.toString()}',
      );
    }
  }
  
  /// Change admin PIN
  static Future<AdminAuthResult> changeAdminPin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      // Verify current PIN first
      final authResult = await authenticateAdmin(
        phoneNumber: _adminPhoneNumber,
        pin: currentPin,
      );
      
      if (!authResult.success) {
        return AdminAuthResult(
          success: false,
          message: 'Current PIN is incorrect',
        );
      }
      
      // Validate new PIN
      if (newPin.length < 4) {
        return AdminAuthResult(
          success: false,
          message: 'PIN must be at least 4 digits',
        );
      }
      
      if (!RegExp(r'^\d+$').hasMatch(newPin)) {
        return AdminAuthResult(
          success: false,
          message: 'PIN must contain only numbers',
        );
      }
      
      // Update PIN in Firestore
      await _firestore.collection('admin_config').doc('credentials').update({
        'pinHash': _hashPin(newPin),
        'lastUpdated': FieldValue.serverTimestamp(),
        'pinChangedAt': FieldValue.serverTimestamp(),
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
  
  /// Reset admin PIN to default (emergency function)
  static Future<AdminAuthResult> resetAdminPin() async {
    try {
      await _firestore.collection('admin_config').doc('credentials').update({
        'pinHash': _hashPin(_defaultAdminPin),
        'lastUpdated': FieldValue.serverTimestamp(),
        'pinResetAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Admin PIN reset to default: $_defaultAdminPin');
      
      return AdminAuthResult(
        success: true,
        message: 'PIN reset to default: $_defaultAdminPin',
        isDefaultPin: true,
      );
      
    } catch (e) {
      debugPrint('Error resetting admin PIN: $e');
      return AdminAuthResult(
        success: false,
        message: 'Failed to reset PIN: ${e.toString()}',
      );
    }
  }
  
  /// Get admin info
  static Future<Map<String, dynamic>?> getAdminInfo() async {
    try {
      final adminDoc = await _firestore.collection('admin_config').doc('credentials').get();
      
      if (!adminDoc.exists) {
        return null;
      }
      
      final data = adminDoc.data()!;
      return {
        'phoneNumber': data['phoneNumber'],
        'isActive': data['isActive'] ?? true,
        'lastLogin': data['lastLogin'],
        'lastUpdated': data['lastUpdated'],
        'pinChangedAt': data['pinChangedAt'],
        'isDefaultPin': data['pinHash'] == _hashPin(_defaultAdminPin),
      };
      
    } catch (e) {
      debugPrint('Error getting admin info: $e');
      return null;
    }
  }
  
  /// Check if current user session is admin
  static Future<bool> isCurrentSessionAdmin() async {
    try {
      // For now, we'll use a simple session check
      // In a more complex system, you might store admin session tokens
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // Check if user has admin role in Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final role = userData['role'] as String?;
      
      return role == 'admin' || role == 'national_leadership';
      
    } catch (e) {
      debugPrint('Error checking admin session: $e');
      return false;
    }
  }
  
  // Private helper methods
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
    // Use SHA-256 for PIN hashing
    final bytes = utf8.encode('talowa_admin_$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  static Future<void> _updateLastLogin() async {
    try {
      await _firestore.collection('admin_config').doc('credentials').update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating admin last login: $e');
    }
  }
}

class AdminAuthResult {
  final bool success;
  final String message;
  final bool isDefaultPin;
  
  AdminAuthResult({
    required this.success,
    required this.message,
    this.isDefaultPin = false,
  });
}
