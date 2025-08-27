// Data Population Service for TALOWA
// Populates missing Firestore collections with initial data

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataPopulationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Populate all missing collections
  static Future<void> populateAllMissingData() async {
    try {
      debugPrint('🔄 Starting data population...');
      
      // Populate each collection independently, don't stop if one fails
      await populateDailyMotivation().catchError((e) => 
        debugPrint('❌ Daily motivation population failed: $e'));
      
      await populateHashtags().catchError((e) => 
        debugPrint('❌ Hashtags population failed: $e'));
      
      await populateAnalytics().catchError((e) => 
        debugPrint('❌ Analytics population failed: $e'));
      
      await populateNotifications().catchError((e) => 
        debugPrint('❌ Notifications population failed: $e'));
      
      await populateActiveStories().catchError((e) => 
        debugPrint('❌ Active stories population failed: $e'));
      
      debugPrint('✅ Data population completed (some operations may have failed)');
    } catch (e) {
      debugPrint('❌ Critical error in data population: $e');
      // Don't rethrow to prevent app crashes
      debugPrint('⚠️ Continuing app startup despite data population errors...');
    }
  }
  
  /// Populate active stories collection
  static Future<void> populateActiveStories() async {
    try {
      debugPrint('📖 Populating active stories...');
      
      // Check if active stories already exist
      final existingStories = await _firestore
          .collection('active_stories')
          .limit(1)
          .get();
      
      if (existingStories.docs.isNotEmpty) {
        debugPrint('✅ Active stories already exist, skipping...');
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
      
      debugPrint('✅ Active stories populated successfully!');
    } catch (e) {
      debugPrint('❌ Error populating active stories: $e');
    }
  }

  /// Populate daily motivation content
  static Future<void> populateDailyMotivation() async {
    try {
      debugPrint('📝 Populating daily motivation...');
      
      // Check if daily motivation already exists
      final existingMotivation = await _firestore
          .collection('daily_motivation')
          .limit(1)
          .get();
      
      if (existingMotivation.docs.isNotEmpty) {
        debugPrint('✅ Daily motivation already exists, skipping...');
        return;
      }
      
      final motivationData = {
        'id': 'daily_motivation_${DateTime.now().millisecondsSinceEpoch}',
        'messages': [
          "आज एक नया दिन है। अपनी भूमि के लिए लड़ते रहें। (Today is a new day. Keep fighting for your land.)",
          "एकजुट होकर हम अपने अधिकारों को पा सकते हैं। (United we can achieve our rights.)",
          "हर छोटा कदम बड़े बदलाव की शुरुआत है। (Every small step is the beginning of big change.)",
          "आपकी आवाज़ मायने रखती है। बोलते रहें। (Your voice matters. Keep speaking up.)",
          "न्याय की लड़ाई में हम साथ हैं। (We are together in the fight for justice.)",
          "भूमि हमारा अधिकार है, हम इसे पाकर रहेंगे। (Land is our right, we will get it.)",
          "संगठन में शक्ति है। एक साथ चलें। (There is strength in organization. Let's move together.)",
          "हमारे बच्चों के लिए एक बेहतर कल बनाएं। (Create a better tomorrow for our children.)",
          "कानूनी लड़ाई में धैर्य और दृढ़ता जरूरी है। (Patience and persistence are necessary in legal battles.)",
          "आपका संघर्ष व्यर्थ नहीं है। जारी रखें। (Your struggle is not in vain. Continue.)"
        ],
        'success_stories': [
          {
            'title': "करीमनगर में 500 एकड़ भूमि वापसी",
            'description': "सामूहिक प्रयास से किसानों को अपनी भूमि वापस मिली।",
            'location': "करीमनगर, तेलंगाना",
            'date': "2024-01-15"
          },
          {
            'title': "वारंगल में पट्टा वितरण",
            'description': "200 परिवारों को भूमि पट्टे मिले।",
            'location': "वारंगल, तेलंगाना",
            'date': "2024-02-20"
          },
          {
            'title': "निज़ामाबाद में न्यायालयी जीत",
            'description': "भूमि हड़पने के मामले में किसानों की जीत।",
            'location': "निज़ामाबाद, तेलंगाना",
            'date': "2024-03-10"
          }
        ],
        'last_updated': FieldValue.serverTimestamp()
      };

      // Try to write to daily_motivation collection first (has unauthenticated read)
      try {
        await _firestore.collection('daily_motivation').doc('current').set(motivationData);
        debugPrint('✅ Daily motivation populated successfully in daily_motivation collection!');
      } catch (e) {
        debugPrint('⚠️ Could not write to daily_motivation collection: $e');
        // Fallback: try content collection
        try {
          await _firestore.collection('content').doc('daily_motivation').set(motivationData);
          debugPrint('✅ Daily motivation populated successfully in content collection!');
        } catch (e2) {
          debugPrint('❌ Could not write to content collection either: $e2');
          // Don't rethrow - this is a background operation
        }
      }
    } catch (e) {
      debugPrint('❌ Error populating daily motivation: $e');
      // Don't rethrow - this is a background operation
    }
  }

  /// Populate hashtags collection
  static Future<void> populateHashtags() async {
    try {
      debugPrint('🏷️ Populating hashtags...');
      
      final hashtags = [
        {'tag': 'भूमिअधिकार', 'count': 0, 'category': 'land_rights'},
        {'tag': 'किसानन्याय', 'count': 0, 'category': 'farmer_justice'},
        {'tag': 'पट्टावितरण', 'count': 0, 'category': 'patta_distribution'},
        {'tag': 'तेलंगानाकिसान', 'count': 0, 'category': 'telangana_farmers'},
        {'tag': 'भूमिसंघर्ष', 'count': 0, 'category': 'land_struggle'},
        {'tag': 'न्यायालयीजीत', 'count': 0, 'category': 'court_victory'},
        {'tag': 'सामुदायिकशक्ति', 'count': 0, 'category': 'community_power'},
        {'tag': 'कृषिनीति', 'count': 0, 'category': 'agriculture_policy'},
        {'tag': 'ग्रामीणविकास', 'count': 0, 'category': 'rural_development'},
        {'tag': 'सामाजिकन्याय', 'count': 0, 'category': 'social_justice'}
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
      debugPrint('✅ Hashtags populated successfully!');
    } catch (e) {
      debugPrint('❌ Error populating hashtags: $e');
      // Don't rethrow - this is a background operation
    }
  }

  /// Populate analytics collection
  static Future<void> populateAnalytics() async {
    try {
      debugPrint('📊 Populating analytics...');
      
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
      debugPrint('✅ Analytics populated successfully!');
    } catch (e) {
      debugPrint('❌ Error populating analytics: $e');
      // Don't rethrow - this is a background operation
    }
  }

  /// Populate notifications collection structure
  static Future<void> populateNotifications() async {
    try {
      debugPrint('🔔 Populating notifications structure...');
      
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
      debugPrint('✅ Notifications structure populated successfully!');
    } catch (e) {
      debugPrint('❌ Error populating notifications: $e');
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
          debugPrint('✅ Daily motivation exists in daily_motivation collection');
        } else {
          debugPrint('📝 Daily motivation needs population');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ Could not check daily_motivation collection: $e');
        // Try content collection as fallback
        try {
          final motivationDoc = await _firestore.collection('content').doc('daily_motivation').get();
          if (motivationDoc.exists) {
            debugPrint('✅ Daily motivation exists in content collection');
          } else {
            debugPrint('📝 Daily motivation needs population');
            return true;
          }
        } catch (e2) {
          debugPrint('⚠️ Could not check content collection either: $e2');
          return true; // Assume we need population if we can't check
        }
      }

      // Check if hashtags exist
      try {
        final hashtagsSnapshot = await _firestore.collection('hashtags').limit(1).get();
        if (hashtagsSnapshot.docs.isNotEmpty) {
          debugPrint('✅ Hashtags exist');
        } else {
          debugPrint('🏷️ Hashtags need population');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ Could not check hashtags collection: $e');
        return true; // Assume we need population if we can't check
      }

      // Check if analytics exist
      try {
        final analyticsDoc = await _firestore.collection('analytics').doc('global_stats').get();
        if (analyticsDoc.exists) {
          debugPrint('✅ Analytics exist');
        } else {
          debugPrint('📊 Analytics need population');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ Could not check analytics collection: $e');
        return true; // Assume we need population if we can't check
      }

      debugPrint('✅ All required data already exists');
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
        debugPrint('🔄 Data population needed, starting...');
        await populateAllMissingData();
      } else {
        debugPrint('✅ Data already populated, skipping...');
      }
    } catch (e) {
      debugPrint('❌ Error in populateIfNeeded: $e');
      // Don't rethrow - this is a background operation
    }
  }
}
