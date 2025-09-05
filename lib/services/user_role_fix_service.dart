// User Role Fix Service for TALOWA
// Ensures users have proper roles for security rules

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRoleFixService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fix current user's role if missing
  static Future<void> fixCurrentUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('âŒ No authenticated user found');
        return;
      }

      debugPrint('ðŸ”§ Checking user role for: ${user.uid}');
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        debugPrint('âŒ User document does not exist');
        return;
      }

      final userData = userDoc.data()!;
      final currentRole = userData['role'] as String?;
      
      debugPrint('ðŸ‘¤ Current user role: $currentRole');
      
      // If user has no role or invalid role, set a default role
      if (currentRole == null || !_isValidRole(currentRole)) {
        debugPrint('ðŸ”§ Fixing user role...');
        
        await _firestore.collection('users').doc(user.uid).update({
          'role': 'member', // Default role that allows basic access
          'role_updated_at': FieldValue.serverTimestamp(),
          'role_updated_by': 'system_auto_fix'
        });
        
        debugPrint('âœ… User role fixed to: member');
      } else {
        debugPrint('âœ… User role is valid: $currentRole');
      }
      
    } catch (e) {
      debugPrint('âŒ Error fixing user role: $e');
    }
  }

  /// Check if role is valid according to security rules
  static bool _isValidRole(String role) {
    const validRoles = [
      'member',
      'village_coordinator',
      'mandal_coordinator', 
      'district_coordinator',
      'state_coordinator',
      'national_leadership'
    ];
    
    return validRoles.contains(role);
  }

  /// Create missing collections with proper permissions
  static Future<void> createMissingCollectionsWithAuth() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('âŒ No authenticated user for collection creation');
        return;
      }

      debugPrint('ðŸ”§ Creating missing collections with proper auth...');

      // Create daily motivation with user context
      await _createDailyMotivationWithAuth(user.uid);
      
      // Create hashtags with user context
      await _createHashtagsWithAuth(user.uid);
      
      // Create analytics with user context
      await _createAnalyticsWithAuth(user.uid);
      
      debugPrint('âœ… Missing collections created successfully');
      
    } catch (e) {
      debugPrint('âŒ Error creating collections: $e');
      rethrow;
    }
  }

  static Future<void> _createDailyMotivationWithAuth(String userId) async {
    try {
      debugPrint('ðŸ“ Creating daily motivation with auth...');
      
      final motivationData = {
        'messages': [
          "à¤†à¤œ à¤à¤• à¤¨à¤¯à¤¾ à¤¦à¤¿à¤¨ à¤¹à¥ˆà¥¤ à¤…à¤ªà¤¨à¥€ à¤­à¥‚à¤®à¤¿ à¤•à¥‡ à¤²à¤¿à¤ à¤²à¤¡à¤¼à¤¤à¥‡ à¤°à¤¹à¥‡à¤‚à¥¤",
          "à¤à¤•à¤œà¥à¤Ÿ à¤¹à¥‹à¤•à¤° à¤¹à¤® à¤…à¤ªà¤¨à¥‡ à¤…à¤§à¤¿à¤•à¤¾à¤°à¥‹à¤‚ à¤•à¥‹ à¤ªà¤¾ à¤¸à¤•à¤¤à¥‡ à¤¹à¥ˆà¤‚à¥¤",
          "à¤¹à¤° à¤›à¥‹à¤Ÿà¤¾ à¤•à¤¦à¤® à¤¬à¤¡à¤¼à¥‡ à¤¬à¤¦à¤²à¤¾à¤µ à¤•à¥€ à¤¶à¥à¤°à¥à¤†à¤¤ à¤¹à¥ˆà¥¤",
          "à¤†à¤ªà¤•à¥€ à¤†à¤µà¤¾à¤œà¤¼ à¤®à¤¾à¤¯à¤¨à¥‡ à¤°à¤–à¤¤à¥€ à¤¹à¥ˆà¥¤ à¤¬à¥‹à¤²à¤¤à¥‡ à¤°à¤¹à¥‡à¤‚à¥¤",
          "à¤¨à¥à¤¯à¤¾à¤¯ à¤•à¥€ à¤²à¤¡à¤¼à¤¾à¤ˆ à¤®à¥‡à¤‚ à¤¹à¤® à¤¸à¤¾à¤¥ à¤¹à¥ˆà¤‚à¥¤"
        ],
        'success_stories': [
          {
            'title': "à¤•à¤°à¥€à¤®à¤¨à¤—à¤° à¤®à¥‡à¤‚ à¤­à¥‚à¤®à¤¿ à¤µà¤¾à¤ªà¤¸à¥€",
            'description': "à¤¸à¤¾à¤®à¥‚à¤¹à¤¿à¤• à¤ªà¥à¤°à¤¯à¤¾à¤¸ à¤¸à¥‡ à¤•à¤¿à¤¸à¤¾à¤¨à¥‹à¤‚ à¤•à¥‹ à¤…à¤ªà¤¨à¥€ à¤­à¥‚à¤®à¤¿ à¤µà¤¾à¤ªà¤¸ à¤®à¤¿à¤²à¥€à¥¤",
            'location': "à¤•à¤°à¥€à¤®à¤¨à¤—à¤°, à¤¤à¥‡à¤²à¤‚à¤—à¤¾à¤¨à¤¾",
            'date': "2024-01-15"
          }
        ],
        'created_by': userId,
        'created_at': FieldValue.serverTimestamp(),
        'last_updated': FieldValue.serverTimestamp()
      };

      await _firestore.collection('content').doc('daily_motivation').set(motivationData);
      debugPrint('âœ… Daily motivation created successfully');
      
    } catch (e) {
      debugPrint('âŒ Error creating daily motivation: $e');
      rethrow;
    }
  }

  static Future<void> _createHashtagsWithAuth(String userId) async {
    try {
      debugPrint('ðŸ·ï¸ Creating hashtags with auth...');
      
      final hashtags = [
        {'tag': 'à¤­à¥‚à¤®à¤¿à¤…à¤§à¤¿à¤•à¤¾à¤°', 'count': 0, 'category': 'land_rights'},
        {'tag': 'à¤•à¤¿à¤¸à¤¾à¤¨à¤¨à¥à¤¯à¤¾à¤¯', 'count': 0, 'category': 'farmer_justice'},
        {'tag': 'à¤¤à¥‡à¤²à¤‚à¤—à¤¾à¤¨à¤¾à¤•à¤¿à¤¸à¤¾à¤¨', 'count': 0, 'category': 'telangana_farmers'},
      ];

      final batch = _firestore.batch();
      for (int i = 0; i < hashtags.length; i++) {
        final ref = _firestore.collection('hashtags').doc('hashtag_${i + 1}');
        batch.set(ref, {
          ...hashtags[i],
          'created_by': userId,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp()
        });
      }

      await batch.commit();
      debugPrint('âœ… Hashtags created successfully');
      
    } catch (e) {
      debugPrint('âŒ Error creating hashtags: $e');
      rethrow;
    }
  }

  static Future<void> _createAnalyticsWithAuth(String userId) async {
    try {
      debugPrint('ðŸ“Š Creating analytics with auth...');
      
      final analyticsData = {
        'total_users': 1,
        'total_posts': 0,
        'total_stories': 0,
        'total_comments': 0,
        'total_likes': 0,
        'active_users_today': 1,
        'active_users_week': 1,
        'active_users_month': 1,
        'created_by': userId,
        'created_at': FieldValue.serverTimestamp(),
        'last_updated': FieldValue.serverTimestamp()
      };

      await _firestore.collection('analytics').doc('global_stats').set(analyticsData);
      debugPrint('âœ… Analytics created successfully');
      
    } catch (e) {
      debugPrint('âŒ Error creating analytics: $e');
      rethrow;
    }
  }

  /// Complete fix - role + collections
  static Future<void> performCompleteFix() async {
    try {
      debugPrint('ðŸ”§ Starting complete user and data fix...');
      
      // First fix the user role
      await fixCurrentUserRole();
      
      // Wait a moment for the role update to propagate
      await Future.delayed(const Duration(seconds: 2));
      
      // Then create missing collections
      await createMissingCollectionsWithAuth();
      
      debugPrint('âœ… Complete fix performed successfully!');
      
    } catch (e) {
      debugPrint('âŒ Error in complete fix: $e');
      rethrow;
    }
  }
}

