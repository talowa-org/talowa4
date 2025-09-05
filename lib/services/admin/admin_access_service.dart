// Admin Access Service - Check if current user has admin privileges
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminAccessService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Check if current user is an admin
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // Check user document for admin role
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      
      // Check multiple admin indicators
      final role = userData['role'] as String?;
      final referralCode = userData['referralCode'] as String?;
      final isAdmin = userData['isAdmin'] as bool?;
      
      // Admin if:
      // 1. Role is admin or national_leadership
      // 2. Referral code is TALADMIN
      // 3. isAdmin flag is true
      return role == 'admin' || 
             role == 'national_leadership' ||
             referralCode == 'TALADMIN' ||
             isAdmin == true;
             
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }
  
  /// Get current user's role
  static Future<String?> getCurrentUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;
      
      final userData = userDoc.data()!;
      return userData['role'] as String?;
      
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }
  
  /// Check if user has coordinator privileges
  static Future<bool> isCurrentUserCoordinator() async {
    try {
      final role = await getCurrentUserRole();
      return role != null && role.contains('coordinator');
    } catch (e) {
      debugPrint('Error checking coordinator status: $e');
      return false;
    }
  }
}
