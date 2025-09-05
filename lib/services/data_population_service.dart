// Data Population Service for TALOWA
// Populates missing Firestore collections with initial data

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataPopulationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Populate all missing collections
  static Future<void> populateAllMissingData() async {
    try {
      debugPrint('ðŸ”„ Starting data population...');
      
      // Populate each collection independently, don't stop if one fails
      await populateDailyMotivation().catchError((e) => 
        debugPrint('âŒ Daily motivation population failed: $e'));
      
      await populateHashtags().catchError((e) => 
        debugPrint('âŒ Hashtags population failed: $e'));
      
      await populateAnalytics().catchError((e) => 
        debugPrint('âŒ Analytics population failed: $e'));
      
      await populateNotifications().catchError((e) => 
        debugPrint('âŒ Notifications population failed: $e'));
      
      await populateActiveStories().catchError((e) => 
        debugPrint('âŒ Active stories population failed: $e'));
      
      debugPrint('âœ… Data population completed (some operations may have failed)');
    } catch (e) {
      debugPrint('âŒ Critical error in data population: $e');
      // Don't rethrow to prevent app crashes
      debugPrint('âš ï¸ Continuing app startup despite data population errors...');
    }
  }
  
  /// Populate active stories collection
  static Future<void> populateActiveStories() async {
    try {
      debugPrint('ðŸ“– Populating active stories...');
      
      // Check if active stories already exist
      final existingStories = await _firestore
          .collection('active_stories')
          .limit(1)
          .get();
      
      if (existingStories.docs.isNotEmpty) {
        debugPrint('âœ… Active stories already exist, skipping...');
        return;
      }
      
      final storiesData = {
        'id': 'active_stories_${DateTime.now().millisecondsSinceEpoch}',
        'stories': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection('active_stories')
          .doc('current')
          .set(storiesData);
      
      debugPrint('âœ… Active stories populated successfully!');
    } catch (e) {
      debugPrint('âŒ Error populating active stories: $e');
    }
  }

  /// Populate daily motivation content
  static Future<void> populateDailyMotivation() async {
    try {
      debugPrint('ðŸ“ Populating daily motivation...');
      
      // Check if daily motivation already exists
      final existingMotivation = await _firestore
          .collection('daily_motivation')
          .limit(1)
          .get();
      
      if (existingMotivation.docs.isNotEmpty) {
        debugPrint('âœ… Daily motivation already exists, skipping...');
        return;
      }
      
      final motivationData = {
        'id': 'daily_motivation_${DateTime.now().millisecondsSinceEpoch}',
        'messages': [
          "à¤†à¤œ à¤à¤• à¤¨à¤¯à¤¾ à¤¦à¤¿à¤¨ à¤¹à¥ˆà¥¤ à¤…à¤ªà¤¨à¥€ à¤­à¥‚à¤®à¤¿ à¤•à¥‡ à¤²à¤¿à¤ à¤²à¤¡à¤¼à¤¤à¥‡ à¤°à¤¹à¥‡à¤‚à¥¤ (Today is a new day. Keep fighting for your land.)",
          "à¤à¤•à¤œà¥à¤Ÿ à¤¹à¥‹à¤•à¤° à¤¹à¤® à¤…à¤ªà¤¨à¥‡ à¤…à¤§à¤¿à¤•à¤¾à¤°à¥‹à¤‚ à¤•à¥‹ à¤ªà¤¾ à¤¸à¤•à¤¤à¥‡ à¤¹à¥ˆà¤‚à¥¤ (United we can achieve our rights.)",
          "à¤¹à¤° à¤›à¥‹à¤Ÿà¤¾ à¤•à¤¦à¤® à¤¬à¤¡à¤¼à¥‡ à¤¬à¤¦à¤²à¤¾à¤µ à¤•à¥€ à¤¶à¥à¤°à¥à¤†à¤¤ à¤¹à¥ˆà¥¤ (Every small step is the beginning of big change.)",
          "à¤†à¤ªà¤•à¥€ à¤†à¤µà¤¾à¤œà¤¼ à¤®à¤¾à¤¯à¤¨à¥‡ à¤°à¤–à¤¤à¥€ à¤¹à¥ˆà¥¤ à¤¬à¥‹à¤²à¤¤à¥‡ à¤°à¤¹à¥‡à¤‚à¥¤ (Your voice matters. Keep speaking up.)",
          "à¤¨à¥à¤¯à¤¾à¤¯ à¤•à¥€ à¤²à¤¡à¤¼à¤¾à¤ˆ à¤®à¥‡à¤‚ à¤¹à¤® à¤¸à¤¾à¤¥ à¤¹à¥ˆà¤‚à¥¤ (We are together in the fight for justice.)",
          "à¤­à¥‚à¤®à¤¿ à¤¹à¤®à¤¾à¤°à¤¾ à¤…à¤§à¤¿à¤•à¤¾à¤° à¤¹à¥ˆ, à¤¹à¤® à¤‡à¤¸à¥‡ à¤ªà¤¾à¤•à¤° à¤°à¤¹à¥‡à¤‚à¤—à¥‡à¥¤ (Land is our right, we will get it.)",
          "à¤¸à¤‚à¤—à¤ à¤¨ à¤®à¥‡à¤‚ à¤¶à¤•à¥à¤¤à¤¿ à¤¹à¥ˆà¥¤ à¤à¤• à¤¸à¤¾à¤¥ à¤šà¤²à¥‡à¤‚à¥¤ (There is strength in organization. Let's move together.)",
          "à¤¹à¤®à¤¾à¤°à¥‡ à¤¬à¤šà¥à¤šà¥‹à¤‚ à¤•à¥‡ à¤²à¤¿à¤ à¤à¤• à¤¬à¥‡à¤¹à¤¤à¤° à¤•à¤² à¤¬à¤¨à¤¾à¤à¤‚à¥¤ (Create a better tomorrow for our children.)",
          "à¤•à¤¾à¤¨à¥‚à¤¨à¥€ à¤²à¤¡à¤¼à¤¾à¤ˆ à¤®à¥‡à¤‚ à¤§à¥ˆà¤°à¥à¤¯ à¤”à¤° à¤¦à¥ƒà¤¢à¤¼à¤¤à¤¾ à¤œà¤°à¥‚à¤°à¥€ à¤¹à¥ˆà¥¤ (Patience and persistence are necessary in legal battles.)",
          "à¤†à¤ªà¤•à¤¾ à¤¸à¤‚à¤˜à¤°à¥à¤· à¤µà¥à¤¯à¤°à¥à¤¥ à¤¨à¤¹à¥€à¤‚ à¤¹à¥ˆà¥¤ à¤œà¤¾à¤°à¥€ à¤°à¤–à¥‡à¤‚à¥¤ (Your struggle is not in vain. Continue.)"
        ],
        'success_stories': [
          {
            'title': "à¤•à¤°à¥€à¤®à¤¨à¤—à¤° à¤®à¥‡à¤‚ 500 à¤à¤•à¤¡à¤¼ à¤­à¥‚à¤®à¤¿ à¤µà¤¾à¤ªà¤¸à¥€",
            'description': "à¤¸à¤¾à¤®à¥‚à¤¹à¤¿à¤• à¤ªà¥à¤°à¤¯à¤¾à¤¸ à¤¸à¥‡ à¤•à¤¿à¤¸à¤¾à¤¨à¥‹à¤‚ à¤•à¥‹ à¤…à¤ªà¤¨à¥€ à¤­à¥‚à¤®à¤¿ à¤µà¤¾à¤ªà¤¸ à¤®à¤¿à¤²à¥€à¥¤",
            'location': "à¤•à¤°à¥€à¤®à¤¨à¤—à¤°, à¤¤à¥‡à¤²à¤‚à¤—à¤¾à¤¨à¤¾",
            'date': "2024-01-15"
          },
          {
            'title': "à¤µà¤¾à¤°à¤‚à¤—à¤² à¤®à¥‡à¤‚ à¤ªà¤Ÿà¥à¤Ÿà¤¾ à¤µà¤¿à¤¤à¤°à¤£",
            'description': "200 à¤ªà¤°à¤¿à¤µà¤¾à¤°à¥‹à¤‚ à¤•à¥‹ à¤­à¥‚à¤®à¤¿ à¤ªà¤Ÿà¥à¤Ÿà¥‡ à¤®à¤¿à¤²à¥‡à¥¤",
            'location': "à¤µà¤¾à¤°à¤‚à¤—à¤², à¤¤à¥‡à¤²à¤‚à¤—à¤¾à¤¨à¤¾",
            'date': "2024-02-20"
          },
          {
            'title': "à¤¨à¤¿à¤œà¤¼à¤¾à¤®à¤¾à¤¬à¤¾à¤¦ à¤®à¥‡à¤‚ à¤¨à¥à¤¯à¤¾à¤¯à¤¾à¤²à¤¯à¥€ à¤œà¥€à¤¤",
            'description': "à¤­à¥‚à¤®à¤¿ à¤¹à¤¡à¤¼à¤ªà¤¨à¥‡ à¤•à¥‡ à¤®à¤¾à¤®à¤²à¥‡ à¤®à¥‡à¤‚ à¤•à¤¿à¤¸à¤¾à¤¨à¥‹à¤‚ à¤•à¥€ à¤œà¥€à¤¤à¥¤",
            'location': "à¤¨à¤¿à¤œà¤¼à¤¾à¤®à¤¾à¤¬à¤¾à¤¦, à¤¤à¥‡à¤²à¤‚à¤—à¤¾à¤¨à¤¾",
            'date': "2024-03-10"
          }
        ],
        'last_updated': FieldValue.serverTimestamp()
      };

      // Try to write to daily_motivation collection first (has unauthenticated read)
      try {
        await _firestore.collection('daily_motivation').doc('current').set(motivationData);
        debugPrint('âœ… Daily motivation populated successfully in daily_motivation collection!');
      } catch (e) {
        debugPrint('âš ï¸ Could not write to daily_motivation collection: $e');
        // Fallback: try content collection
        try {
          await _firestore.collection('content').doc('daily_motivation').set(motivationData);
          debugPrint('âœ… Daily motivation populated successfully in content collection!');
        } catch (e2) {
          debugPrint('âŒ Could not write to content collection either: $e2');
          // Don't rethrow - this is a background operation
        }
      }
    } catch (e) {
      debugPrint('âŒ Error populating daily motivation: $e');
      // Don't rethrow - this is a background operation
    }
  }

  /// Populate hashtags collection
  static Future<void> populateHashtags() async {
    try {
      debugPrint('ðŸ·ï¸ Populating hashtags...');
      
      final hashtags = [
        {'tag': 'à¤­à¥‚à¤®à¤¿à¤…à¤§à¤¿à¤•à¤¾à¤°', 'count': 0, 'category': 'land_rights'},
        {'tag': 'à¤•à¤¿à¤¸à¤¾à¤¨à¤¨à¥à¤¯à¤¾à¤¯', 'count': 0, 'category': 'farmer_justice'},
        {'tag': 'à¤ªà¤Ÿà¥à¤Ÿà¤¾à¤µà¤¿à¤¤à¤°à¤£', 'count': 0, 'category': 'patta_distribution'},
        {'tag': 'à¤¤à¥‡à¤²à¤‚à¤—à¤¾à¤¨à¤¾à¤•à¤¿à¤¸à¤¾à¤¨', 'count': 0, 'category': 'telangana_farmers'},
        {'tag': 'à¤­à¥‚à¤®à¤¿à¤¸à¤‚à¤˜à¤°à¥à¤·', 'count': 0, 'category': 'land_struggle'},
        {'tag': 'à¤¨à¥à¤¯à¤¾à¤¯à¤¾à¤²à¤¯à¥€à¤œà¥€à¤¤', 'count': 0, 'category': 'court_victory'},
        {'tag': 'à¤¸à¤¾à¤®à¥à¤¦à¤¾à¤¯à¤¿à¤•à¤¶à¤•à¥à¤¤à¤¿', 'count': 0, 'category': 'community_power'},
        {'tag': 'à¤•à¥ƒà¤·à¤¿à¤¨à¥€à¤¤à¤¿', 'count': 0, 'category': 'agriculture_policy'},
        {'tag': 'à¤—à¥à¤°à¤¾à¤®à¥€à¤£à¤µà¤¿à¤•à¤¾à¤¸', 'count': 0, 'category': 'rural_development'},
        {'tag': 'à¤¸à¤¾à¤®à¤¾à¤œà¤¿à¤•à¤¨à¥à¤¯à¤¾à¤¯', 'count': 0, 'category': 'social_justice'}
      ];

      final batch = _firestore.batch();
      for (int i = 0; i < hashtags.length; i++) {
        final ref = _firestore.collection('hashtags').doc('hashtag_${i + 1}');
        batch.set(ref, {
          ...hashtags[i],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp()
        });
      }

      await batch.commit();
      debugPrint('âœ… Hashtags populated successfully!');
    } catch (e) {
      debugPrint('âŒ Error populating hashtags: $e');
      // Don't rethrow - this is a background operation
    }
  }

  /// Populate analytics collection
  static Future<void> populateAnalytics() async {
    try {
      debugPrint('ðŸ“Š Populating analytics...');
      
      final analyticsData = {
        'total_users': 0,
        'total_posts': 0,
        'total_stories': 0,
        'total_comments': 0,
        'total_likes': 0,
        'active_users_today': 0,
        'active_users_week': 0,
        'active_users_month': 0,
        'last_updated': FieldValue.serverTimestamp()
      };

      await _firestore.collection('analytics').doc('global_stats').set(analyticsData);
      debugPrint('âœ… Analytics populated successfully!');
    } catch (e) {
      debugPrint('âŒ Error populating analytics: $e');
      // Don't rethrow - this is a background operation
    }
  }

  /// Populate notifications collection structure
  static Future<void> populateNotifications() async {
    try {
      debugPrint('ðŸ”” Populating notifications structure...');
      
      // Create a sample notification structure document
      final notificationStructure = {
        'types': [
          'post_like',
          'post_comment',
          'story_view',
          'new_follower',
          'emergency_alert',
          'system_announcement'
        ],
        'settings': {
          'default_enabled': true,
          'sound_enabled': true,
          'vibration_enabled': true
        },
        'last_updated': FieldValue.serverTimestamp()
      };

      await _firestore.collection('notifications').doc('_structure').set(notificationStructure);
      debugPrint('âœ… Notifications structure populated successfully!');
    } catch (e) {
      debugPrint('âŒ Error populating notifications: $e');
      // Don't rethrow - this is a background operation
    }
  }

  /// Check if data needs to be populated
  static Future<bool> needsDataPopulation() async {
    try {
      // Check if daily motivation exists
      try {
        final motivationDoc = await _firestore.collection('daily_motivation').doc('current').get();
        if (motivationDoc.exists) {
          debugPrint('âœ… Daily motivation exists in daily_motivation collection');
        } else {
          debugPrint('ðŸ“ Daily motivation needs population');
          return true;
        }
      } catch (e) {
        debugPrint('âš ï¸ Could not check daily_motivation collection: $e');
        // Try content collection as fallback
        try {
          final motivationDoc = await _firestore.collection('content').doc('daily_motivation').get();
          if (motivationDoc.exists) {
            debugPrint('âœ… Daily motivation exists in content collection');
          } else {
            debugPrint('ðŸ“ Daily motivation needs population');
            return true;
          }
        } catch (e2) {
          debugPrint('âš ï¸ Could not check content collection either: $e2');
          return true; // Assume we need population if we can't check
        }
      }

      // Check if hashtags exist
      try {
        final hashtagsSnapshot = await _firestore.collection('hashtags').limit(1).get();
        if (hashtagsSnapshot.docs.isNotEmpty) {
          debugPrint('âœ… Hashtags exist');
        } else {
          debugPrint('ðŸ·ï¸ Hashtags need population');
          return true;
        }
      } catch (e) {
        debugPrint('âš ï¸ Could not check hashtags collection: $e');
        return true; // Assume we need population if we can't check
      }

      // Check if analytics exist
      try {
        final analyticsDoc = await _firestore.collection('analytics').doc('global_stats').get();
        if (analyticsDoc.exists) {
          debugPrint('âœ… Analytics exist');
        } else {
          debugPrint('ðŸ“Š Analytics need population');
          return true;
        }
      } catch (e) {
        debugPrint('âš ï¸ Could not check analytics collection: $e');
        return true; // Assume we need population if we can't check
      }

      debugPrint('âœ… All required data already exists');
      return false;
    } catch (e) {
      debugPrint('Error checking data population needs: $e');
      return true; // Assume we need population if we can't check
    }
  }

  /// Populate data if needed (safe to call multiple times)
  static Future<void> populateIfNeeded() async {
    try {
      final needsPopulation = await needsDataPopulation();
      if (needsPopulation) {
        debugPrint('ðŸ”„ Data population needed, starting...');
        await populateAllMissingData();
      } else {
        debugPrint('âœ… Data already populated, skipping...');
      }
    } catch (e) {
      debugPrint('âŒ Error in populateIfNeeded: $e');
      // Don't rethrow - this is a background operation
    }
  }
}

