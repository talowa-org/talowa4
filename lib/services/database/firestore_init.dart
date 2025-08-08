// Firestore Database Initialization for TALOWA Social Feed System
// Sets up initial collections, documents, and data structure

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreInit {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize the database with required collections and initial data
  static Future<void> initializeDatabase() async {
    try {
      debugPrint('FirestoreInit: Starting database initialization');

      // Create initial collections with sample documents
      await _createInitialCollections();
      
      // Set up trending hashtags collection
      await _initializeTrendingHashtags();
      
      // Create system notifications
      await _createSystemNotifications();
      
      // Initialize analytics collections
      await _initializeAnalytics();

      debugPrint('FirestoreInit: Database initialization completed');
      
    } catch (e) {
      debugPrint('FirestoreInit: Error initializing database: $e');
      rethrow;
    }
  }

  /// Create initial collections with proper structure
  static Future<void> _createInitialCollections() async {
    try {
      debugPrint('FirestoreInit: Creating initial collections');

      // Create posts collection with sample post
      await _createSamplePost();
      
      // Create hashtags collection
      await _createHashtagsCollection();
      
      // Create reports collection structure
      await _createReportsCollection();

      debugPrint('FirestoreInit: Initial collections created');
      
    } catch (e) {
      debugPrint('FirestoreInit: Error creating initial collections: $e');
      rethrow;
    }
  }

  /// Create a sample post to establish collection structure
  static Future<void> _createSamplePost() async {
    try {
      // Check if posts collection already has documents
      final existingPosts = await _firestore.collection('posts').limit(1).get();
      if (existingPosts.docs.isNotEmpty) {
        debugPrint('FirestoreInit: Posts collection already exists');
        return;
      }

      // Create sample post
      final samplePost = {
        'authorId': 'system',
        'authorName': 'TALOWA System',
        'authorRole': 'system_admin',
        'authorAvatarUrl': null,
        'content': 'Welcome to TALOWA Social Feed! Share your land rights stories, connect with your community, and stay informed about important updates. #Welcome #LandRights #Community',
        'imageUrls': <String>[],
        'documentUrls': <String>[],
        'hashtags': ['Welcome', 'LandRights', 'Community'],
        'category': 'announcement',
        'targeting': {
          'village': null,
          'mandal': null,
          'district': null,
          'state': null,
          'scope': 'national',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'viewsCount': 0,
        'isReported': false,
        'isHidden': false,
        'moderationReason': null,
        'moderatedAt': null,
        'moderatedBy': null,
        'visibility': 'public',
        'allowedRoles': <String>[],
        'allowedLocations': <String>[],
        'isPinned': true,
        'isEmergency': false,
      };

      final postRef = await _firestore.collection('posts').add(samplePost);
      
      // Create sample engagement document
      await postRef.collection('engagement').doc('sample').set({
        'userId': 'sample',
        'postId': postRef.id,
        'liked': false,
        'shared': false,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('FirestoreInit: Sample post created');
      
    } catch (e) {
      debugPrint('FirestoreInit: Error creating sample post: $e');
    }
  }

  /// Initialize hashtags collection for trending hashtags
  static Future<void> _createHashtagsCollection() async {
    try {
      // Check if hashtags collection exists
      final existingHashtags = await _firestore.collection('hashtags').limit(1).get();
      if (existingHashtags.docs.isNotEmpty) {
        debugPrint('FirestoreInit: Hashtags collection already exists');
        return;
      }

      // Create initial hashtags
      final initialHashtags = [
        {
          'tag': 'LandRights',
          'count': 1,
          'lastUsed': FieldValue.serverTimestamp(),
          'category': 'landRights',
        },
        {
          'tag': 'Community',
          'count': 1,
          'lastUsed': FieldValue.serverTimestamp(),
          'category': 'community',
        },
        {
          'tag': 'Welcome',
          'count': 1,
          'lastUsed': FieldValue.serverTimestamp(),
          'category': 'general',
        },
      ];

      for (final hashtag in initialHashtags) {
        await _firestore.collection('hashtags').doc(hashtag['tag'] as String).set(hashtag);
      }

      debugPrint('FirestoreInit: Hashtags collection created');
      
    } catch (e) {
      debugPrint('FirestoreInit: Error creating hashtags collection: $e');
    }
  }

  /// Create reports collection structure
  static Future<void> _createReportsCollection() async {
    try {
      // Create a sample report document to establish structure
      await _firestore.collection('reports').doc('sample').set({
        'reporterId': 'sample',
        'reporterName': 'Sample User',
        'contentType': 'post', // post, comment
        'contentId': 'sample_post_id',
        'reason': 'inappropriate_content',
        'description': 'Sample report for collection structure',
        'status': 'pending', // pending, reviewed, resolved, dismissed
        'createdAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
        'resolution': null,
      });

      debugPrint('FirestoreInit: Reports collection created');
      
    } catch (e) {
      debugPrint('FirestoreInit: Error creating reports collection: $e');
    }
  }

  /// Initialize trending hashtags with sample data
  static Future<void> _initializeTrendingHashtags() async {
    try {
      // Create trending hashtags document
      await _firestore.collection('analytics').doc('trending_hashtags').set({
        'hashtags': [
          {
            'tag': 'LandRights',
            'count': 1,
            'score': 1.0,
          },
          {
            'tag': 'Community',
            'count': 1,
            'score': 0.8,
          },
        ],
        'lastUpdated': FieldValue.serverTimestamp(),
        'period': 'weekly',
      });

      debugPrint('FirestoreInit: Trending hashtags initialized');
      
    } catch (e) {
      debugPrint('FirestoreInit: Error initializing trending hashtags: $e');
    }
  }

  /// Create system notifications
  static Future<void> _createSystemNotifications() async {
    try {
      // Create a sample notification structure
      await _firestore.collection('notifications').doc('sample').set({
        'recipientId': 'sample_user',
        'actorId': 'system',
        'actorName': 'TALOWA System',
        'actorAvatarUrl': null,
        'type': 'system_announcement',
        'message': 'Welcome to TALOWA! Start connecting with your community.',
        'postId': null,
        'commentId': null,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('FirestoreInit: System notifications created');
      
    } catch (e) {
      debugPrint('FirestoreInit: Error creating system notifications: $e');
    }
  }

  /// Initialize analytics collections
  static Future<void> _initializeAnalytics() async {
    try {
      // Create daily analytics document
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      await _firestore.collection('analytics').doc('daily_stats').collection('dates').doc(dateKey).set({
        'date': dateKey,
        'postsCreated': 1,
        'commentsCreated': 0,
        'likesGiven': 0,
        'sharesGiven': 0,
        'activeUsers': 0,
        'newUsers': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create overall statistics
      await _firestore.collection('analytics').doc('overall_stats').set({
        'totalPosts': 1,
        'totalComments': 0,
        'totalUsers': 0,
        'totalEngagements': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint('FirestoreInit: Analytics collections initialized');
      
    } catch (e) {
      debugPrint('FirestoreInit: Error initializing analytics: $e');
    }
  }

  /// Verify database structure
  static Future<bool> verifyDatabaseStructure() async {
    try {
      debugPrint('FirestoreInit: Verifying database structure');

      // Check if required collections exist
      final collections = ['posts', 'users', 'notifications', 'hashtags', 'reports', 'analytics'];
      
      for (final collection in collections) {
        final snapshot = await _firestore.collection(collection).limit(1).get();
        if (snapshot.docs.isEmpty) {
          debugPrint('FirestoreInit: Collection $collection is empty or missing');
          return false;
        }
      }

      // Check if posts have proper subcollections
      final postsSnapshot = await _firestore.collection('posts').limit(1).get();
      if (postsSnapshot.docs.isNotEmpty) {
        final postId = postsSnapshot.docs.first.id;
        
        // Check engagement subcollection
        final engagementSnapshot = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('engagement')
            .limit(1)
            .get();
            
        if (engagementSnapshot.docs.isEmpty) {
          debugPrint('FirestoreInit: Engagement subcollection missing');
          return false;
        }
      }

      debugPrint('FirestoreInit: Database structure verified successfully');
      return true;
      
    } catch (e) {
      debugPrint('FirestoreInit: Error verifying database structure: $e');
      return false;
    }
  }

  /// Clean up sample data (for testing)
  static Future<void> cleanupSampleData() async {
    try {
      debugPrint('FirestoreInit: Cleaning up sample data');

      // Delete sample documents
      await _firestore.collection('posts').doc('sample').delete();
      await _firestore.collection('notifications').doc('sample').delete();
      await _firestore.collection('reports').doc('sample').delete();

      debugPrint('FirestoreInit: Sample data cleaned up');
      
    } catch (e) {
      debugPrint('FirestoreInit: Error cleaning up sample data: $e');
    }
  }

  /// Get database statistics
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      debugPrint('FirestoreInit: Getting database statistics');

      final stats = <String, dynamic>{};

      // Count documents in each collection
      final collections = ['posts', 'users', 'notifications', 'hashtags', 'reports'];
      
      for (final collection in collections) {
        try {
          final snapshot = await _firestore.collection(collection).get();
          stats['${collection}Count'] = snapshot.docs.length;
        } catch (e) {
          stats['${collection}Count'] = 0;
        }
      }

      // Get overall analytics if available
      try {
        final analyticsDoc = await _firestore.collection('analytics').doc('overall_stats').get();
        if (analyticsDoc.exists) {
          final data = analyticsDoc.data() as Map<String, dynamic>;
          stats.addAll(data);
        }
      } catch (e) {
        debugPrint('FirestoreInit: Error getting analytics: $e');
      }

      return stats;
      
    } catch (e) {
      debugPrint('FirestoreInit: Error getting database stats: $e');
      return {};
    }
  }
}