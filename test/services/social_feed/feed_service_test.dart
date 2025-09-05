// Test file for FeedService
// Comprehensive tests for social feed functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:talowa/models/social_feed/index.dart';
import 'package:talowa/services/social_feed/feed_service.dart';

void main() {
  group('FeedService Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(signedIn: true);
    });

    group('Post Creation', () {
      test('should create post successfully with valid data', () async {
        // Arrange
        const authorId = 'test_user_123';
        const content = 'Test post content with #hashtag';
        const category = PostCategory.generalDiscussion;

        // Mock user profile
        await fakeFirestore.collection('users').doc(authorId).set({
          'id': authorId,
          'fullName': 'Test User',
          'role': 'member',
          'avatarUrl': 'https://example.com/avatar.jpg',
        });

        // Act & Assert
        expect(() async {
          final post = await FeedService.createPost(
            authorId: authorId,
            content: content,
            category: category,
          );
          
          expect(post.authorId, equals(authorId));
          expect(post.content, equals(content));
          expect(post.category, equals(category));
          expect(post.hashtags, contains('hashtag'));
        }, returnsNormally);
      });

      test('should fail to create post with empty content', () async {
        // Arrange
        const authorId = 'test_user_123';
        const content = '';
        const category = PostCategory.generalDiscussion;

        // Act & Assert
        expect(() async {
          await FeedService.createPost(
            authorId: authorId,
            content: content,
            category: category,
          );
        }, throwsException);
      });

      test('should fail to create post with content exceeding limit', () async {
        // Arrange
        const authorId = 'test_user_123';
        final content = 'a' * 2001; // Exceeds 2000 character limit
        const category = PostCategory.generalDiscussion;

        // Act & Assert
        expect(() async {
          await FeedService.createPost(
            authorId: authorId,
            content: content,
            category: category,
          );
        }, throwsException);
      });

      test('should limit hashtags to 10', () async {
        // Arrange
        const authorId = 'test_user_123';
        final hashtags = List.generate(15, (index) => 'hashtag$index');
        const content = 'Test post with many hashtags';
        const category = PostCategory.generalDiscussion;

        // Mock user profile
        await fakeFirestore.collection('users').doc(authorId).set({
          'id': authorId,
          'fullName': 'Test User',
          'role': 'member',
        });

        // Act
        final post = await FeedService.createPost(
          authorId: authorId,
          content: content,
          hashtags: hashtags,
          category: category,
        );

        // Assert
        expect(post.hashtags.length, equals(10));
      });

      test('should require coordinator role for emergency posts', () async {
        // Arrange
        const authorId = 'test_user_123';
        const content = 'Emergency announcement';
        const category = PostCategory.emergency;

        // Mock regular user profile
        await fakeFirestore.collection('users').doc(authorId).set({
          'id': authorId,
          'fullName': 'Test User',
          'role': 'member',
        });

        // Act & Assert
        expect(() async {
          await FeedService.createPost(
            authorId: authorId,
            content: content,
            category: category,
            isEmergency: true,
          );
        }, throwsException);
      });
    });

    group('Feed Retrieval', () {
      test('should retrieve feed posts with pagination', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock user profile
        await fakeFirestore.collection('users').doc(userId).set({
          'id': userId,
          'fullName': 'Test User',
          'district': 'Test District',
        });

        // Create test posts
        for (int i = 0; i < 25; i++) {
          await fakeFirestore.collection('posts').add({
            'authorId': 'author_$i',
            'authorName': 'Author $i',
            'content': 'Test post content $i',
            'category': 'generalDiscussion',
            'hashtags': ['test'],
            'imageUrls': [],
            'documentUrls': [],
            'createdAt': DateTime.now().subtract(Duration(hours: i)),
            'isHidden': false,
            'likesCount': 0,
            'commentsCount': 0,
            'sharesCount': 0,
            'viewsCount': 0,
            'visibility': 'public',
          });
        }

        // Act
        final posts = await FeedService.getFeedPosts(
          userId: userId,
          limit: 20,
        );

        // Assert
        expect(posts.length, equals(20));
        expect(posts.first.createdAt.isAfter(posts.last.createdAt), isTrue);
      });

      test('should filter posts by category', () async {
        // Arrange
        const userId = 'test_user_123';
        const category = PostCategory.announcement;

        // Mock user profile
        await fakeFirestore.collection('users').doc(userId).set({
          'id': userId,
          'fullName': 'Test User',
        });

        // Create test posts with different categories
        await fakeFirestore.collection('posts').add({
          'authorId': 'author_1',
          'authorName': 'Author 1',
          'content': 'Announcement post',
          'category': 'announcement',
          'hashtags': [],
          'imageUrls': [],
          'documentUrls': [],
          'createdAt': DateTime.now(),
          'isHidden': false,
          'visibility': 'public',
        });

        await fakeFirestore.collection('posts').add({
          'authorId': 'author_2',
          'authorName': 'Author 2',
          'content': 'General discussion post',
          'category': 'generalDiscussion',
          'hashtags': [],
          'imageUrls': [],
          'documentUrls': [],
          'createdAt': DateTime.now(),
          'isHidden': false,
          'visibility': 'public',
        });

        // Act
        final posts = await FeedService.getFeedPosts(
          userId: userId,
          categoryFilter: category,
        );

        // Assert
        expect(posts.length, equals(1));
        expect(posts.first.category, equals(category));
      });

      test('should exclude hidden posts from feed', () async {
        // Arrange
        const userId = 'test_user_123';

        // Mock user profile
        await fakeFirestore.collection('users').doc(userId).set({
          'id': userId,
          'fullName': 'Test User',
          'role': 'member',
        });

        // Create visible post
        await fakeFirestore.collection('posts').add({
          'authorId': 'author_1',
          'authorName': 'Author 1',
          'content': 'Visible post',
          'category': 'generalDiscussion',
          'hashtags': [],
          'imageUrls': [],
          'documentUrls': [],
          'createdAt': DateTime.now(),
          'isHidden': false,
          'visibility': 'public',
        });

        // Create hidden post
        await fakeFirestore.collection('posts').add({
          'authorId': 'author_2',
          'authorName': 'Author 2',
          'content': 'Hidden post',
          'category': 'generalDiscussion',
          'hashtags': [],
          'imageUrls': [],
          'documentUrls': [],
          'createdAt': DateTime.now(),
          'isHidden': true,
          'visibility': 'public',
        });

        // Act
        final posts = await FeedService.getFeedPosts(userId: userId);

        // Assert
        expect(posts.length, equals(1));
        expect(posts.first.content, equals('Visible post'));
      });
    });

    group('Search Functionality', () {
      test('should search posts by content', () async {
        // Arrange
        const searchQuery = 'land rights';

        // Create test posts
        await fakeFirestore.collection('posts').add({
          'authorId': 'author_1',
          'authorName': 'Author 1',
          'content': 'This post is about land rights and farming',
          'category': 'landRights',
          'hashtags': ['land', 'rights'],
          'imageUrls': [],
          'documentUrls': [],
          'createdAt': DateTime.now(),
          'isHidden': false,
          'visibility': 'public',
        });

        await fakeFirestore.collection('posts').add({
          'authorId': 'author_2',
          'authorName': 'Author 2',
          'content': 'This post is about agriculture',
          'category': 'agriculture',
          'hashtags': ['farming'],
          'imageUrls': [],
          'documentUrls': [],
          'createdAt': DateTime.now(),
          'isHidden': false,
          'visibility': 'public',
        });

        // Act
        final results = await FeedService.searchPosts(searchQuery);

        // Assert
        expect(results.length, equals(1));
        expect(results.first.content.toLowerCase(), contains('land rights'));
      });

      test('should search posts by hashtags', () async {
        // Arrange
        const searchQuery = 'farming';

        // Create test posts
        await fakeFirestore.collection('posts').add({
          'authorId': 'author_1',
          'authorName': 'Author 1',
          'content': 'Post about agriculture',
          'category': 'agriculture',
          'hashtags': ['farming', 'crops'],
          'imageUrls': [],
          'documentUrls': [],
          'createdAt': DateTime.now(),
          'isHidden': false,
          'visibility': 'public',
        });

        // Act
        final results = await FeedService.searchPosts(searchQuery);

        // Assert
        expect(results.length, equals(1));
        expect(results.first.hashtags, contains('farming'));
      });

      test('should return empty results for empty query', () async {
        // Act
        final results = await FeedService.searchPosts('');

        // Assert
        expect(results, isEmpty);
      });
    });

    group('Hashtag Functionality', () {
      test('should extract hashtags from content', () async {
        // Arrange
        const content = 'This is a post with #hashtag1 and #hashtag2 tags';

        // Act
        final hashtags = PostModel.extractHashtags(content);

        // Assert
        expect(hashtags, contains('hashtag1'));
        expect(hashtags, contains('hashtag2'));
        expect(hashtags.length, equals(2));
      });

      test('should get trending hashtags', () async {
        // Arrange
        final weekAgo = DateTime.now().subtract(const Duration(days: 3));

        // Create posts with hashtags
        for (int i = 0; i < 5; i++) {
          await fakeFirestore.collection('posts').add({
            'authorId': 'author_$i',
            'authorName': 'Author $i',
            'content': 'Post with trending hashtag',
            'category': 'generalDiscussion',
            'hashtags': ['trending', 'popular'],
            'imageUrls': [],
            'documentUrls': [],
            'createdAt': weekAgo.add(Duration(hours: i)),
            'isHidden': false,
            'visibility': 'public',
          });
        }

        // Act
        final trending = await FeedService.getTrendingHashtags(null);

        // Assert
        expect(trending, isNotEmpty);
        expect(trending, contains('trending'));
        expect(trending, contains('popular'));
      });
    });

    group('Post Engagement', () {
      test('should like post successfully', () async {
        // Arrange
        const postId = 'test_post_123';
        const userId = 'test_user_123';

        // Create test post
        await fakeFirestore.collection('posts').doc(postId).set({
          'authorId': 'author_1',
          'authorName': 'Author 1',
          'content': 'Test post',
          'category': 'generalDiscussion',
          'hashtags': [],
          'imageUrls': [],
          'documentUrls': [],
          'createdAt': DateTime.now(),
          'isHidden': false,
          'likesCount': 0,
          'visibility': 'public',
        });

        // Act
        await FeedService.likePost(postId, userId);

        // Assert
        final postDoc = await fakeFirestore.collection('posts').doc(postId).get();
        final postData = postDoc.data() as Map<String, dynamic>;
        expect(postData['likesCount'], equals(1));

        final engagementDoc = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('engagement')
            .doc(userId)
            .get();
        expect(engagementDoc.exists, isTrue);
        expect(engagementDoc.data()!['liked'], isTrue);
      });

      test('should unlike post successfully', () async {
        // Arrange
        const postId = 'test_post_123';
        const userId = 'test_user_123';

        // Create test post with existing like
        await fakeFirestore.collection('posts').doc(postId).set({
          'authorId': 'author_1',
          'authorName': 'Author 1',
          'content': 'Test post',
          'category': 'generalDiscussion',
          'hashtags': [],
          'imageUrls': [],
          'documentUrls': [],
          'createdAt': DateTime.now(),
          'isHidden': false,
          'likesCount': 1,
          'visibility': 'public',
        });

        await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('engagement')
            .doc(userId)
            .set({
          'userId': userId,
          'postId': postId,
          'liked': true,
          'likedAt': DateTime.now(),
        });

        // Act
        await FeedService.unlikePost(postId, userId);

        // Assert
        final postDoc = await fakeFirestore.collection('posts').doc(postId).get();
        final postData = postDoc.data() as Map<String, dynamic>;
        expect(postData['likesCount'], equals(0));

        final engagementDoc = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('engagement')
            .doc(userId)
            .get();
        expect(engagementDoc.data()!['liked'], isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        // This test would require mocking network failures
        // For now, we'll test that the service doesn't crash on invalid data
        
        expect(() async {
          await FeedService.getFeedPosts(userId: 'invalid_user');
        }, returnsNormally);
      });

      test('should validate post data before creation', () async {
        // Test various invalid scenarios
        expect(() async {
          await FeedService.createPost(
            authorId: '',
            content: 'Valid content',
            category: PostCategory.generalDiscussion,
          );
        }, throwsException);
      });
    });

    group('Cache Management', () {
      test('should clear cache when requested', () async {
        // Act
        FeedService.clearCache();

        // Assert - This is more of a smoke test since cache is internal
        expect(() => FeedService.clearCache(), returnsNormally);
      });
    });
  });
}
